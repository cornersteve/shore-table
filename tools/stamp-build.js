#!/usr/bin/env node
// Stamps a build number everywhere it must agree:
//   node tools/stamp-build.js 26
// public/js/admin.js (const BUILD), public/version.json ("build"), and the
// ?v= on every js/*.js script tag in the pages (a new build is a new URL,
// so browsers never pair an old script with a new page).
'use strict';
const fs = require('fs');
const path = require('path');
const ROOT = path.resolve(__dirname, '..');
const P = path.join(ROOT, 'public');
const n = parseInt(process.argv[2], 10);
if (!n) { console.error('usage: node tools/stamp-build.js N'); process.exit(2); }
const rw = (f, fn) => { const t = fs.readFileSync(f, 'utf8'); const o = fn(t); if (o !== t) fs.writeFileSync(f, o); return o !== t; };
let changed = 0;
if (rw(path.join(P, 'js', 'admin.js'), t => t.replace(/^const BUILD = \d+;/m, 'const BUILD = ' + n + ';'))) changed++;
if (rw(path.join(P, 'version.json'), t => t.replace(/"build":\s*\d+/, '"build": ' + n))) changed++;
for (const f of ['index.html', 'app.html', 'owner.html', 'report.html', 'admin.html']) {
  if (rw(path.join(P, f), t => t.replace(/(<script src="js\/[a-z-]+\.js\?v=)\d+(")/g, '$1' + n + '$2'))) changed++;
}
console.log('build ' + n + ' stamped (' + changed + ' files changed)');
