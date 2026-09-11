#!/usr/bin/env node
// Builds public/migrations/NNN.json from migrations-src/NNN/*.sql and
// rewrites public/migrations/index.json to list every built file.
//
//   node tools/build-migration.js 005
//
// Each .sql file in the source folder holds one or more statements
// separated by a line that is exactly "-- @@". Files run in name order,
// statements in file order. Comment-only chunks are skipped. The schema
// version the JSON declares is the folder number + 1 (folder 001 was the
// first migration, which took a fresh install from schema 1 to 2).
//
// install.sql is the fresh-install truth and must carry the same function
// bodies: run tools/check-migrations.js after this to prove it does.
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const arg = process.argv[2];
if (!arg || !/^\d{3}$/.test(arg)) {
  console.error('usage: node tools/build-migration.js NNN   (e.g. 005)');
  process.exit(2);
}
const srcDir = path.join(ROOT, 'migrations-src', arg);
if (!fs.existsSync(srcDir)) { console.error('no such folder: ' + srcDir); process.exit(2); }

const files = fs.readdirSync(srcDir).filter(f => f.endsWith('.sql')).sort();
if (!files.length) { console.error('no .sql files in ' + srcDir); process.exit(2); }

const statements = [];
for (const f of files) {
  const text = fs.readFileSync(path.join(srcDir, f), 'utf8').replace(/\r\n/g, '\n');
  for (const chunk of text.split(/^-- @@\s*$/m)) {
    const s = chunk.trim().replace(/;\s*$/, '');
    if (!s) continue;
    // a chunk that is only comments has nothing to execute
    if (s.split('\n').every(l => !l.trim() || l.trim().startsWith('--'))) continue;
    statements.push(s);
  }
}

const version = parseInt(arg, 10) + 1;
const outDir = path.join(ROOT, 'public', 'migrations');
fs.writeFileSync(path.join(outDir, arg + '.json'), JSON.stringify({ version, statements }, null, 1) + '\n');

// index: every NNN.json present, in order
const list = fs.readdirSync(outDir).filter(f => /^\d{3}\.json$/.test(f)).sort()
  .map(f => ({ version: JSON.parse(fs.readFileSync(path.join(outDir, f), 'utf8')).version, file: f }));
fs.writeFileSync(path.join(outDir, 'index.json'), JSON.stringify({ migrations: list }, null, 1) + '\n');

console.log(`${arg}.json written: schema ${version}, ${statements.length} statements from ${files.length} files`);
