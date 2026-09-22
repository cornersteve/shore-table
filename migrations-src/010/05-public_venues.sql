create or replace view public.public_venues
with (security_invoker = off) as
  select id, name, logo, accent, google_review_link,
         games,
         custom_questions,
         header_bg,
         custom_only,
         dark_mode,
         cards,
         card,
         games_enabled,
         form_custom,
         report_county,
         (status = 'lead') as demo
  from public.venues
  where status in ('lead', 'active');
-- @@
grant select on public.public_venues to anon, authenticated;
