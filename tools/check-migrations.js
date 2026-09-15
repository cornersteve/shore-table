#!/usr/bin/env node
// Release gate for the database side. Proves that a fresh install and a
// migrated instance end up identical, and that the version stamps agree.
//
//   node tools/check-migrations.js
//
// Checks:
//  1. every migrations-src/NNN folder has a built public/migrations/NNN.json
//     whose statements match the source exactly (run build-migration.js);
//  2. index.json lists every built file, versions consecutive from 2;
//  3. version.json's "schema" equals the newest migration version, and
//     install.sql seeds schema_migrations with every version through it;
//  4. every function, table, view, grant, revoke and default-privilege
//     statement in the NEWEST migration appears verbatim (whitespace and
//     comments aside) in install/install.sql, so a fresh install carries
//     the same definitions an operator gets by pressing Apply.
//     (alter table / update / drop statements are exempt: a fresh install
//     expresses those inside its create table statements.)
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(p, 'utf8').replace(/\r\n/g, '\n');
let bad = 0;
const fail = m => { console.log('FAIL  ' + m); bad++; };
const ok = m => console.log('ok    ' + m);

// comments out, whitespace collapsed, trailing semicolon dropped
const norm = s => s
  .split('\n').map(l => l.replace(/--.*$/, '')).join('\n')
  .replace(/\s+/g, ' ').replace(/\s*;\s*$/, '').trim().toLowerCase();

const splitStatements = text => text.split(/^-- @@\s*$/m).map(c => c.trim().replace(/;\s*$/, ''))
  .filter(s => s && !s.split('\n').every(l => !l.trim() || l.trim().startsWith('--')));

const srcRoot = path.join(ROOT, 'migrations-src');
const outDir = path.join(ROOT, 'public', 'migrations');
const folders = fs.existsSync(srcRoot) ? fs.readdirSync(srcRoot).filter(f => /^\d{3}$/.test(f)).sort() : [];

// 1. built JSON matches source
for (const f of folders) {
  const files = fs.readdirSync(path.join(srcRoot, f)).filter(x => x.endsWith('.sql')).sort();
  const want = [];
  for (const x of files) want.push(...splitStatements(read(path.join(srcRoot, f, x))));
  const jp = path.join(outDir, f + '.json');
  if (!fs.existsSync(jp)) { fail(`migrations-src/${f} has no public/migrations/${f}.json (run build-migration.js ${f})`); continue; }
  const j = JSON.parse(read(jp));
  if (j.version !== parseInt(f, 10) + 1) fail(`${f}.json declares version ${j.version}, expected ${parseInt(f, 10) + 1}`);
  const got = j.statements.map(s => s.replace(/\r\n/g, '\n').trim());
  if (got.length !== want.length || got.some((s, i) => s !== want[i])) fail(`${f}.json statements differ from migrations-src/${f} (rebuild it)`);
  else ok(`${f}.json matches its source (${want.length} statements)`);
}

// 2. index lists every built file, consecutive versions
const built = fs.readdirSync(outDir).filter(x => /^\d{3}\.json$/.test(x)).sort();
const index = JSON.parse(read(path.join(outDir, 'index.json'))).migrations || [];
const versions = built.map(x => JSON.parse(read(path.join(outDir, x))).version);
if (index.length !== built.length || index.some((m, i) => m.file !== built[i] || m.version !== versions[i])) fail('index.json does not list exactly the built migrations in order');
else ok(`index.json lists ${built.length} migrations`);
versions.forEach((v, i) => { if (v !== i + 2) fail(`migration versions must run 2, 3, ...; ${built[i]} is ${v}`); });
const newest = versions.length ? versions[versions.length - 1] : 1;

// 3. stamps
const vj = JSON.parse(read(path.join(ROOT, 'public', 'version.json')));
if (vj.schema !== newest) fail(`version.json schema is ${vj.schema}, newest migration is ${newest}`);
else ok(`version.json schema ${vj.schema}`);
const sql = read(path.join(ROOT, 'install', 'install.sql'));
const seedWant = 'insert into schema_migrations (version) values ' + Array.from({ length: newest }, (_, i) => `(${i + 1})`).join(', ') + ';';
if (!sql.includes(seedWant)) fail(`install.sql must seed: ${seedWant}`);
else ok('install.sql seeds every schema version');
const adminJs = read(path.join(ROOT, 'public', 'js', 'admin.js'));
const bm = adminJs.match(/^const BUILD = (\d+);/m);
if (!bm || parseInt(bm[1], 10) !== vj.build) fail(`js/admin.js BUILD (${bm && bm[1]}) and version.json build (${vj.build}) differ`);
else ok(`build ${vj.build} stamped in js/admin.js and version.json`);
for (const f of ['index.html', 'app.html', 'owner.html', 'report.html', 'admin.html']) {
  const page = read(path.join(ROOT, 'public', f));
  if (/<script(?![^>]*\bsrc=)[^>]*>\s*\S/.test(page)) fail(`${f} has an inline <script> (the CSP refuses those since build 25)`);
  const stamps = [...page.matchAll(/<script src="js\/[a-z-]+\.js\?v=(\d+)"/g)].map(m => +m[1]);
  if (!stamps.length || stamps.some(s => s !== vj.build)) fail(`${f} script tags are not all stamped ?v=${vj.build} (run tools/stamp-build.js ${vj.build})`);
}
ok('pages carry no inline script and every js tag is stamped');

// 4. newest migration's definitions are in install.sql
if (folders.length) {
  const f = folders[folders.length - 1];
  const nsql = norm(sql);
  const files = fs.readdirSync(path.join(srcRoot, f)).filter(x => x.endsWith('.sql')).sort();
  let n = 0;
  for (const x of files) for (const s of splitStatements(read(path.join(srcRoot, f, x)))) {
    const head = norm(s).slice(0, 40);
    const checked = /^(create or replace function|create or replace view|create table|create index|grant |revoke |alter default privileges|comment on)/.test(head);
    if (!checked) continue;
    n++;
    const ns = norm(s).replace(/^create table if not exists /, 'create table ').replace(/^create table public\./, 'create table ')
      .replace(/^comment on table public\./, 'comment on table ');
    if (!nsql.includes(ns)) fail(`install.sql lacks this ${f} statement: ${s.split('\n')[0].slice(0, 90)}`);
  }
  ok(`${n} definitions from migrations-src/${f} checked against install.sql`);
}

console.log(bad ? `\n${bad} problem(s)` : '\nall good');
process.exit(bad ? 1 : 0);
