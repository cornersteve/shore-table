create or replace function public.get_report(
  p_venue_id text,
  p_key      text,
  p_pass     text default null,
  p_from     date default null,   -- inclusive; null with p_to null = all time
  p_to       date default null,   -- exclusive
  p_pf       date default null,   -- previous range (for deltas), optional
  p_pt       date default null
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row  public.venues%rowtype;
  v_gate text;
  v_tz   text := public.operator_tz();
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

  return json_build_object(
    'name',  v_row.name,
    'logo',  v_row.logo,
    'accent', v_row.accent,
    'cur', (
      select json_build_object(
        'count', count(*),
        'food',    round(avg(food)::numeric, 2),
        'service', round(avg(service)::numeric, 2))
      from public.survey_responses
      where venue_id = v_row.id
        and (p_from is null or (created_at at time zone v_tz)::date >= p_from)
        and (p_to   is null or (created_at at time zone v_tz)::date <  p_to)),
    'prev', case when p_pf is null then null else (
      select json_build_object(
        'count', count(*),
        'food',    round(avg(food)::numeric, 2),
        'service', round(avg(service)::numeric, 2))
      from public.survey_responses
      where venue_id = v_row.id
        and (created_at at time zone v_tz)::date >= p_pf
        and (created_at at time zone v_tz)::date <  p_pt) end,
    'discovery', (
      select coalesce(json_agg(json_build_object('k', k, 'n', n) order by n desc), '[]'::json)
      from (select discovery as k, count(*) as n from public.survey_responses
            where venue_id = v_row.id and discovery is not null
              and (p_from is null or (created_at at time zone v_tz)::date >= p_from)
              and (p_to   is null or (created_at at time zone v_tz)::date <  p_to)
            group by discovery) d),
    'plate', (
      select coalesce(json_agg(json_build_object('k', k, 'n', n) order by n desc), '[]'::json)
      from (select plate as k, count(*) as n from public.survey_responses
            where venue_id = v_row.id and plate is not null
              and (p_from is null or (created_at at time zone v_tz)::date >= p_from)
              and (p_to   is null or (created_at at time zone v_tz)::date <  p_to)
            group by plate) d),
    'visit', (
      select coalesce(json_agg(json_build_object('k', k, 'n', n) order by n desc), '[]'::json)
      from (select visit as k, count(*) as n from public.survey_responses
            where venue_id = v_row.id and visit is not null
              and (p_from is null or (created_at at time zone v_tz)::date >= p_from)
              and (p_to   is null or (created_at at time zone v_tz)::date <  p_to)
            group by visit) d),
    -- the cross-venue comparison is computed only for venues that show it
    -- (four scans of every venue's responses otherwise run for nothing)
    'county', case when v_row.report_county is distinct from true then null else (
      select json_build_object(
        'food',    round(avg(sr.food)::numeric, 2),
        'service', round(avg(sr.service)::numeric, 2),
        'discovery', (
          select coalesce(json_agg(json_build_object('k', k, 'pct', pct) order by pct desc), '[]'::json)
          from (select discovery as k,
                       round(100.0 * count(*) / greatest(1, sum(count(*)) over ()), 0) as pct
                from public.survey_responses s2
                join public.venues vv2 on vv2.id = s2.venue_id and vv2.status = 'active'
                where s2.discovery is not null
                  and (p_from is null or (s2.created_at at time zone v_tz)::date >= p_from)
                  and (p_to   is null or (s2.created_at at time zone v_tz)::date <  p_to)
                group by s2.discovery) cd),
        'plate', (
          select coalesce(json_agg(json_build_object('k', k, 'pct', pct) order by pct desc), '[]'::json)
          from (select plate as k,
                       round(100.0 * count(*) / greatest(1, sum(count(*)) over ()), 0) as pct
                from public.survey_responses s2
                join public.venues vv2 on vv2.id = s2.venue_id and vv2.status = 'active'
                where s2.plate is not null
                  and (p_from is null or (s2.created_at at time zone v_tz)::date >= p_from)
                  and (p_to   is null or (s2.created_at at time zone v_tz)::date <  p_to)
                group by s2.plate) cp),
        'visit', (
          select coalesce(json_agg(json_build_object('k', k, 'pct', pct) order by pct desc), '[]'::json)
          from (select visit as k,
                       round(100.0 * count(*) / greatest(1, sum(count(*)) over ()), 0) as pct
                from public.survey_responses s2
                join public.venues vv2 on vv2.id = s2.venue_id and vv2.status = 'active'
                where s2.visit is not null
                  and (p_from is null or (s2.created_at at time zone v_tz)::date >= p_from)
                  and (p_to   is null or (s2.created_at at time zone v_tz)::date <  p_to)
                group by s2.visit) cv))
      from public.survey_responses sr
      join public.venues vv on vv.id = sr.venue_id and vv.status = 'active'
      where (p_from is null or (sr.created_at at time zone v_tz)::date >= p_from)
        and (p_to   is null or (sr.created_at at time zone v_tz)::date <  p_to)) end,
    'events', (
      select json_build_object(
        'opens',         count(*) filter (where event = 'app_open'),
        'review_clicks', count(*) filter (where event = 'review_click'),
        'promo_clicks',  count(*) filter (where event = 'promo_click'),
        'card_opens',    count(*) filter (where event = 'card_open'))
      from public.events
      where venue_id = v_row.id
        and (p_from is null or (created_at at time zone v_tz)::date >= p_from)
        and (p_to   is null or (created_at at time zone v_tz)::date <  p_to)),
    'events_prev', case when p_pf is null then null else (
      select json_build_object(
        'opens',         count(*) filter (where event = 'app_open'),
        'review_clicks', count(*) filter (where event = 'review_click'),
        'promo_clicks',  count(*) filter (where event = 'promo_click'),
        'card_opens',    count(*) filter (where event = 'card_open'))
      from public.events
      where venue_id = v_row.id
        and (created_at at time zone v_tz)::date >= p_pf
        and (created_at at time zone v_tz)::date <  p_pt) end,
    'games', (
      select coalesce(json_agg(json_build_object('game', game, 'plays', plays) order by plays desc), '[]'::json)
      from public.game_plays where venue_id = v_row.id),
    'comments', (
      select coalesce(json_agg(json_build_object('t', comment, 'at', created_at) order by created_at desc), '[]'::json)
      from (select comment, created_at from public.survey_responses
            where venue_id = v_row.id and comment is not null and btrim(comment) <> ''
              and (p_from is null or (created_at at time zone v_tz)::date >= p_from)
              and (p_to   is null or (created_at at time zone v_tz)::date <  p_to)
            order by created_at desc limit 200) c),
    'extras', (
      select coalesce(json_agg(extra order by created_at desc), '[]'::json)
      from (select extra, created_at from public.survey_responses
            where venue_id = v_row.id and extra is not null
              and (p_from is null or (created_at at time zone v_tz)::date >= p_from)
              and (p_to   is null or (created_at at time zone v_tz)::date <  p_to)
            order by created_at desc limit 500) x),
    'form_custom', v_row.form_custom
  );
end;
$$;
