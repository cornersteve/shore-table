create or replace function public.set_venue_games(p_venue_id text, p_key text, p_games text[], p_pass text default null)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row     public.venues%rowtype;
  v_clean   text[];
  v_allowed constant text[] := array['who_knows_who','guess_the_split','wordy','trivia','who_invited_you','fortune_teller','all_talk','cornhole','quick_pour','exquisite_corpse'];
  v_excl    constant text[] := array['horse_racing','ring_toss'];   -- keepable, never addable
begin
  if public.owner_gate(p_venue_id, p_key, p_pass) <> 'ok' then
    return false;
  end if;
  select * into v_row from public.venues where id = p_venue_id;

  select array_agg(g order by ord) into v_clean
    from (select g, min(ord) as ord
            from unnest(coalesce(p_games, array[]::text[])) with ordinality as t(g, ord)
           where g = any(v_allowed)
              or (g = any(v_excl) and g = any(coalesce(v_row.games, array[]::text[])))
           group by g) s;

  if v_clean is null or array_length(v_clean, 1) < 1 then
    return false;
  end if;

  update public.venues set games = v_clean where id = p_venue_id;
  return true;
end;
$$;
