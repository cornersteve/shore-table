create or replace function public.get_owner_stats(p_venue_id text, p_key text, p_pass text default null)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row     public.venues%rowtype;
  v_gate    text;
  v_tz      text := public.operator_tz();
  v_today   date;
  v_m0      date;
  v_m1      date;
begin
  v_gate := public.owner_gate(p_venue_id, p_key, p_pass);
  if v_gate = 'bad_key' then
    return null;
  end if;
  if v_gate = 'locked' then
    return json_build_object('need_pass', true, 'locked', true);
  end if;
  if v_gate <> 'ok' then
    return json_build_object('need_pass', true);
  end if;
  select * into v_row from public.venues where id = p_venue_id;

  v_today := (now() at time zone v_tz)::date;
  v_m0 := date_trunc('month', v_today)::date;
  v_m1 := (date_trunc('month', v_today) - interval '1 month')::date;

  return json_build_object(
    'name',   v_row.name,
    'logo',   v_row.logo,
    'status', v_row.status,
    'games',  v_row.games,
    'cards', v_row.cards,
    'card_cap', v_row.card_cap,
    'games_enabled', v_row.games_enabled,
    'form_custom', v_row.form_custom,
    'extras_month', (
      select coalesce(json_agg(extra order by created_at desc), '[]'::json)
      from (select extra, created_at
              from public.survey_responses
             where venue_id = v_row.id
               and extra is not null
               and (created_at at time zone v_tz)::date >= v_m0
             order by created_at desc
             limit 500) x),
    'this_month', (
      select json_build_object(
        'count', count(*),
        'food',    round(avg(food)::numeric, 2),
        'service', round(avg(service)::numeric, 2))
      from public.survey_responses
      where venue_id = v_row.id
        and (created_at at time zone v_tz)::date >= v_m0),
    'last_month', (
      select json_build_object(
        'count', count(*),
        'food',    round(avg(food)::numeric, 2),
        'service', round(avg(service)::numeric, 2))
      from public.survey_responses
      where venue_id = v_row.id
        and (created_at at time zone v_tz)::date >= v_m1
        and (created_at at time zone v_tz)::date <  v_m0),
    'discovery_30d', (
      select coalesce(json_agg(json_build_object('k', discovery, 'n', n) order by n desc), '[]'::json)
      from (select discovery, count(*) as n
            from public.survey_responses
            where venue_id = v_row.id
              and discovery is not null
              and created_at > now() - interval '30 days'
            group by discovery) d),
    'comments', (
      select coalesce(json_agg(json_build_object('t', comment, 'at', created_at) order by created_at desc), '[]'::json)
      from (select comment, created_at
            from public.survey_responses
            where venue_id = v_row.id and comment is not null and btrim(comment) <> ''
            order by created_at desc
            limit 30) c),
    'game_plays', (
      select coalesce(json_agg(json_build_object('game', game, 'plays', plays) order by plays desc), '[]'::json)
      from public.game_plays where venue_id = v_row.id),
    'events_30d', (
      select json_build_object(
        'opens',         count(*) filter (where event = 'app_open'),
        'review_clicks', count(*) filter (where event = 'review_click'),
        'promo_clicks',  count(*) filter (where event = 'promo_click'),
        'card_opens',    count(*) filter (where event = 'card_open'))
      from public.events
      where venue_id = v_row.id and created_at > now() - interval '30 days')
  );
end;
$$;
