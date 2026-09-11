create or replace function public.admin_export_all()
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- one JSON document with everything an operator would need to rebuild
  -- their instance: venues (owner links and passphrase hashes included,
  -- so the links keep working after a restore), all feedback, game
  -- counters, a year of analytics events, forms, content (with each
  -- row's status), and settings minus the GitHub token
  if not public.is_operator() then return null; end if;
  return json_build_object(
    'format', 'shore-table-backup',
    'exported_at', now(),
    'schema', (select coalesce(max(version), 0) from public.schema_migrations),
    'venues', (select coalesce(json_agg(v order by v.created_at), '[]'::json) from public.venues v),
    'survey_responses', (select coalesce(json_agg(s order by s.id), '[]'::json) from public.survey_responses s),
    'game_plays', (select coalesce(json_agg(g order by g.venue_id, g.game), '[]'::json) from public.game_plays g),
    'events_365d', (select coalesce(json_agg(e order by e.id), '[]'::json) from public.events e where e.created_at > now() - interval '365 days'),
    'feedback_forms', (select coalesce(json_agg(f order by f.id), '[]'::json) from public.feedback_forms f),
    'gts_questions', (select coalesce(json_agg(q order by q.id), '[]'::json) from public.gts_questions q),
    'wkw_questions', (select coalesce(json_agg(q order by q.id), '[]'::json) from public.wkw_questions q),
    'trivia_questions', (select coalesce(json_agg(q order by q.id), '[]'::json) from public.trivia_questions q),
    'wordy_words', (select coalesce(json_agg(w order by w.word), '[]'::json) from public.wordy_words w),
    'wiy_words', (select coalesce(json_agg(w order by w.id), '[]'::json) from public.wiy_words w),
    'fortunes', (select coalesce(json_agg(f order by f.id), '[]'::json) from public.fortunes f),
    'at_categories', (select coalesce(json_agg(a order by a.id), '[]'::json) from public.at_categories a),
    'operator_settings', (select coalesce(json_agg(o order by o.key), '[]'::json) from public.operator_settings o where o.key <> 'gh_token'),
    'schema_migrations', (select coalesce(json_agg(m order by m.version), '[]'::json) from public.schema_migrations m)
  );
end;
$$;
-- @@
revoke all on function public.admin_export_all() from public;
-- @@
revoke execute on function public.admin_export_all() from anon;
-- @@
grant execute on function public.admin_export_all() to authenticated;
