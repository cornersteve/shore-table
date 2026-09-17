/* The report sheet is drawn at the report's own 820px width and scaled to
   the frame; the month line is always last month. */
(function(){
  const w = document.querySelector('.rp-wrap'); if(!w) return;
  // the frame can be 0 wide while a tab is hidden; never write a zero scale, and
  // recompute whenever the frame gets a size
  const set = ()=>{ const cw = w.clientWidth; if(cw) w.style.setProperty('--rs', (cw / 820).toFixed(4)); };
  set(); window.addEventListener('resize', set); window.addEventListener('load', set);
  if(window.ResizeObserver) new ResizeObserver(set).observe(w);
  // a page that loads in a hidden tab has no width yet: keep trying until it does
  let tries = 0; const tick = ()=>{ if(w.clientWidth || tries++ > 40) return; set(); setTimeout(tick, 250); }; setTimeout(tick, 250);
  document.addEventListener('visibilitychange', set);
  const d = new Date(); d.setDate(1); d.setMonth(d.getMonth() - 1);
  const m = document.querySelector('.rp-meta span'); if(m) m.textContent = d.toLocaleDateString('en-US', { month: 'long', year: 'numeric' }) + ' · 23 guests responded';
})();

/* ---- the demo venue lands in the phone mockups: its name and logo on all
   three, and its real home screen (cards, games row) on the first ---- */
function mkHome(v){
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const d0 = new Date();
  const dayKey = ['sun','mon','tue','wed','thu','fri','sat'][d0.getDay()];
  const dayName = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'][d0.getDay()];
  const todayYmd = d0.getFullYear() + '-' + String(d0.getMonth() + 1).padStart(2, '0') + '-' + String(d0.getDate()).padStart(2, '0');
  const row = (ic, title, sub, hot) => '<div class="mk-opt' + (hot ? ' hot' : '') + '">' + (ic ? '<span class="mk-ic">' + ic + '</span>' : '') + '<span><b>' + esc(title) + '</b>' + (sub ? '<i' + (sub.special ? ' class="special"' : '') + '>' + (sub.special ? '<b>' + esc(dayName) + ':</b> ' + esc(sub.text) : esc(sub.text)) + '</i>' : '') + '</span><em>›</em></div>';
  let out = '';
  if(v.games_enabled !== false) out += row(CARD_ICONS.dice, 'Play a game', { text: 'Pass the time, solo or with the whole table.' });
  out += '<div class="mk-opt"><span class="mk-ic"><svg viewBox="0 0 24 24"><path d="M21 11.5c0 4.14-4.03 7.5-9 7.5-1.02 0-2-.14-2.91-.4L4 20l1.18-3.53C3.83 15.15 3 13.4 3 11.5 3 7.36 7.03 4 12 4s9 3.36 9 7.5z"/></svg></span><span><b>Share feedback</b><i>Anonymous, and seen only by ' + esc(v.name) + '.</i></span><em>›</em></div>';
  (Array.isArray(v.cards) ? v.cards : []).forEach(c => {
    if(!c || c.off) return;
    if(c.t === 'notice' && c.until && c.until < todayYmd) return;
    const ic = cardIcon(c);
    if(c.t === 'notice' && (c.mode || 'inline') === 'inline'){
      out += c.hot
        ? '<div class="mk-promo"><b>' + esc(c.title) + '</b>' + (cardBannerText(c) ? '<i>' + esc(cardBannerText(c)) + '</i>' : '') + '</div>'
        : '<div class="mk-note"><b>' + esc(c.title) + '</b>' + (c.body ? '<i>' + esc(c.body) + '</i>' : '') + '</div>';
      return;
    }
    if(c.t === 'schedule'){
      const today = (c.days || {})[dayKey];
      if(!today && !c.always) return;
      out += row(ic, c.title, today ? { text: today, special: true } : { text: c.desc || 'Tap to view the calendar' });
      return;
    }
    out += row(ic, c.title, cardSub(c) ? { text: cardSub(c) } : null, c.t === 'notice' && c.hot);
  });
  return out;
}
(function(){
  const C = Object.assign({}, window.OPERATOR_CONFIG || {}, window.OPERATOR_BRAND || {});
  // which venue plays the demo: the platform's Corner & Oak unless Settings picked one
  const DEMO = /^[a-z0-9_-]{1,40}$/i.test(C.demoVenue || '') ? C.demoVenue : 'demo';
  document.querySelectorAll('a[href="app.html?v=demo"]').forEach(a => { a.href = 'app.html?v=' + encodeURIComponent(DEMO); });
  const phones = document.querySelector('.phones');
  const show = ()=>{ if(phones) phones.classList.remove('mk-wait'); };
  const CACHE = 'st_demo_venue_' + DEMO;
  // the venue's own accent on the phones and the report sheet, the way its
  // real app and report wear it (the page around them keeps the operator's)
  const onAccent = hex => { const m = /^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex); if(!m) return '#ffffff';
    const lin = h => { const x = parseInt(h, 16) / 255; return x <= .03928 ? x / 12.92 : Math.pow((x + .055) / 1.055, 2.4); };
    const L = .2126 * lin(m[1]) + .7152 * lin(m[2]) + .0722 * lin(m[3]); return (1.05 / (L + .05)) >= 4.5 ? '#ffffff' : '#16110a'; };
  const fill = v => {
    if(!v || !v.name) return false;
    // a text wordmark is the venue's logo: the phone headers print it, like the real app does
    const wordmark = (v.logo && !/^(https?:|images\/|data:image\/)/i.test(v.logo)) ? v.logo : v.name;
    document.querySelectorAll('.mk-name').forEach(e => e.textContent = wordmark);
    const home = document.querySelector('.mk-home'); if(home) home.innerHTML = mkHome(v);
    if(/^#[0-9a-f]{6}$/i.test(v.accent || '')) document.querySelectorAll('.phones, .report-fig').forEach(e => {
      e.style.setProperty('--accent', v.accent);
      e.style.setProperty('--on-accent', onAccent(v.accent));
      e.style.setProperty('--accent-deep', 'color-mix(in srgb, ' + v.accent + ' 72%, #16110a)');
    });
    if(v.logo && /^(https?:|images\/|data:image\/)/i.test(v.logo)) document.querySelectorAll('.mk-logo').forEach(e => {
      // claim the slot before the image loads: the cached fill and the live
      // fill can arrive within the same second, and each used to add a logo
      if(e.dataset.logo === v.logo) return;
      e.dataset.logo = v.logo;
      const i = new Image(); i.alt = '';
      i.onload = ()=>{ e.querySelectorAll('img').forEach(x => x.remove()); e.appendChild(i); e.classList.add('has-img'); };
      i.src = v.logo;
    });
    return true;
  };
  // the last answer, before the first paint: no placeholder flash on a repeat visit
  try { if(fill(JSON.parse(localStorage.getItem(CACHE) || 'null'))) show(); } catch(e){}
  if(!C.supabaseUrl || !C.supabaseKey){ show(); return; }
  // never hold the phones for more than a moment on a slow connection
  const t0 = setTimeout(show, 2500);
  fetch(C.supabaseUrl.replace(/\/$/, '') + '/rest/v1/public_venues?id=eq.' + encodeURIComponent(DEMO) + '&select=name,logo,accent,cards,games_enabled', { headers: { apikey: C.supabaseKey, Authorization: 'Bearer ' + C.supabaseKey } })
    .then(r => r.ok ? r.json() : [])
    .then(rows => {
      const v = rows && rows[0];
      if(fill(v)){ try { localStorage.setItem(CACHE, JSON.stringify({ name: v.name, logo: v.logo || null, accent: v.accent || null, cards: v.cards || null, games_enabled: v.games_enabled })); } catch(e){} }
    })
    .catch(()=>{})
    .finally(()=>{ clearTimeout(t0); show(); });
})();

/* ---- operator config fill (config.js + brand.js) ---- */
(function(){
  const C = Object.assign({}, window.OPERATOR_CONFIG || {}, window.OPERATOR_BRAND || {});
  const brand = C.brandName || 'This platform';
  const email = C.contactEmail || '';
  const region = C.regionName || 'your area';
  const regionShort = C.regionShort || 'the county';
  const acc = /^#[0-9a-f]{6}$/i.test(C.accent || '') ? C.accent : '#3a6ea5';
  document.title = brand + ': a better experience at the table';
  const initial = brand.trim().charAt(0).toUpperCase();
  const logoSvg = (typeof C.logoSvg === 'string' && C.logoSvg.trim().startsWith('<svg')) ? C.logoSvg : '';
  const iconUrl = (typeof C.iconUrl === 'string' && C.iconUrl) ? C.iconUrl : '';
  const logoUrl = (typeof C.logoUrl === 'string' && C.logoUrl) ? C.logoUrl : '';
  if (logoUrl) {
    // a full logo image replaces the mark+name pair everywhere it appears
    document.querySelectorAll('.wordmark').forEach(w => { w.innerHTML = '<img class="wm-img" src="' + logoUrl.replace(/"/g, '&quot;') + '" alt="' + brand.replace(/"/g, '&quot;') + '">'; });
  } else {
    document.querySelectorAll('.wm-mark').forEach(m => {
      if (logoSvg) { m.innerHTML = logoSvg; m.style.background = 'transparent'; }
      else if (iconUrl) { m.innerHTML = '<img src="' + iconUrl.replace(/"/g, '&quot;') + '" alt="">'; m.style.background = 'transparent'; }
      else { m.textContent = initial; m.style.background = acc; }
    });
    document.querySelectorAll('.wm-name').forEach(m => { m.textContent = brand; });
  }
  document.querySelectorAll('.cfg-region').forEach(m => { m.textContent = region; });
  document.querySelectorAll('.cfg-regionshort').forEach(m => { m.textContent = regionShort; });
  document.querySelectorAll('.cfg-brand').forEach(m => { m.textContent = brand; });
  document.querySelectorAll('.cfg-email').forEach(m => { m.textContent = email; });
  document.querySelectorAll('.cfg-gname-quick-pour').forEach(m => { m.textContent = (C.gameNames || {}).quick_pour || 'Quick Pour'; });
  if (C.operatorStory) {
    const s = document.querySelector('.cfg-story');
    if (s) s.textContent = C.operatorStory;
  }
  document.querySelectorAll('[data-mailto]').forEach(a => {
    if (!email) return;
    a.href = 'mailto:' + email + (a.dataset.mailto === 'game-idea' ? '?subject=' + encodeURIComponent('Game idea for ' + brand) : '');
  });
  const fav = document.querySelector('link[rel="icon"]');
  if (fav) fav.href = iconUrl || 'data:image/svg+xml,' + encodeURIComponent(logoSvg || '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect x="6" y="6" width="52" height="52" rx="12" fill="' + acc + '"/><text x="32" y="44" font-family="sans-serif" font-size="34" font-weight="800" fill="#fff" text-anchor="middle">' + initial + '</text></svg>');
  const ati = document.querySelector('link[rel="apple-touch-icon"]');
  if (ati && iconUrl) ati.href = iconUrl;
})();
