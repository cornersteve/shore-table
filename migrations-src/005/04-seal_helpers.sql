revoke all on function public.clean_cards(jsonb, integer) from public, anon, authenticated;
-- @@
revoke all on function public.clean_card_url(text) from public, anon, authenticated;
-- @@
alter default privileges in schema public revoke execute on functions from public;
