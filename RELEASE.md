# Shipping an update (the release playbook)

Work happens on `dev`. A release is: merge `dev` into `release`, with the
version stamps and migration files in the same merge. Operators sync
`release` into their forks with one dashboard button, so everything below
protects that button.

## Every release

1. Bump `const BUILD = N` in `public/admin.html` **and** `"build": N` in
   `public/version.json` — same number, same commit. The dashboard's
   Platform updates screen compares these to know a deploy landed.
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

Same release, all together (missing one of these has bitten before):

- `install/install.sql` stays the fresh-install truth: game id in
  `game_plays`' check, `log_game_play`'s whitelist, `set_venue_games` +
  `admin_set_games` allowed lists, `venues.games` default (UNLESS the
  game is venue-exclusive: then it goes in `v_excl`, never the default).
- The equivalent changes for existing operators ship as that release's
  migration JSON.
- `public/app.html`: GAME_IDS, the hub card, the screens (and
  DEFAULT_ORDER unless exclusive).
- `public/owner.html`: GAME_LIB + the gameName map (exclusives get
  `excl:true`).
- `public/admin.html`: GAMES_META (content-less games use `fields:[]`),
  GAME_ORDER.
- `public/index.html`: the game-library card (never for exclusives).
- Launch policy: new games ship OFF everywhere; operators tick them on
  per venue.

## Content updates

- Universal question batches: a migration JSON with plain INSERTs (no
  explicit ids), or a pack file in `packs/` that operators import from
  the dashboard — packs for optional/regional, migrations for baseline.
- The question style rules travel with the content pass, not here.
