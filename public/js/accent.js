/* the operator accent lands before first paint, so the panels never flash
   the default blue on a differently colored instance */
(function(){
  var C = Object.assign({}, window.OPERATOR_CONFIG || {}, window.OPERATOR_BRAND || {});
  var m = /^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(C.accent || '');
  if(!m) return;
  document.documentElement.style.setProperty('--accent', C.accent);
  // white text on a light accent fails contrast; ink text takes over past the 4.5:1 line
  var lin = function(h){ var v = parseInt(h, 16) / 255; return v <= .03928 ? v / 12.92 : Math.pow((v + .055) / 1.055, 2.4); };
  var L = .2126 * lin(m[1]) + .7152 * lin(m[2]) + .0722 * lin(m[3]);
  document.documentElement.style.setProperty('--on-accent', (1.05 / (L + .05)) >= 4.5 ? '#ffffff' : '#16110a');
  var tc = document.querySelector('meta[name="theme-color"]'); if(tc) tc.setAttribute('content', C.accent);
})();
