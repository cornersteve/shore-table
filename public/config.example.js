/* ============================================================================
   OPERATOR CONFIG  ·  copy this file to config.js and fill in your values
   ============================================================================
   config.js lives ONLY in your fork (the upstream repo never ships one, so
   syncing updates never touches yours). Create it once:
     GitHub > your fork > public/ > Add file > name it config.js >
     paste this file's contents > edit the values > commit.
   Every value here is safe to be public. The publishable Supabase key is
   DESIGNED to ship in web pages; the security model lives in the database.
   Never put your service_role key, passwords, or tokens in this file.
   ============================================================================ */
window.OPERATOR_CONFIG = {

  /* --- your Supabase project (dashboard > Settings > API) --- */
  supabaseUrl: "https://YOURPROJECT.supabase.co",
  supabaseKey: "sb_publishable_YOURKEY",

  /* --- your brand --- */
  brandName: "Table Time",              // your product name: wordmark, page titles, card footer
  domain: "https://example.com",        // your live domain, no trailing slash: QR payloads + dashboard links
  contactEmail: "hello@example.com",    // homepage contact button + privacy page
  accent: "#3a6ea5",                    // your brand color (hex): homepage accents + favicon

  /* --- your region (homepage + report copy) --- */
  regionName: "Ocean County",           // the area your venues share, as it reads in a sentence
  regionShort: "the county",            // how copy refers to the pooled network ("the county pulse");
                                        // use "the area" or "the neighborhood" if county reads wrong
  operatorStory: "",                    // optional: 1-2 first-person sentences for the homepage's
                                        // "local on purpose" section; empty = a generic line

  /* --- operator identity (dashboard email templates) --- */
  operatorName: "Your Name",
  operatorPhone: "",                    // optional, shown in your email signatures

  /* --- optional --- */
  stripePlans: [
    // { label: "Standard monthly", url: "https://buy.stripe.com/..." },
  ],
  workerUrl: "",                        // your deployed autofill Worker URL; empty hides the autofill UI
  gameNames: {},                        // diner-facing display-name overrides, e.g. { quick_pour: "Perfect Pour" }
};
