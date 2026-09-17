create or replace function public.log_game_play(p_venue_id text, p_game text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status public.venue_status;
  v_hour   timestamptz := date_trunc('hour', now());
begin
  if p_game not in ('guess_the_split','who_knows_who','wordy','trivia','who_invited_you','fortune_teller','all_talk','cornhole','quick_pour','horse_racing','ring_toss','exquisite_corpse','sketch_chain') then
    return;
  end if;

  select status into v_status from public.venues where id = p_venue_id;
  if v_status is distinct from 'active' then
    return;
  end if;

  -- flood cap: at most 600 plays of one game per venue per clock hour
  -- (a table starting ten games a minute all hour is not a table); the
  -- extras are dropped silently
  insert into public.game_plays (venue_id, game, plays, hour_start, plays_hour)
  values (p_venue_id, p_game, 1, v_hour, 1)
  on conflict (venue_id, game)
  do update set plays      = game_plays.plays + 1,
                plays_hour = case when game_plays.hour_start = v_hour then game_plays.plays_hour + 1 else 1 end,
                hour_start = v_hour,
                updated_at = now()
        where game_plays.hour_start is distinct from v_hour
           or game_plays.plays_hour < 600;
end;
$$;
