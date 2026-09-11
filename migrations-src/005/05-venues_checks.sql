update public.venues
   set google_review_link = null
 where google_review_link is not null
   and google_review_link !~* '^https://[^\s"''<>]+$';
-- @@
alter table public.venues
  add constraint venues_review_https check (google_review_link is null or google_review_link ~* '^https://[^\s"''<>]+$');
-- @@
alter table public.venues
  add constraint venues_name_len check (char_length(btrim(name)) between 1 and 80) not valid;
-- @@
alter table public.venues
  add constraint venues_logo_shape check (logo is null or (char_length(logo) <= 500 and logo !~ '[<>"]')) not valid;
