create or replace function public.log_event(p_venue_id text, p_event text, p_meta text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status public.venue_status;
  v_recent integer;
begin
  if p_event not in ('app_open','game_start','survey_submit','review_click','promo_click','card_open') then
    return;  -- ignore anything unexpected
  end if;
  if p_meta is not null and char_length(p_meta) > 20 then
    return;
  end if;

  select status into v_status from public.venues where id = p_venue_id;
  if v_status is distinct from 'lead' and v_status is distinct from 'active' then
    return;  -- unknown or inactive: nothing
  end if;

  -- flood cap: a full house of tables cannot produce more than a few
  -- hundred events an hour, so past 3000 the extras are dropped silently
  -- (a script hammering the public key fills nothing)
  select count(*) into v_recent
    from public.events
   where venue_id = p_venue_id and created_at > now() - interval '1 hour';
  if v_recent >= 3000 then
    return;
  end if;

  insert into public.events (venue_id, event, meta)
  values (p_venue_id, p_event, p_meta);
end;
$$;
