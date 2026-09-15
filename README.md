# Table platform

A branded QR product for independent restaurants and bars: a table card
opens a mobile web app with a games hub and an anonymous suggestion box;
owners get a private dashboard and a monthly guest report; you (the
operator) run the whole territory from an operator dashboard.

- **Start here: [SETUP.md](SETUP.md)** — fork, database, hosting, config.
- `public/` — the site Cloudflare Pages serves: diner app, homepage,
  owner dashboard, operator dashboard, guest report. Configured entirely
  by `public/config.js` (yours; copy `config.example.js`).
- `install/` — `install.sql` (schema, run once) and
  `baseline_content.sql` (the shared question library, run once).
- `packs/` — optional content packs you can import from the dashboard's
  Question packs tool (e.g. the coastal Shore pack).
- `worker/` — the optional venue-autofill Cloudflare Worker.
- `public/migrations/` — versioned database migrations; applied through
  the dashboard's Platform updates tool, never by hand.

Licensed, not sold: see [LICENSE.txt](LICENSE.txt). Updates ship to the
`release` branch and are mirrored to the public repository
`shore-table-platform/shore-table`, which operators fork; a fork syncs
them with one button from the dashboard.
