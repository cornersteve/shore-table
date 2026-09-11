/* ============================================================================
   SHORE TABLE · autofill-worker.js · the one tiny backend piece
   ============================================================================
   A Cloudflare Worker with three endpoints, used ONLY by admin.html's
   "Autofill from their website" flow. Exists because browser CORS forbids a
   static page from reading another site's HTML. Every request requires a
   valid Supabase session token for the operator, verified server-side here,
   so nobody else can burn quota or proxy through it.

   ENDPOINTS (all GET, all require Authorization: Bearer <supabase token>):
     /site?url=…    fetch a restaurant's homepage, return {name, theme,
                    images:[…], googleReview…} — logo candidates from
                    og:image, icons, and header imgs, plus any Google
                    review/profile links the site itself publishes.
     /img?url=…     pass one image through with CORS headers so the page can
                    canvas-process and re-upload it (cross-origin images
                    taint a canvas; same-origin-via-worker does not).

   There is deliberately NO Google Places integration (a deliberate call, Aug
   2026): review links come from the restaurant's own site when published,
   and from the Place ID Finder fallback on the form otherwise. The worker
   never scrapes Google itself.

   ONE-TIME SETUP (Cloudflare dashboard, ~5 minutes):
     1. Workers & Pages > Create > pick the WORKERS tab > Create Worker.
        This makes a SEPARATE application that sits NEXT TO the site
        Pages project in your list, not inside it. Name it (e.g.
        shore-autofill), Deploy the hello-world it offers, then Edit code,
        delete the boilerplate, paste THIS ENTIRE file, Deploy again.
     2. Settings > Variables and Secrets, add:
          SUPABASE_URL       https://wryscqcukjduaodgfmdl.supabase.co
          SUPABASE_ANON_KEY  (the publishable key from app.html)
          OPERATOR_EMAIL     you@yourdomain.com   (your operator login email)
     3. Copy the worker URL (https://shore-autofill.<account>.workers.dev)
        into WORKER_URL at the top of admin.html and redeploy admin.html.

   PACKAGING NOTE: each future operator deploys their own copy with their own
   variables; the file itself is operator-agnostic.
   ============================================================================ */

// EDIT: your live domain (and keep a localhost entry for local testing)
const ALLOWED_ORIGINS = ['https://yourdomain.com', 'http://localhost:5599'];

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || '';
    const cors = {
      'Access-Control-Allow-Origin': ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0],
      'Access-Control-Allow-Headers': 'authorization, content-type',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Vary': 'Origin',
    };
    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });

    const json = (obj, status = 200) =>
      new Response(JSON.stringify(obj), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

    // ---- gate: a real, current operator session or nothing ----------------
    const token = (request.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
    if (!token) return json({ error: 'no_token' }, 401);
    let user;
    try {
      const who = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
        headers: { apikey: env.SUPABASE_ANON_KEY, Authorization: `Bearer ${token}` },
      });
      if (!who.ok) return json({ error: 'bad_token' }, 401);
      user = await who.json();
    } catch (e) {
      return json({ error: 'auth_unreachable' }, 502);
    }
    if (env.OPERATOR_EMAIL && (user.email || '').toLowerCase() !== env.OPERATOR_EMAIL.toLowerCase()) {
      return json({ error: 'not_operator' }, 403);
    }

    const url = new URL(request.url);
    try {
      if (url.pathname === '/site')  return await site(url.searchParams.get('url'), json);
      if (url.pathname === '/img')   return await img(url.searchParams.get('url'), cors, json);
    } catch (e) {
      return json({ error: 'failed', detail: String(e && e.message || e) }, 502);
    }
    return json({ error: 'not_found' }, 404);
  },
};

/* Refuse obviously-internal targets; this worker only ever fetches the
   public web. (The auth gate already limits callers to the operator, so
   this is a second belt, not the primary defense.) */
function publicHttpUrl(raw) {
  let u;
  try { u = new URL(raw); } catch (e) { return null; }
  if (!/^https?:$/.test(u.protocol)) return null;
  const h = u.hostname;
  if (h === 'localhost' || h.endsWith('.local') || h.endsWith('.internal')) return null;
  if (/^(127\.|10\.|192\.168\.|169\.254\.|0\.)/.test(h)) return null;
  if (/^172\.(1[6-9]|2\d|3[01])\./.test(h)) return null;
  return u;
}

const UA = 'Mozilla/5.0 (compatible; TableAppSetup/1.0)';

async function site(raw, json) {
  const u = publicHttpUrl(raw);
  if (!u) return json({ error: 'bad_url' }, 400);

  const res = await fetch(u, {
    headers: { 'User-Agent': UA, 'Accept': 'text/html' },
    signal: AbortSignal.timeout(9000),
    redirect: 'follow',
  });
  if (!res.ok) return json({ error: 'site_unreachable', status: res.status }, 502);
  const html = (await res.text()).slice(0, 300000);
  const base = res.url || u.href;

  const attr = (tagRe) => {
    const out = [];
    let m;
    while ((m = tagRe.exec(html)) !== null) out.push(m[1]);
    return out;
  };
  const metaContent = (name) => {
    const re = new RegExp(`<meta[^>]+(?:property|name)=["']${name}["'][^>]*content=["']([^"']+)["']`, 'i');
    const re2 = new RegExp(`<meta[^>]+content=["']([^"']+)["'][^>]*(?:property|name)=["']${name}["']`, 'i');
    const m = html.match(re) || html.match(re2);
    return m ? m[1] : null;
  };

  // name: og:site_name, else <title> with the usual suffix junk trimmed
  let name = metaContent('og:site_name');
  if (!name) {
    const t = html.match(/<title[^>]*>([^<]{1,120})<\/title>/i);
    if (t) name = t[1].split(/\s*[|·]\s*/)[0].trim();
  }
  if (name) name = name.replace(/&amp;/g, '&').replace(/&#0?39;|&apos;/g, "'").trim();

  // logo candidates, best-first-ish: og:image, apple-touch-icon, icons,
  // then any <img> whose src/class/alt/id mentions "logo"
  const cands = [];
  const push = (v) => { if (v) { try { cands.push(new URL(v, base).href); } catch (e) {} } };
  push(metaContent('og:image'));
  attr(/<link[^>]+rel=["'][^"']*apple-touch-icon[^"']*["'][^>]*href=["']([^"']+)["']/gi).forEach(push);
  attr(/<link[^>]+href=["']([^"']+)["'][^>]*rel=["'][^"']*apple-touch-icon[^"']*["']/gi).forEach(push);
  attr(/<img[^>]+(?:src)=["']([^"']+)["'][^>]*(?:class|alt|id)=["'][^"']*logo[^"']*["']/gi).forEach(push);
  attr(/<img[^>]+(?:class|alt|id)=["'][^"']*logo[^"']*["'][^>]*src=["']([^"']+)["']/gi).forEach(push);
  attr(/<link[^>]+rel=["'](?:shortcut )?icon["'][^>]*href=["']([^"']+)["']/gi).forEach(push);
  const images = [...new Set(cands)].filter(x => !/\.svg(\?|$)/i.test(x) ? true : true).slice(0, 8);

  const theme = metaContent('theme-color');

  // Google links the site itself carries. Free and legitimate: no key, no
  // scraping of Google, just reading what the restaurant already published.
  //   - an explicit writereview link, or a g.page/r/<code>/review link, IS
  //     the review link: return it as googleReview.
  //   - a plain g.page/<slug> link: its /review variant usually opens the
  //     review box; return it as googleReviewDerived (the page asks the
  //     operator to verify it opens before trusting it).
  //   - plain maps links: returned as googleLinks, display-only helpers.
  const glinks = [];
  // host-anchored: only links that really live on Google's own domains
  // (a page saying "https://evil.example/?x=g.page/" matches nothing)
  const linkRe = /href=["'](https?:\/\/(?:[a-z0-9-]+\.)*(?:search\.google\.com\/local\/writereview|g\.page\/|maps\.app\.goo\.gl\/|google\.[a-z]{2,3}(?:\.[a-z]{2})?\/maps)[^"'\s<>]*)["']/gi;
  let gm;
  while ((gm = linkRe.exec(html)) !== null) glinks.push(gm[1].replace(/&amp;/g, '&'));
  const uniq = [...new Set(glinks)];
  const googleReview = uniq.find(u => /writereview/i.test(u)) || uniq.find(u => /g\.page\/r\/[^/]+\/review/i.test(u)) || null;
  let googleReviewDerived = null;
  if (!googleReview) {
    const gp = uniq.find(u => /g\.page\/(?!r\/)[^/?#]+\/?$/i.test(u));
    if (gp) googleReviewDerived = gp.replace(/\/$/, '') + '/review';
  }

  return json({
    name: name || null,
    theme: /^#[0-9a-fA-F]{6}$/.test(theme || '') ? theme : null,
    images,
    googleReview,
    googleReviewDerived,
    googleLinks: uniq.slice(0, 3),
  });
}

async function img(raw, cors, json) {
  const u = publicHttpUrl(raw);
  if (!u) return json({ error: 'bad_url' }, 400);
  const res = await fetch(u, {
    headers: { 'User-Agent': UA, 'Accept': 'image/*' },
    signal: AbortSignal.timeout(9000),
    redirect: 'follow',
  });
  if (!res.ok) return json({ error: 'image_unreachable' }, 502);
  const type = res.headers.get('Content-Type') || '';
  if (!/^image\//i.test(type) && !/\.(png|jpe?g|gif|webp|svg|ico)(\?|$)/i.test(u.pathname)) {
    return json({ error: 'not_an_image' }, 415);
  }
  const buf = await res.arrayBuffer();
  if (buf.byteLength > 6 * 1024 * 1024) return json({ error: 'too_big' }, 413);
  return new Response(buf, { headers: { ...cors, 'Content-Type': type || 'application/octet-stream', 'Cache-Control': 'no-store' } });
}
