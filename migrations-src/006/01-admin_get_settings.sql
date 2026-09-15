create or replace function public.admin_get_settings()
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- the GitHub token never leaves the database on a page load: the
  -- dashboard learns only that one is set (and its last four characters,
  -- so the operator can tell which token it is); admin_get_secret hands
  -- the full value over at the moment a sync or publish needs it
  if not public.is_operator() then return null; end if;
  return (
    select coalesce(json_object_agg(key, value), '{}'::json)
    from public.operator_settings
    where key <> 'gh_token'
  )::jsonb
  || jsonb_build_object(
       'gh_token_set', exists (select 1 from public.operator_settings where key = 'gh_token' and nullif(value, '') is not null),
       'gh_token_hint', (select right(value, 4) from public.operator_settings where key = 'gh_token'));
end;
$$;
