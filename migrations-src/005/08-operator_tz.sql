create or replace function public.operator_tz()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tz text;
  v_t  timestamp;
begin
  -- the operator's time zone (Settings > Your area), used wherever a
  -- report turns a timestamp into a calendar day; anything unset or
  -- unknown to Postgres falls back to US Eastern
  select value into v_tz from public.operator_settings where key = 'tz';
  v_tz := nullif(btrim(coalesce(v_tz, '')), '');
  if v_tz is null or v_tz !~ '^[A-Za-z0-9_/+-]{1,64}$' then
    return 'America/New_York';
  end if;
  begin
    v_t := now() at time zone v_tz;
  exception when others then
    return 'America/New_York';
  end;
  return v_tz;
end;
$$;
-- @@
revoke all on function public.operator_tz() from public, anon, authenticated;
