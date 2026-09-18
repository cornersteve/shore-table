#!/usr/bin/env node
// Every game id the database knows must be wired into every page that lists
// games, or a new game silently goes missing somewhere (the Question packs
// page did not know Exquisite Corpse until build 39). Runs from
// check-migrations.js; also: node tools/check-games.js
'use strict';
const fs = require('fs');
const path = require('path');
const ROOT = path.resolve(__dirname, '..');
const read = f => fs.readFileSync(path.join(ROOT, f), 'utf8');
module.exports = function checkGames() {
  let bad = 0;
  const sql = read('install/install.sql');
  const m = sql.match(/check \(game in\s*\(([^)]*)\)\)/);
  if (!m) { console.log('FAIL  check-games: game_plays check constraint not found'); return 1; }
  const ids = [...m[1].matchAll(/'([a-z_]+)'/g)].map(x => x[1]);
  const app = read('public/js/app.js'), owner = read('public/js/owner.js'), admin = read('public/js/admin.js'), report = read('public/js/report.js'), prompts = read('public/js/prompts.js');
  const gameIds = (app.match(/const GAME_IDS = \[([^\]]*)\]/) || ['', ''])[1];
  const gameLib = owner.slice(owner.indexOf('const GAME_LIB = ['), owner.indexOf('];', owner.indexOf('const GAME_LIB = [')));
  const ownerNames = (owner.match(/const gameName = g => \(\{([^}]*)\}/) || ['', ''])[1];
  const gameOrder = (admin.match(/const GAME_ORDER = \[([^\]]*)\]/) || ['', ''])[1];
  const gamesMeta = admin.slice(admin.indexOf('const GAMES_META = {'), admin.indexOf('\n};', admin.indexOf('const GAMES_META = {')));
  const reportNames = (report.match(/\(\{guess_the_split:[^}]*\}\)\[g\.game\]/) || [''])[0];
  const where = [
    ['app.js GAME_IDS', id => gameIds.includes(`'${id}'`)],
    ['app.js hub card', id => new RegExp(`\\n\\s*${id}:\\s*\\{ ok:`).test(app)],
    ['owner.js GAME_LIB', id => gameLib.includes(`id:'${id}'`)],
    ['owner.js gameName map', id => ownerNames.includes(`${id}:`)],
    ['admin.js GAME_ORDER', id => gameOrder.includes(`'${id}'`)],
    ['admin.js GAMES_META', id => new RegExp(`\\n\\s*${id}:\\s*\\{ name:`).test(gamesMeta)],
    ['report.js name map', id => reportNames.includes(`${id}:`)],
  ];
  for (const id of ids) for (const [label, test] of where) if (!test(id)) { console.log(`FAIL  check-games: ${id} is missing from ${label}`); bad++; }
  // every in-app prompt bank belongs to a known game, and every code-held bank is registered
  const banks = [...((prompts.match(/const PROMPT_BANKS = \{([\s\S]*?)\n\};/) || ['', ''])[1]).matchAll(/^\s*([a-z_]+):/gm)].map(x => x[1]);
  for (const b of banks) if (!ids.includes(b)) { console.log(`FAIL  check-games: PROMPT_BANKS lists unknown game ${b}`); bad++; }
  if (/^const (EC_PROMPTS|SC_WORDS|[A-Z_]+_PROMPTS) = /m.test(app)) { console.log('FAIL  check-games: a prompt bank is declared in app.js; it belongs in js/prompts.js'); bad++; }
  if (!bad) console.log(`ok    ${ids.length} game ids wired into app, owner, admin, report; ${banks.length} in-app prompt bank(s) registered`);
  return bad;
};
if (require.main === module) process.exit(module.exports() ? 1 : 0);
