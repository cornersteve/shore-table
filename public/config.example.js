/* ============================================================================
   OPERATOR CONFIG  ·  copy this file to config.js and fill in the two values
   ============================================================================
   config.js lives ONLY in your fork (the upstream repo never ships one, so
   syncing updates never touches yours). Create it once:
     GitHub > your fork > public/ > Add file > name it config.js >
     paste this file's contents > edit the two values > commit.
   Everything else about your brand (name, colors, logo, region wording,
   contact details, plans) is set from the dashboard: Tools > Settings.
   The dashboard writes those into public/brand.js in your fork, so your
   pages carry the brand from their very first paint.
   Both values here are safe to be public. The publishable Supabase key is
   DESIGNED to ship in web pages; the security model lives in the database.
   Never put your service_role key, passwords, or tokens in this file.
   ============================================================================ */
window.OPERATOR_CONFIG = {
  /* --- your Supabase project (dashboard > Settings > API) --- */
  supabaseUrl: "https://YOURPROJECT.supabase.co",
  supabaseKey: "sb_publishable_YOURKEY",
};
