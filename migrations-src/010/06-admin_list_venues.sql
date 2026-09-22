create or replace function public.admin_list_venues()
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_operator() then return null; end if;
  return (
    select coalesce(json_agg(json_build_object(
      'id', id, 'name', name, 'status', status, 'accent', accent,
      'logo', logo, 'header_bg', header_bg, 'review', google_review_link,
      'owner_email', owner_email, 'owner_key', owner_key,
      'custom_questions', custom_questions, 'games', games,
      'custom_only', custom_only, 'has_pass', owner_pass is not null,
      'dark_mode', dark_mode, 'cards', cards, 'card', card,
      'card_cap', card_cap, 'games_enabled', games_enabled,
      'form_custom', form_custom, 'report_county', report_county,
      'pause_submissions', pause_submissions, 'created_at', created_at
    ) order by created_at desc), '[]'::json)
    from public.venues
  );
end;
$$;
