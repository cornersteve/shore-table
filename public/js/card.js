/* Shore Table: the table card, in one place for both dashboards. The QR
   encoder, the print renderer, and the designer the owner dashboard's card
   section and the operator dashboard's card page both mount. Loaded after
   shared.js (esc, readableOn). Fix a card bug here, once. */
/* ============================================================
   Self-contained QR encoder (ISO/IEC 18004), byte mode, ECC
   level Q, versions 1..10. Ported VERBATIM from the verified
   encoder in tools/qr-maker.html (output machine-decode
   checked there); only the export differs, exposing the raw
   module matrix for canvas drawing. Do not edit the algorithm.
   ============================================================ */
const QR = (() => {
  const EXP = new Array(256), LOG = new Array(256);
  for (let i = 0, x = 1; i < 256; i++) { EXP[i] = x; LOG[x] = i; x <<= 1; if (x & 0x100) x ^= 0x11D; }
  LOG[1] = 0;
  const gmul = (a, b) => (a === 0 || b === 0) ? 0 : EXP[(LOG[a] + LOG[b]) % 255];
  const BLOCKS = {
    1:[13,[[1,13]]], 2:[22,[[1,22]]], 3:[18,[[2,17]]], 4:[26,[[2,24]]],
    5:[18,[[2,15],[2,16]]], 6:[24,[[4,19]]], 7:[18,[[2,14],[4,15]]],
    8:[22,[[4,18],[2,19]]], 9:[20,[[4,16],[4,17]]], 10:[24,[[6,19],[2,20]]],
  };
  const ALIGN = {2:[6,18],3:[6,22],4:[6,26],5:[6,30],6:[6,34],7:[6,22,38],8:[6,24,42],9:[6,26,46],10:[6,28,50]};
  function dataCapacity(v){ const [,bl] = BLOCKS[v]; return bl.reduce((s,[n,d]) => s + n*d, 0); }
  function pickVersion(len){
    for (let v = 1; v <= 10; v++){
      const countBits = v <= 9 ? 8 : 16;
      const bits = 4 + countBits + 8*len;
      if (bits <= dataCapacity(v)*8) return v;
    }
    throw new Error("URL too long for this generator (version 10 max)");
  }
  function makeCodewords(bytes, v){
    const capacity = dataCapacity(v);
    const countBits = v <= 9 ? 8 : 16;
    const bits = [];
    const push = (val, n) => { for (let i = n-1; i >= 0; i--) bits.push((val >> i) & 1); };
    push(0b0100, 4);
    push(bytes.length, countBits);
    bytes.forEach(b => push(b, 8));
    for (let i = 0; i < 4 && bits.length < capacity*8; i++) bits.push(0);
    while (bits.length % 8) bits.push(0);
    const cw = [];
    for (let i = 0; i < bits.length; i += 8){
      let b = 0; for (let j = 0; j < 8; j++) b = (b<<1) | bits[i+j];
      cw.push(b);
    }
    const pads = [0xEC, 0x11];
    for (let i = 0; cw.length < capacity; i++) cw.push(pads[i % 2]);
    return cw;
  }
  function eccForBlock(data, ecCount){
    let gen = [1];
    for (let i = 0; i < ecCount; i++){
      const next = new Array(gen.length + 1).fill(0);
      for (let j = 0; j < gen.length; j++){
        next[j] ^= gmul(gen[j], EXP[i]);
        next[j+1] ^= gen[j];
      }
      gen = next;
    }
    gen.reverse();
    const res = data.concat(new Array(ecCount).fill(0));
    for (let i = 0; i < data.length; i++){
      const f = res[i];
      if (f === 0) continue;
      for (let j = 0; j < gen.length; j++) res[i+j] ^= gmul(gen[j], f);
    }
    return res.slice(data.length);
  }
  function interleave(cw, v){
    const [ec, layout] = BLOCKS[v];
    const blocks = [];
    let pos = 0;
    layout.forEach(([n, dlen]) => {
      for (let i = 0; i < n; i++){
        const d = cw.slice(pos, pos + dlen); pos += dlen;
        blocks.push({ d, e: eccForBlock(d, ec) });
      }
    });
    const out = [];
    const maxD = Math.max(...blocks.map(b => b.d.length));
    for (let i = 0; i < maxD; i++) blocks.forEach(b => { if (i < b.d.length) out.push(b.d[i]); });
    for (let i = 0; i < ec; i++) blocks.forEach(b => out.push(b.e[i]));
    return out;
  }
  const bchDigit = n => { let d = 0; while (n){ d++; n >>>= 1; } return d; };
  const G15 = 0b10100110111, G15M = 0b101010000010010, G18 = 0b1111100100101;
  function bch15(data){
    let d = data << 10;
    while (bchDigit(d) - bchDigit(G15) >= 0) d ^= G15 << (bchDigit(d) - bchDigit(G15));
    return ((data << 10) | d) ^ G15M;
  }
  function bch18(data){
    let d = data << 12;
    while (bchDigit(d) - bchDigit(G18) >= 0) d ^= G18 << (bchDigit(d) - bchDigit(G18));
    return (data << 12) | d;
  }
  const MASKS = [
    (i,j) => (i+j) % 2 === 0,
    (i,j) => i % 2 === 0,
    (i,j) => j % 3 === 0,
    (i,j) => (i+j) % 3 === 0,
    (i,j) => (Math.floor(i/2) + Math.floor(j/3)) % 2 === 0,
    (i,j) => (i*j) % 2 + (i*j) % 3 === 0,
    (i,j) => ((i*j) % 2 + (i*j) % 3) % 2 === 0,
    (i,j) => ((i*j) % 3 + (i+j) % 2) % 2 === 0,
  ];
  function build(v, dataCw, mask){
    const mc = v*4 + 17;
    const m = Array.from({length: mc}, () => new Array(mc).fill(null));
    const setFinder = (r, c) => {
      for (let i = -1; i <= 7; i++) for (let j = -1; j <= 7; j++){
        const rr = r+i, cc = c+j;
        if (rr < 0 || rr >= mc || cc < 0 || cc >= mc) continue;
        m[rr][cc] = (i >= 0 && i <= 6 && (j === 0 || j === 6)) ||
                    (j >= 0 && j <= 6 && (i === 0 || i === 6)) ||
                    (i >= 2 && i <= 4 && j >= 2 && j <= 4);
      }
    };
    setFinder(0, 0); setFinder(0, mc-7); setFinder(mc-7, 0);
    const ap = ALIGN[v] || [];
    ap.forEach(r => ap.forEach(c => {
      if (m[r][c] !== null) return;
      for (let i = -2; i <= 2; i++) for (let j = -2; j <= 2; j++)
        m[r+i][c+j] = Math.max(Math.abs(i), Math.abs(j)) !== 1;
    }));
    for (let i = 8; i < mc-8; i++){
      if (m[i][6] === null) m[i][6] = i % 2 === 0;
      if (m[6][i] === null) m[6][i] = i % 2 === 0;
    }
    const f = bch15((0b11 << 3) | mask);
    for (let i = 0; i < 15; i++){
      const bit = ((f >> i) & 1) === 1;
      if (i < 6) m[i][8] = bit;
      else if (i < 8) m[i+1][8] = bit;
      else m[mc-15+i][8] = bit;
      if (i < 8) m[8][mc-i-1] = bit;
      else if (i < 9) m[8][15-i-1+1] = bit;
      else m[8][15-i-1] = bit;
    }
    m[mc-8][8] = true;
    if (v >= 7){
      const vi = bch18(v);
      for (let i = 0; i < 18; i++){
        const bit = ((vi >> i) & 1) === 1;
        m[Math.floor(i/3)][i%3 + mc - 8 - 3] = bit;
        m[i%3 + mc - 8 - 3][Math.floor(i/3)] = bit;
      }
    }
    let inc = -1, row = mc-1, bitIdx = 7, byteIdx = 0;
    for (let col = mc-1; col > 0; col -= 2){
      if (col === 6) col--;
      while (true){
        for (let c = 0; c < 2; c++){
          if (m[row][col-c] === null){
            let dark = false;
            if (byteIdx < dataCw.length) dark = ((dataCw[byteIdx] >>> bitIdx) & 1) === 1;
            if (MASKS[mask](row, col-c)) dark = !dark;
            m[row][col-c] = dark;
            bitIdx--; if (bitIdx === -1){ byteIdx++; bitIdx = 7; }
          }
        }
        row += inc;
        if (row < 0 || row >= mc){ row -= inc; inc = -inc; break; }
      }
    }
    return m;
  }
  function penalty(m){
    const mc = m.length;
    let p = 0;
    for (let pass = 0; pass < 2; pass++){
      for (let i = 0; i < mc; i++){
        let run = 1;
        for (let j = 1; j < mc; j++){
          const cur = pass ? m[j][i] : m[i][j], prev = pass ? m[j-1][i] : m[i][j-1];
          if (cur === prev) run++;
          else { if (run >= 5) p += 3 + (run - 5); run = 1; }
        }
        if (run >= 5) p += 3 + (run - 5);
      }
    }
    for (let i = 0; i < mc-1; i++) for (let j = 0; j < mc-1; j++)
      if (m[i][j] === m[i][j+1] && m[i][j] === m[i+1][j] && m[i][j] === m[i+1][j+1]) p += 3;
    const pat = [true,false,true,true,true,false,true];
    const light4 = (arr, s) => s >= 0 && s+3 < arr.length && !arr[s] && !arr[s+1] && !arr[s+2] && !arr[s+3];
    for (let pass = 0; pass < 2; pass++){
      for (let i = 0; i < mc; i++){
        const line = [];
        for (let j = 0; j < mc; j++) line.push(pass ? m[j][i] : m[i][j]);
        for (let j = 0; j <= mc-7; j++){
          let ok = true;
          for (let k = 0; k < 7; k++) if (line[j+k] !== pat[k]){ ok = false; break; }
          if (ok && (light4(line, j-4) || light4(line, j+7))) p += 40;
        }
      }
    }
    let dark = 0;
    for (let i = 0; i < mc; i++) for (let j = 0; j < mc; j++) if (m[i][j]) dark++;
    p += Math.floor(Math.abs(dark*100/(mc*mc) - 50) / 5) * 10;
    return p;
  }
  function encode(text){
    const bytes = Array.from(new TextEncoder().encode(text));
    const v = pickVersion(bytes.length);
    const cw = interleave(makeCodewords(bytes, v), v);
    let best = null, bestP = Infinity;
    for (let mask = 0; mask < 8; mask++){
      const m = build(v, cw, mask);
      const p = penalty(m);
      if (p < bestP){ bestP = p; best = m; }
    }
    return best;
  }
  return { encode };
})();

function drawTracked(ctx, text, x, y, ls){
  let cx = x;
  for(const ch of text){ ctx.fillText(ch, cx, y); cx += ctx.measureText(ch).width + ls; }
  return cx - ls;
}
function trackedWidth(ctx, text, ls){
  let w = 0;
  for(const ch of text) w += ctx.measureText(ch).width + ls;
  return w - ls;
}
function roundRect(ctx, x, y, w, h, r){
  ctx.beginPath();
  ctx.moveTo(x+r, y);
  ctx.arcTo(x+w, y, x+w, y+h, r);
  ctx.arcTo(x+w, y+h, x, y+h, r);
  ctx.arcTo(x, y+h, x, y, r);
  ctx.arcTo(x, y, x+w, y, r);
  ctx.closePath();
}
function drawQrCard(ctx, matrix, x, y, size){
  ctx.save();
  ctx.shadowColor = 'rgba(30,25,15,.16)'; ctx.shadowBlur = 36; ctx.shadowOffsetY = 10;
  ctx.fillStyle = '#ffffff';
  roundRect(ctx, x, y, size, size, 30); ctx.fill();
  ctx.restore();
  const pad = 50, inner = size - pad*2, mc = matrix.length, mod = inner/mc;
  ctx.fillStyle = '#1a1a1a';
  for(let r=0; r<mc; r++) for(let c=0; c<mc; c++)
    if(matrix[r][c]) ctx.fillRect(x+pad + c*mod, y+pad + r*mod, Math.ceil(mod), Math.ceil(mod));
}
function drawPill(ctx, x, y, label, bg, dotColor){
  ctx.font = '700 30px "Hanken Grotesk", sans-serif';
  const ls = 4.5, tw = trackedWidth(ctx, label, ls);
  const h = 64, dotR = 8, padL = 30, gap = 16, padR = 32;
  const w = padL + dotR*2 + gap + tw + padR;
  ctx.fillStyle = bg;
  roundRect(ctx, x, y, w, h, h/2); ctx.fill();
  ctx.fillStyle = dotColor;
  ctx.beginPath(); ctx.arc(x+padL+dotR, y+h/2, dotR, 0, Math.PI*2); ctx.fill();
  ctx.fillStyle = '#ffffff';
  ctx.textBaseline = 'middle';
  drawTracked(ctx, label, x+padL+dotR*2+gap, y+h/2+2, ls);
  ctx.textBaseline = 'alphabetic';
}

/* ================================================================
   THE CARD DESIGN. What a venue may change, with the defaults that
   reproduce the original card exactly when nothing is saved. Saved in
   venues.card through clean_card (owner: set_venue_card, operator:
   admin_set_card); this file only ever draws what the server kept.
   ================================================================ */
const CARD_TARGETS = { home: 'Home screen', games: 'Games', box: 'Feedback', url: 'A link of your own' };
const CARD_PILL = { home: 'YOUR TABLE', games: 'GAME TIME', box: 'YOUR FEEDBACK', url: 'SCAN ME' };
const CARD_DEFAULT_SLOTS = {
  s1: { head: 'Play games while you wait.', body: 'A few quick games for the table. No app or sign-up required.', scan: 'SCAN TO PLAY TABLE GAMES', to: 'games', url: '' },
  s2: { head: 'How was everything?', body: 'Tell us anything, completely anonymous. No name, no email.', scan: 'SCAN TO LEAVE FEEDBACK', to: 'box', url: '' },
};
const HEX = /^#[0-9a-f]{6}$/i;
// the saved design (or nothing) merged over the defaults for this venue
function cardDesign(v, saved){
  const s = saved && typeof saved === 'object' ? saved : {};
  const slot = k => Object.assign({}, CARD_DEFAULT_SLOTS[k], (s[k] && typeof s[k] === 'object') ? s[k] : {});
  return {
    town: typeof s.town === 'string' ? s.town : '',
    a1: HEX.test(s.a1 || '') ? s.a1 : '#1e3a5f',
    a2: HEX.test(s.a2 || '') ? s.a2 : (HEX.test(v.accent || '') ? v.accent : '#3a6ea5'),
    hb: HEX.test(s.hb || '') ? s.hb : (HEX.test(v.header_bg || '') ? v.header_bg : (v.dark_mode ? '#0b0a09' : '#ffffff')),
    bb: HEX.test(s.bb || '') ? s.bb : (v.dark_mode ? '#171512' : '#efe8dc'),
    s1: slot('s1'), s2: slot('s2'),
  };
}
// where a slot's QR sends the phone
function cardTargetUrl(base, v, slot){
  if (slot.to === 'url' && /^https:\/\/[^\s"'<>]{1,200}$/i.test(slot.url || '')) return slot.url;
  const q = slot.to === 'games' ? '&go=games' : slot.to === 'box' ? '&go=box' : '';
  return `${base}/app.html?v=${v.id}${q}`;
}
// WCAG contrast ratio, for the designer's warnings
function contrastRatio(a, b){
  const lum = hex => { const c = hex.replace('#', ''); const f = x => { x /= 255; return x <= .03928 ? x / 12.92 : Math.pow((x + .055) / 1.055, 2.4); };
    return .2126 * f(parseInt(c.slice(0, 2), 16)) + .7152 * f(parseInt(c.slice(2, 4), 16)) + .0722 * f(parseInt(c.slice(4, 6), 16)); };
  const l1 = lum(a), l2 = lum(b); return (Math.max(l1, l2) + .05) / (Math.min(l1, l2) + .05);
}
// words onto lines that fit maxW at the current ctx.font
function wrapWords(ctx, text, maxW){
  const words = String(text || '').trim().split(/\s+/).filter(Boolean), lines = [];
  let cur = '';
  for (const w of words){
    const trial = cur ? cur + ' ' + w : w;
    if (ctx.measureText(trial).width <= maxW || !cur) cur = trial; else { lines.push(cur); cur = w; }
  }
  if (cur) lines.push(cur);
  return lines;
}
// the largest size in the list whose wrapped text fits in maxLines; at the
// smallest size the overflow is cut with an ellipsis, so nothing ever runs off the card
function fitText(ctx, text, maxW, maxLines, sizes, weight, family){
  let lines = [], size = sizes[sizes.length - 1];
  for (const s of sizes){
    ctx.font = `${weight} ${s}px ${family}`;
    lines = wrapWords(ctx, text, maxW);
    if (lines.length <= maxLines){ size = s; break; }
  }
  ctx.font = `${weight} ${size}px ${family}`;
  if (lines.length > maxLines){
    lines = lines.slice(0, maxLines);
    let last = lines[maxLines - 1];
    while (last.length > 1 && ctx.measureText(last + '…').width > maxW) last = last.slice(0, -1);
    lines[maxLines - 1] = last + '…';
  }
  return { size, lines };
}
async function renderCard(cnv, v, opts){
  // opts: the design (cardDesign shape) plus bleed, logoImg, base (the site
  // origin the QR codes point at). opts.bleed (px per edge): the background
  // bands extend through the bleed ring so a commercial printer can trim back
  // to a clean 4x6. 38px at 300dpi is a hair over the standard 1/8" bleed.
  const W = 1200, H = 1800, B = opts.bleed || 0;
  const d = cardDesign(v, opts);
  cnv.width = W + 2*B; cnv.height = H + 2*B;
  const ctx = cnv.getContext('2d');
  const a1 = d.a1, a2 = d.a2, HEADER = d.hb, BODY = d.bb;
  const darkBody = readableOn(BODY) === '#ffffff';
  const INK    = darkBody ? '#ece7dd' : '#33302a';
  const TOWN   = readableOn(HEADER) === '#ffffff' ? '#a7a196' : '#8b8578';
  const RULE_L = darkBody ? '#3a352e' : '#d9d2c2';    // the hairline divider
  const FAM = '"Hanken Grotesk", sans-serif';
  await Promise.all([
    document.fonts.load(`800 100px ${FAM}`),
    document.fonts.load(`700 30px ${FAM}`),
    document.fonts.load(`400 38px ${FAM}`),
  ]).catch(()=>{});

  // background bands, painted edge to edge including the bleed ring
  ctx.fillStyle = BODY; ctx.fillRect(0, 0, W+2*B, H+2*B);
  ctx.fillStyle = HEADER; ctx.fillRect(0, 0, W+2*B, 332+B);        // header band
  ctx.fillStyle = a2; ctx.fillRect(0, 332+B, W+2*B, 12);           // accent rule
  ctx.fillStyle = a1; ctx.fillRect(0, H-54+B, W+2*B, 54+B);        // bottom bar
  ctx.translate(B, B);  // everything below draws in trim-box coordinates

  // header: logo left (image or wordmark), town right
  if(opts.logoImg){
    const img = opts.logoImg, maxW = 430, maxH = 214;
    const s = Math.min(maxW/img.naturalWidth, maxH/img.naturalHeight, 2.2);
    const w = img.naturalWidth*s, h = img.naturalHeight*s;
    ctx.drawImage(img, 110, 166 - h/2, w, h);
  } else {
    ctx.fillStyle = readableOn(HEADER) === '#ffffff' ? '#ffffff' : a1;
    ctx.font = `800 58px ${FAM}`;
    ctx.fillText((v.logo && !/^(https?:|images\/)/i.test(v.logo) ? v.logo : v.name), 110, 188);
  }
  if(d.town){
    ctx.fillStyle = TOWN;   // header-aware: light dim on dark headers
    ctx.font = `700 36px ${FAM}`;
    const t = d.town.toUpperCase(), ls = 6;
    drawTracked(ctx, t, W - 110 - trackedWidth(ctx, t, ls), 182, ls);
  }

  // the two QR panels
  const base = opts.base || location.origin;
  const qrFor = slot => { try { return QR.encode(cardTargetUrl(base, v, slot)); } catch(e){ return QR.encode(cardTargetUrl(base, v, { to: 'home' })); } };
  drawQrCard(ctx, qrFor(d.s1), 710, 435, 380);
  drawQrCard(ctx, qrFor(d.s2), 710, 1095, 380);

  // a text section: pill, headline (2 lines), message (2 lines), small caps
  // line. With the default text every y lands where the original card put it.
  const COL = 560;   // text column: from x=110 to the QR panel
  const section = (y0, slot, pillBg, dot) => {
    drawPill(ctx, 110, y0, CARD_PILL[slot.to] || CARD_PILL.games, pillBg, dot);
    ctx.fillStyle = a1;
    const head = fitText(ctx, slot.head, COL, 2, [74, 66, 58, 52], 800, FAM);
    let y = y0 + 162;
    const lh = Math.round(head.size * 1.16);
    head.lines.forEach((l, i) => ctx.fillText(l, 110, y + i * lh));
    y += (head.lines.length - 1) * lh;
    ctx.fillStyle = INK;
    const body = fitText(ctx, slot.body, COL, 2, [38, 34, 30], 400, FAM);
    y += 78;
    const blh = Math.round(body.size * 1.37);
    body.lines.forEach((l, i) => ctx.fillText(l, 110, y + i * blh));
    y += (body.lines.length - 1) * blh;
    if (slot.scan){
      ctx.fillStyle = a1;
      let sz = 34, t = slot.scan.toUpperCase();
      for (; sz >= 22; sz -= 2){ ctx.font = `700 ${sz}px ${FAM}`; if (trackedWidth(ctx, t, 4) <= COL) break; }
      while (t.length > 3 && trackedWidth(ctx, t, 4) > COL) t = t.slice(0, -2) + '…';
      drawTracked(ctx, t, 110, y + 76, 4);
    }
  };
  section(430, d.s1, a1, a2);
  ctx.fillStyle = RULE_L; ctx.fillRect(110, 972, W-220, 2);   // divider
  section(1090, d.s2, a2, '#ffffff');
}
async function loadCardLogo(v){
  if(!v.logo || !/^(https?:|images\/)/i.test(v.logo)) return null;
  try {
    const res = await fetch(v.logo);
    if(!res.ok) return null;
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const img = new Image();
    await new Promise((ok, no)=>{ img.onload=ok; img.onerror=no; img.src=url; });
    return img;
  } catch(e){ return null; }
}
function downloadCanvas(cnv, filename){
  cnv.toBlob(blob=>{
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = filename;
    a.click();
    setTimeout(()=>URL.revokeObjectURL(a.href), 4000);
  }, 'image/png');
}

/* ================================================================
   THE DESIGNER. One editor for both dashboards: the owner's card
   section and the operator's card page mount it into a host element.
   opts: { base, save(card) -> cleaned card, onDirty(bool), msgClass,
   swatches(img) -> [hex] }. The saved design comes from v.card; a design
   an older build kept in this browser (st_card_<id>) prefills once.
   ================================================================ */
function mountCardDesigner(host, v, opts){
  let legacy = null;
  if (!v.card) { try { legacy = JSON.parse(localStorage.getItem('st_card_' + v.id) || 'null'); } catch(e){} }
  const start = v.card || (legacy ? { town: legacy.town, a1: legacy.a1, a2: legacy.a2, hb: legacy.hb || (legacy.dark ? '#0b0a09' : null), bb: legacy.dark ? '#171512' : null } : null);
  const d = cardDesign(v, start);
  const msgClass = opts.msgClass || 'msg';
  const color = (key, label, sub) => `
    <label class="cd-l">${label} <span>${sub}</span></label>
    <div class="cd-row"><input type="color" data-cd="${key}" value="${esc(d[key])}"><input type="text" data-cdhex="${key}" value="${esc(d[key])}" aria-label="${label}, hex code" autocapitalize="off" spellcheck="false" maxlength="7"></div>
    <div class="cd-sw" data-sw="${key}"></div>`;
  const slotForm = (k, title) => { const s = d[k]; return `
    <div class="cd-h">${title}</div>
    <label class="cd-l">Headline</label>
    <input type="text" data-cd="${k}.head" value="${esc(s.head)}" maxlength="60" spellcheck="true" placeholder="Ex. Play games while you wait.">
    <label class="cd-l">Message</label>
    <textarea data-cd="${k}.body" maxlength="120" spellcheck="true" placeholder="Ex. A few quick games for the table.">${esc(s.body)}</textarea>
    <label class="cd-l">Small caps line</label>
    <input type="text" data-cd="${k}.scan" value="${esc(s.scan)}" maxlength="40" spellcheck="true" placeholder="Ex. SCAN TO PLAY">
    <label class="cd-l">Where the code sends them</label>
    <div class="cd-radios">${Object.keys(CARD_TARGETS).map(t => `<label class="cd-ck"><input type="radio" name="cd_${k}_to" value="${t}" ${s.to === t ? 'checked' : ''}> ${CARD_TARGETS[t]}</label>`).join('')}</div>
    <input type="url" data-cd="${k}.url" value="${esc(s.url || '')}" maxlength="200" placeholder="https://yourrestaurant.com/menu" inputmode="url" autocapitalize="off" autocorrect="off" spellcheck="false" style="${s.to === 'url' ? '' : 'display:none'}">
    <div class="cd-note" data-urlnote="${k}" style="${s.to === 'url' ? '' : 'display:none'}">A link of your own skips the app, so scans of this code do not show in your report.</div>`; };
  host.innerHTML = `
    <div class="cd">
      <div class="cd-form">
        <div class="cd-h">Colors</div>
        <label class="cd-l">Town line <span>(top right, optional)</span></label>
        <input type="text" data-cd="town" value="${esc(d.town)}" maxlength="30" spellcheck="true" placeholder="Ex. Highlands, NJ">
        ${color('a1', 'Structure color', '(headlines, pills, bottom bar)')}
        ${color('a2', 'Accent color', '(header rule, second pill)')}
        ${color('hb', 'Header background', '')}
        ${color('bb', 'Card background', '(QR panels stay white so they scan)')}
        <div class="cd-warn" data-warn></div>
        ${slotForm('s1', 'Top QR code')}
        ${slotForm('s2', 'Bottom QR code')}
        <div class="cd-actions">
          <button type="button" class="btn" data-save>Save design</button>
          <span class="${msgClass}" data-msg></span>
        </div>
        <div class="cd-actions">
          <button type="button" class="btn ghost" data-dl>Download my table card</button>
          <button type="button" class="btn ghost" data-dlbleed>Download with bleed</button>
        </div>
        <div class="hint" style="margin-top:8px">An exact 4x6 at 300dpi for home or lab printing. The bleed version extends the background past each edge for commercial printers that trim to size. Always test-scan a printed card before a real print run.</div>
      </div>
      <div class="cd-preview"><canvas data-canvas></canvas><div class="hint" data-note style="text-align:center;margin-top:8px"></div></div>
    </div>`;
  const q = sel => host.querySelector(sel);
  const canvas = q('[data-canvas]'), msg = q('[data-msg]');
  let logoImg = null, timer = null, dirty = false;
  const setDirty = b => { dirty = b; q('[data-save]').disabled = !b; q('[data-save]').textContent = b ? 'Save design' : 'Saved'; if (opts.onDirty) opts.onDirty(b); };
  // the design as typed right now
  const read = ()=>{
    const g = k => { const e = host.querySelector(`[data-cd="${k}"]`); return e ? e.value.trim() : ''; };
    const slot = k => ({ head: g(k + '.head'), body: g(k + '.body'), scan: g(k + '.scan'), to: (host.querySelector(`input[name="cd_${k}_to"]:checked`) || {}).value || CARD_DEFAULT_SLOTS[k].to, url: g(k + '.url') });
    const hex = k => { const e = q(`[data-cdhex="${k}"]`); return HEX.test(e.value) ? e.value.toLowerCase() : d[k]; };
    return { town: g('town'), a1: hex('a1'), a2: hex('a2'), hb: hex('hb'), bb: hex('bb'), s1: slot('s1'), s2: slot('s2') };
  };
  const warn = c => {
    const w = [];
    if (contrastRatio(c.a1, c.bb) < 3) w.push('The structure color is hard to read on this card background.');
    if (contrastRatio(c.a2, c.bb) < 2) w.push('The accent color is hard to see on this card background.');
    ['s1', 's2'].forEach(k => { if (c[k].to === 'url' && c[k].url && !/^https:\/\/[^\s"'<>]{1,200}$/i.test(c[k].url)) w.push('The ' + (k === 's1' ? 'top' : 'bottom') + ' link must start with https://.'); });
    q('[data-warn]').innerHTML = w.map(esc).join('<br>');
    q('[data-warn]').style.display = w.length ? '' : 'none';
  };
  const paint = ()=>{ const c = read(); warn(c); return renderCard(canvas, v, Object.assign({}, c, { logoImg, base: opts.base })); };
  const queue = ()=>{ clearTimeout(timer); timer = setTimeout(paint, 150); };
  const touched = ()=>{ setDirty(true); msg.textContent = ''; msg.className = msgClass; queue(); };
  host.querySelectorAll('[data-cd]').forEach(e => e.addEventListener('input', touched));
  host.querySelectorAll('input[type=color][data-cd]').forEach(w => w.addEventListener('input', ()=>{ q(`[data-cdhex="${w.dataset.cd}"]`).value = w.value; }));
  host.querySelectorAll('[data-cdhex]').forEach(h => h.addEventListener('input', ()=>{ if (HEX.test(h.value)) q(`input[type=color][data-cd="${h.dataset.cdhex}"]`).value = h.value; touched(); }));
  host.querySelectorAll('input[type=radio]').forEach(r => r.addEventListener('change', ()=>{
    const k = r.name.replace('cd_', '').replace('_to', ''), isUrl = r.value === 'url';
    host.querySelector(`[data-cd="${k}.url"]`).style.display = isUrl ? '' : 'none';
    q(`[data-urlnote="${k}"]`).style.display = isUrl ? '' : 'none';
    if (isUrl) host.querySelector(`[data-cd="${k}.url"]`).focus();
    touched();
  }));
  q('[data-dl]').onclick = async ()=>{ await paint(); downloadCanvas(canvas, `${v.id}-table-card.png`); };
  q('[data-dlbleed]').onclick = async ()=>{ const b = document.createElement('canvas'); await renderCard(b, v, Object.assign({}, read(), { logoImg, base: opts.base, bleed: 38 })); downloadCanvas(b, `${v.id}-table-card-bleed.png`); };
  q('[data-save]').onclick = async ()=>{
    const c = read();
    for (const k of ['s1', 's2']) if (c[k].to === 'url' && !/^https:\/\/[^\s"'<>]{1,200}$/i.test(c[k].url)) { msg.className = msgClass + ' err'; msg.textContent = 'A link of your own must start with https://. Nothing was saved.'; return; }
    msg.className = msgClass; msg.textContent = 'Saving…'; q('[data-save]').disabled = true;
    try {
      const saved = await opts.save(c);
      v.card = saved || null;
      try { localStorage.removeItem('st_card_' + v.id); } catch(e){}
      setDirty(false);
      msg.className = msgClass + ' ok'; msg.textContent = 'Saved. Download the card whenever you like.';
    } catch(e){
      q('[data-save]').disabled = false;
      msg.className = msgClass + ' err';
      msg.textContent = e.message === 'locked' ? 'Too many passphrase tries. Wait fifteen minutes, then reload this page.'
        : (e.message === 'need_pass' || e.message === 'bad_key') ? 'Your link or passphrase no longer matches. Reload this page and sign in again.'
        : 'Could not save. Check your connection and try again.';
    }
  };
  setDirty(false);
  (async ()=>{
    q('[data-note]').textContent = 'Rendering…';
    logoImg = await loadCardLogo(v);
    await paint();
    q('[data-note]').textContent = logoImg ? '' : 'No logo image, so the header prints your name as a wordmark.';
    if (logoImg && opts.swatches){
      const sw = opts.swatches(logoImg);
      ['a1', 'a2', 'hb', 'bb'].forEach(k => {
        const box = q(`[data-sw="${k}"]`);
        box.innerHTML = sw.map(c => `<button type="button" class="cd-swatch" style="background:${c}" data-c="${c}" title="${c}" aria-label="Use ${c}"></button>`).join('');
        box.querySelectorAll('.cd-swatch').forEach(b => b.onclick = ()=>{ q(`input[type=color][data-cd="${k}"]`).value = b.dataset.c; q(`[data-cdhex="${k}"]`).value = b.dataset.c; touched(); });
      });
    }
  })();
  return { paint, isDirty: ()=> dirty };
}
