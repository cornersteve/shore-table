/* Shore Table: helpers shared by every page. Loaded after config.js and
   brand.js, before the page's own script. Classic scripts share one global
   scope, so a page script must not declare these names again. */
const $ = id => document.getElementById(id);
function esc(s){ return String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
const escHtml = esc;   // the diner app's name for it
// a promise that gives up after ms (loading screens, saves, votes)
const withTimeout = (p, ms)=> Promise.race([p, new Promise((_, rej)=> setTimeout(()=> rej(new Error('timeout')), ms))]);
// ink or white on a given background (WCAG luminance); the diner app keeps
// its own copy with the app's ink token
function readableOn(hex){
  const c=(hex||'').replace('#',''); if(c.length<6) return '#16110a';
  const f=x=>{x/=255; return x<=.03928?x/12.92:Math.pow((x+.055)/1.055,2.4);};
  const L=.2126*f(parseInt(c.slice(0,2),16))+.7152*f(parseInt(c.slice(2,4),16))+.0722*f(parseInt(c.slice(4,6),16));
  return L>.55 ? '#16110a' : '#ffffff';
}

/* Curated card icons, drawn in the same stroke style as the landing tiles.
   Keys are what the owner editors save; an unknown key falls back to the
   star, so removing an icon from this set can never blank a card. */
const CI = inner => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${inner}</svg>`;
// the line under a card's name on the home screen. A link announcement
// carries its message in body, like an inline one (older ones saved desc).
const cardSub = c => !c ? '' : (c.t === 'notice' && c.mode === 'link') ? (c.body || c.desc || '') : (c.desc || '');
// what a banner announcement prints under its name, whichever kind it is
const cardBannerText = c => (c && (c.mode || 'inline') === 'inline') ? (c.body || '') : cardSub(c);
const CARD_ICONS = {
  calendar: CI('<rect x="3" y="4.5" width="18" height="16.5" rx="3"/><path d="M8 2.5v4M16 2.5v4M3 10h18"/>'),
  clock: CI('<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3.2 1.9"/>'),
  beer: CI('<path d="M7 4.5h8.5v14.5a1.8 1.8 0 0 1-1.8 1.8H8.8A1.8 1.8 0 0 1 7 19z"/><path d="M15.5 8.5h1.9a1.9 1.9 0 0 1 1.9 1.9v2.7a1.9 1.9 0 0 1-1.9 1.9h-1.9M10 8.5V17M12.5 8.5V17"/>'),
  wine: CI('<path d="M8 3.5h8c0 5.2-1.7 7.8-4 7.8s-4-2.6-4-7.8z"/><path d="M12 11.3v8.2M8.5 20.5h7"/>'),
  cocktail: CI('<path d="M4.5 4.5h15L12 13.2z"/><path d="M12 13.2v6.3M8.5 20.5h7M8 8h8"/>'),
  coffee: CI('<path d="M4.5 9.5h12v6.5a3.5 3.5 0 0 1-3.5 3.5H8a3.5 3.5 0 0 1-3.5-3.5z"/><path d="M16.5 11.5h1.3a2.4 2.4 0 0 1 0 4.8h-1.4M8.2 3.5c0 1.3 1 1.4 1 2.7M12.2 3.5c0 1.3 1 1.4 1 2.7"/>'),
  plate: CI('<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="4.2"/>'),
  pizza: CI('<path d="M4 6a18.5 18.5 0 0 1 16 0L12 21z"/><circle cx="9.6" cy="8.6" r="1.05" fill="currentColor" stroke="none"/><circle cx="14.4" cy="8.9" r="1.05" fill="currentColor" stroke="none"/><circle cx="12" cy="12.6" r="1.05" fill="currentColor" stroke="none"/>'),
  burger: CI('<path d="M4 10a8 8 0 0 1 16 0z"/><path d="M4 13.5h16"/><path d="M4.5 17h15v.8a2.7 2.7 0 0 1-2.7 2.7H7.2a2.7 2.7 0 0 1-2.7-2.7z"/>'),
  dessert: CI('<path d="M7.5 10.5a4.5 4.5 0 1 1 9 0"/><path d="M7.5 10.5h9L12 21z"/>'),
  music: CI('<path d="M9 18.5V6.2l10-2.2v12.3"/><circle cx="6.6" cy="18.6" r="2.4"/><circle cx="16.6" cy="16.4" r="2.4"/>'),
  mic: CI('<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21M8.5 21h7"/>'),
  trophy: CI('<path d="M7 4h10v6a5 5 0 0 1-10 0z"/><path d="M7 6H4a3 3 0 0 0 3.2 4M17 6h3a3 3 0 0 1-3.2 4M12 15v3.5M8 21h8l-.9-2.5H8.9z"/>'),
  star: CI('<path d="m12 3.5 2.6 5.3 5.9.9-4.3 4.1 1 5.8-5.2-2.7-5.2 2.7 1-5.8-4.3-4.1 5.9-.9z"/>'),
  tag: CI('<path d="M3.5 12.5v-9h9L21 12l-8.5 8.5z"/><circle cx="8" cy="8" r="1.4"/>'),
  gift: CI('<rect x="4" y="9.5" width="16" height="11" rx="2"/><path d="M12 9.5v11M4 13.5h16M7.5 6.7A2.1 2.1 0 0 1 11.3 5c.7 1 .7 4.5.7 4.5S8 9.7 7.5 6.7zM16.5 6.7A2.1 2.1 0 0 0 12.7 5c-.7 1-.7 4.5-.7 4.5s4 .2 4.5-2.8z"/>'),
  dice: CI('<rect x="3.5" y="3.5" width="17" height="17" rx="4.5"/><circle cx="8.4" cy="8.4" r="1.15" fill="currentColor" stroke="none"/><circle cx="15.6" cy="8.4" r="1.15" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.15" fill="currentColor" stroke="none"/><circle cx="8.4" cy="15.6" r="1.15" fill="currentColor" stroke="none"/><circle cx="15.6" cy="15.6" r="1.15" fill="currentColor" stroke="none"/>'),
  megaphone: CI('<path d="M3.5 10.2v3.6l3.2.6L18.5 19V5L6.7 9.6z"/><path d="M18.5 9.2a3.1 3.1 0 0 1 0 5.6M7.8 14.8l1 5.2h2.9l-.8-4.6"/>'),
  info: CI('<circle cx="12" cy="12" r="8.5"/><path d="M12 11.2v5.3"/><circle cx="12" cy="7.8" r="1.1" fill="currentColor" stroke="none"/>'),
  pin: CI('<path d="M12 21s-7-6.4-7-11.4a7 7 0 0 1 14 0C19 14.6 12 21 12 21z"/><circle cx="12" cy="9.6" r="2.5"/>'),
  book: CI('<path d="M12 6.2C10.5 4.5 7.5 4.1 4 4.6V19c3.5-.5 6.5-.1 8 1.6 1.5-1.7 4.5-2.1 8-1.6V4.6c-3.5-.5-6.5-.1-8 1.6z"/><path d="M12 6.2v14.4"/>'),
  flame: CI('<path d="M12 3.5c.8 2.9-4.7 5.3-4.7 9.9a4.7 4.7 0 0 0 9.4 0c0-1.9-.9-3.4-1.9-4.5-.1 1.4-.7 2.2-1.5 2.5.9-2.4-.6-5.7-1.3-7.9z"/>'),
  leaf: CI('<path d="M5 19C5 9.5 12 4.5 20 4.5c0 8-5 14.5-15 14.5z"/><path d="M5 19c3-6 7-9 11-11"/>'),
  heart: CI('<path d="M12 20.5S3.5 15 3.5 8.9A4.4 4.4 0 0 1 12 7.3a4.4 4.4 0 0 1 8.5 1.6C20.5 15 12 20.5 12 20.5z"/>'),
  sun: CI('<circle cx="12" cy="12" r="4.4"/><path d="M12 2.5v2.6M12 18.9v2.6M2.5 12h2.6M18.9 12h2.6M5.2 5.2 7 7M17 17l1.8 1.8M18.8 5.2 17 7M7 17l-1.8 1.8"/>'),
  moon: CI('<path d="M20 13.6A8.5 8.5 0 1 1 10.4 4 7 7 0 0 0 20 13.6z"/>'),
  taco: CI('<path d="M3.5 18.5a8.5 8.5 0 0 1 17 0z"/><path d="M4.6 13.4a2.3 2.3 0 0 1 3.2-2.7 2.5 2.5 0 0 1 4.2-2 2.5 2.5 0 0 1 4.2 2 2.3 2.3 0 0 1 3.2 2.7"/><path d="M9 15.6h.01M12 13.8h.01M15 15.6h.01"/>'),
  glass: CI('<path d="M6.5 7h11l-1.2 12.2a2 2 0 0 1-2 1.8H9.7a2 2 0 0 1-2-1.8z"/><path d="M7 11.5h10M13 7l1.8-4H17"/>'),
  cake: CI('<path d="M4 20.5h16v-7a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2z"/><path d="M4 16c1.3 1.2 2.7 1.2 4 0s2.7-1.2 4 0 2.7 1.2 4 0 2.7-1.2 4 0M12 11.5V8M12 5.3h.01"/>'),
  fish: CI('<path d="M3 12c3-4.5 9-5.5 13.5-2.2L21 7v10l-4.5-2.8C12 17.5 6 16.5 3 12z"/><path d="M8 11.5h.01"/>'),
  icecream: CI('<path d="M7.2 11a4.8 4.8 0 1 1 9.6 0z"/><path d="M7.5 11L12 21l4.5-10"/>'),
  bowl: CI('<path d="M3.5 11.5h17a8.5 8.5 0 0 1-17 0z"/><path d="M8 20.5h8M9.5 4c0 1.3 1 1.5 1 2.8M13.5 4c0 1.3 1 1.5 1 2.8"/>'),
  tv: CI('<rect x="3" y="5" width="18" height="12.5" rx="2"/><path d="M8.5 21h7M12 17.5V21"/>'),
  bag: CI('<path d="M5.5 8.5h13l1 12h-15z"/><path d="M9 8.5V7a3 3 0 0 1 6 0v1.5"/>'),
  sparkle: CI('<path d="M11 3.5l1.6 4.9 4.9 1.6-4.9 1.6L11 16.5l-1.6-4.9-4.9-1.6 4.9-1.6z"/><path d="M18 14.5l.9 2.6 2.6.9-2.6.9-.9 2.6-.9-2.6-2.6-.9 2.6-.9z"/>')
};
