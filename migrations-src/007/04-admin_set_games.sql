create or replace function public.admin_set_games(p_id text, p_games text[])
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_clean   text[];
  v_allowed constant text[] := array
    ['who_knows_who','guess_the_split','wordy','trivia','who_invited_you','fortune_teller','all_talk','cornhole','quick_pour','horse_racing','ring_toss','exquisite_corpse'];
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  if not exists (select 1 from public.venues where id = p_id) then
    return json_build_object('ok', false, 'error', 'no_such_venue');
  end if;

  select array_agg(g order by ord) into v_clean
    from (select g, min(ord) as ord
            from unnest(coalesce(p_games, array[]::text[])) with ordinality as t(g, ord)
           where g = any(v_allowed)
           group by g) s;

  if v_clean is null or array_length(v_clean, 1) < 1 then
    return json_build_object('ok', false, 'error', 'empty_list');
  end if;

  update public.venues set games = v_clean where id = p_id;
  return json_build_object('ok', true, 'games', v_clean);
end;
$$;
