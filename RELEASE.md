# Shipping an update (the release playbook)

Work happens on `dev`. A release is: merge `dev` into `release`, with the
version stamps and migration files in the same merge. Operators sync
`release` into their forks with one dashboard button, so everything below
protects that button.

## Every release

1. Stamp the build: `node tools/stamp-build.js N`. That sets `const BUILD`
   in `public/js/admin.js`, `"build"` in `public/version.json`, and the
   `?v=N` on every `js/*.js` script tag in the pages, all in one go. The
   dashboard's Platform updates screen compares the first two to know a
   deploy landed; the third makes a new build a new script URL, so no
   browser ever pairs an old script with a new page. Scripts live in
   `public/js/` (one file per page plus `shared.js`); the pages carry no
   inline script and the CSP refuses any.
2. If the release needs database changes, write the SQL ONCE under
   `migrations-src/NNN/*.sql` (files run in name order; several
   statements in one file are separated by a line that is exactly
   `-- @@`), then:
   ```
   node tools/build-migration.js NNN
   ```
   writes `public/migrations/NNN.json` (`{ "version": NNN+1,
   "statements": [...] }`, one statement per entry: the runner executes
   them one by one inside a single call) and rewrites index.json. Put
   the SAME definitions in `install/install.sql` (fresh installs must
   land where migrated ones do), bump `"schema"` in version.json and the
   `insert into schema_migrations` seed line, then run
   ```
   node tools/check-migrations.js
   ```
   which fails the release if the JSON is stale, the stamps disagree, or
   a function/table/grant in the newest migration is missing from
   install.sql. Version numbers are consecutive integers; the runner
   refuses gaps and repeats.
3. Merge `dev` -> `release` (a normal merge; **never force-push
   `release`** — a rewritten history strands every operator fork). The
   repository is public on purpose: operators fork it directly and use
   a fine-grained token scoped to their own fork. Sales assets, the
   venue agreement, and premium packs live in the community, never here.
4. Post plain-language release notes in the community; once the notes
   page exists, point NOTES_URL in admin.html at it (the dashboard
   shows a What's-new link when it is set).
5. Test as operator 0 first: sync YOUR fork, apply the migration on your
   own instance, play with it live. Then announce in the community.

## Hard rules for migrations

- The demo venue (id `demo`, Corner & Oak Bar & Grill) is platform data:
  a migration may upsert its name, logo, accent, and cards so every
  instance's demo shows new features. Never write to any other venue row.
  Operators who want their own restaurant as the demo pick it under
  Settings > Demo venue (brand key `demoVenue`), so the row stays ours.

- **Additive with a window.** New columns, tables, functions: fine.
  Removing or renaming something the currently-deployed pages read:
  only after a full release cycle in which no shipped page reads it.
  This is what makes Cloudflare's deployment rollback safe without ever
  rolling back a database.
- **No explicit row ids in shipped content.** Install-time seeds use
  explicit ids; anything inserted by a migration must let the identity
  column assign ids, because each operator's sequences have advanced
  differently (their custom rows). Ids only need to be permanent within
  an instance, never equal across instances.
- **Never DELETE content.** Retire by status. (The one historical
  exception was the platform-reset cutover.)
- A new table that pages read DIRECTLY (not via an RPC) needs its own
  `grant select ... to anon, authenticated` in the same migration:
  projects created with 'automatically expose new tables' disabled
  grant nothing by default. Definer-function access needs no grant.
- Writes stay behind SECURITY DEFINER functions; anything granted to
  `anon` gets the same scrutiny as the original surface. New admin
  functions: revoke from public AND anon, grant to authenticated, gate
  with is_operator() inside.

- Every new admin view with a FORM calls draftify(key, [field ids])
  after painting and draftClear(key) on successful save: backgrounded
  tabs get evicted and reload, and unsaved fields must survive it.

- **Never edit `public/brand.js` or anything under `public/brand/`
  upstream.** The dashboard Settings commits those into each fork; the
  upstream placeholder must stay byte-identical forever so the sync
  merge never conflicts with an operator's generated brand. New brand
  keys: add them to BRAND_KEYS + the Settings form in admin.html and
  read them from CFG (config.js stays the fallback).

## Shipping a new game

Same release, all together. `node tools/check-migrations.js` (which runs
tools/check-games.js) refuses the release if a game id known to the database
is missing from any of the lists below, so run it before you push.

- `install/install.sql` stays the fresh-install truth: game id in
  `game_plays`' check, `log_game_play`'s whitelist, `set_venue_games` +
  `admin_set_games` allowed lists (UNLESS the game is venue-exclusive: then
  it goes in `v_excl`, never the default). The equivalent changes for
  existing operators ship as that release's migration JSON.
- `public/js/app.js`: GAME_IDS, GAME_HOME (the screen prefix), the hub card
  + its wire() line, the screens (and DEFAULT_ORDER unless exclusive).
- `public/js/owner.js`: GAME_LIB (exclusives get `excl:true`) + the
  gameName map.
- `public/js/admin.js`: GAMES_META (content-less games use `fields:[]`),
  GAME_ORDER.
- `public/js/report.js`: the game name map.
- GNAME defaults (app, owner, admin, report) only if the diner-facing name
  should be operator-configurable.
- Prompts or words that live in code (no question packs) go in
  `public/js/prompts.js` and are registered in PROMPT_BANKS there. That is
  how the dashboard's Question packs page counts them.
- `public/index.html`: the game-library card (never for exclusives).
- Launch policy: new games ship OFF everywhere; operators tick them on
  per venue. Preview with `?try=<id>`.

The same idea applies to any feature that touches a list: if it appears in
the owner dashboard, look for its twin in the operator dashboard (the card
editor, game toggles and feedback form live in both), and the reverse.

## Content updates

- Universal question batches: a migration JSON with plain INSERTs (no
  explicit ids), or a pack file in `packs/` that operators import from
  the dashboard — packs for optional/regional, migrations for baseline.
- The question style rules travel with the content pass, not here.
