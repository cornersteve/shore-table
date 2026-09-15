# Setup — from zero to your first table card

One evening of setup, on accounts you own. You will create: a GitHub fork,
a Supabase project (the database), and a Cloudflare Pages site (the
hosting). Everything is free tier to start except Supabase Pro
(recommended once you have a paying venue, for daily backups).

## 1. Fork the repository

- On GitHub, fork the public release repository
  `shore-table-platform/shore-table` to your own account (Fork > Create
  fork). That repository carries the `release` branch only; it is the one
  your fork updates from.
- Your fork is where your site deploys from. You never edit code in it;
  the only file you ever add is your config (step 5).

## 2. Supabase (the database)

1. Create a project at supabase.com (any name; pick a strong database
   password and store it in your password manager). On the creation form:
   skip the GitHub connection (updates flow through the dashboard, not
   Supabase-GitHub); leave compute at the default; under Security keep
   **Enable Data API ON**, leave **Automatically expose new tables**
   DISABLED (install.sql grants exactly what should be public), and turn
   **Enable automatic RLS ON**.
2. Authentication > Sign In / Up: **disable public signups**.
3. Authentication > Users: **Add user** — your operator email + a strong
   password. This is your dashboard login.
4. Authentication > URL Configuration: set the Site URL to your domain
   (step 6), and add these to Additional Redirect URLs (wildcards on purpose: hosting serves /admin and /admin.html interchangeably, and a reset link whose return address is not on the list silently falls back to the Site URL): `https://<your-domain>/*`, `https://<your-pages-project>.pages.dev/*` (add it at step 3 when you know it), and `http://localhost:5599/*`.
5. Storage: **New bucket** named exactly `restaurant logos`, PUBLIC.
6. SQL Editor: open `install/install.sql` from the repo, **edit the one
   marked line** (your operator email), paste the whole file, Run.
   If it errors, read the message: the usual cause is the email line.
7. SQL Editor: paste and run `install/baseline_content.sql` (the shared
   question library).
8. Settings > API: copy the Project URL and the publishable (anon) key
   for step 5.

Recommended hardening while you are in there: Authentication > Passwords
minimum length 12+, leaked-password protection ON, and 2FA on your
Supabase account itself.

## 3. Cloudflare Pages (the hosting)

1. Create a Cloudflare account; add your domain (registrar nameservers
   point at Cloudflare).
2. Workers & Pages > Create > Pages > **Connect to Git** > pick your
   fork.
   - Production branch: `release`
   - Build command: (none)
   - Build output directory: `public`
3. Add your custom domain to the Pages project.
4. Security > Bot Fight Mode: ON. Consider a basic rate-limiting rule.
5. 2FA on your Cloudflare account.

## 4. Your logo files

- Replace nothing in code. Add to your fork's `public/` via the GitHub
  web editor if you want: `apple-touch-icon.png` (180x180 PNG, your
  mark, full bleed) improves add-to-home-screen on iPhones. The phones on
  the homepage and the sharing card (`images/og.png`) draw themselves from
  your Settings and your demo venue, so there are no screenshots to make.

## 5. Your config

- In your fork on GitHub: `public/` > Add file > Create new file >
  name it `config.js` > paste the contents of `public/config.example.js`
  and fill in the two values (Supabase URL + key from step 2.8).
- Commit. Pages redeploys automatically. This file exists only in your
  fork, so platform updates never touch it.
- Everything else about your brand is set from the dashboard in step 6;
  you never edit another file.

## 6. First login + first venue

1. Open `https://<your-domain>/admin.html`, sign in with your operator
   email + password.
2. The first screen is the brand setup: your name, brand color, icon and
   logo, region wording, contact details. (Your site address is never
   typed: the pages read it from wherever they are served.) Connect GitHub
   first (step 7) so **Save and publish** can write `public/brand.js`
   into your fork; your pages then carry the brand from their first
   paint. You can change any of it later under Tools > Settings.
3. Add your first venue: name, logo upload, accent color, Google review
   link. Leave the built-in `demo` venue alone: it is Corner & Oak Bar &
   Grill, a made-up restaurant that powers the homepage's Try the demo
   button and phone screens, and platform updates keep it current. To
   show your own restaurant there instead, pick it under Settings > Demo
   venue.
4. Open the venue, download its table card PNG, print, scan, play.

## 7. Staying updated

Dashboard > Tools > **Platform updates**:

- Connect it once: your fork as `owner/repo` and a GitHub
  **fine-grained** personal access token from the account that owns your
  fork (GitHub > Settings > Developer settings > Personal access tokens >
  Fine-grained). Repository access: **only your fork**. Permissions:
  **Contents, Read and write**. Expiration: up to one year; put the date
  in the dashboard's "Token expires" field and it reminds you a month
  out. The token is stored in your database, never in git, and the
  dashboard never shows it again after you save it. It can do nothing to
  any other repository you own. (If GitHub ever refuses the update with a
  fine-grained token, a classic token with the `repo` scope also works;
  it is simply broader than needed.)
- When an update ships, press **Sync fork from upstream**. Pages
  redeploys; the page reloads itself; if the update needs database
  changes, an **Apply pending migrations** button appears — press it.
  Never paste update SQL by hand; the runner applies each migration
  exactly once, in order.

## 8. Optional: the website autofill Worker

`worker/autofill-worker.js` speeds up venue onboarding (fetches a
restaurant site's name/logo/colors). Setup steps are in that file's
header: create a Cloudflare Worker, paste the file, set its three
environment variables, then paste the Worker URL under Tools >
Settings > Advanced. Skip it entirely and the Add-venue form is simply
fully manual.

## Rules that keep you safe

- Venue ids and question ids are permanent. Retire content; never
  delete it.
- The Google review prompt is shown to everyone, never rating-gated
  (Google policy and FTC rules).
- Never put your service_role key in any page or file. The publishable
  key is the only one that ships.
- Never seed or fabricate survey feedback. Game content is seeded;
  business intelligence never is.
- Roll back a bad deploy in Cloudflare Pages (Deployments > Rollback);
  database migrations are designed so a file rollback never needs a
  database rollback.
