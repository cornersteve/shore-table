# Shipping an update (the release playbook)

Work happens on `dev`. A release is: merge `dev` into `release`, with the
version stamps and migration files in the same merge. Operators sync
`release` into their forks with one dashboard button, so everything below
protects that button.

## Every release

1. Bump `const BUILD = N` in `public/admin.html` **and** `"build": N` in
   `public/version.json` — same number, same commit. The dashboard's
   Platform updates screen compares these to know a deploy landed.
2. If the release needs database changes, add
   `public/migrations/NNN.json`:
   ```json
   { "version": N, "statements": ["...sql...", "...sql..."] }
   ```
   one SQL statement per array entry (the runner executes them one by
   one inside a single call), list it in `public/migrations/index.json`,
   and bump `"schema": N` in version.json. Version numbers are
   consecutive integers; the runner refuses gaps and repeats.
3. Merge `dev` -> `release` (a normal merge; **never force-push
   `release`** — a rewritten history strands every operator fork).
4. Test as operator 0 first: sync YOUR fork, apply the migration on your
   own instance, play with it live. Then announce in the community.

## Hard rules for migrations

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
- Writes stay behind SECURITY DEFINER functions; anything granted to
  `anon` gets the same scrutiny as the original surface. New admin
  functions: revoke from public AND anon, grant to authenticated, gate
  with is_operator() inside.

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
