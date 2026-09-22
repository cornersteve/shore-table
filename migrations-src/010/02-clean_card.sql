create or replace function public.clean_card(p jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_out  jsonb := '{}'::jsonb;
  v_s    jsonb;
  v_slot jsonb;
  v_to   text;
  v_k    text;
begin
  if p is null or jsonb_typeof(p) <> 'object' then return null; end if;
  v_out := jsonb_strip_nulls(jsonb_build_object(
    'town', nullif(left(btrim(coalesce(p->>'town', '')), 30), ''),
    'a1', case when coalesce(p->>'a1', '') ~* '^#[0-9a-f]{6}$' then lower(p->>'a1') end,
    'a2', case when coalesce(p->>'a2', '') ~* '^#[0-9a-f]{6}$' then lower(p->>'a2') end,
    'hb', case when coalesce(p->>'hb', '') ~* '^#[0-9a-f]{6}$' then lower(p->>'hb') end,
    'bb', case when coalesce(p->>'bb', '') ~* '^#[0-9a-f]{6}$' then lower(p->>'bb') end));
  foreach v_k in array array['s1', 's2'] loop
    v_s := p->v_k;
    continue when v_s is null or jsonb_typeof(v_s) <> 'object';
    v_to := v_s->>'to';
    if v_to is null or v_to not in ('home', 'games', 'box', 'url') then v_to := null; end if;
    v_slot := jsonb_strip_nulls(jsonb_build_object(
      'head', nullif(left(btrim(coalesce(v_s->>'head', '')), 60), ''),
      'body', nullif(left(btrim(coalesce(v_s->>'body', '')), 120), ''),
      'scan', nullif(left(btrim(coalesce(v_s->>'scan', '')), 40), ''),
      'to',   v_to,
      'url',  case when v_to = 'url' and coalesce(v_s->>'url', '') ~* '^https://[^\s"''<>]{1,200}$' then v_s->>'url' end));
    if v_slot <> '{}'::jsonb then v_out := v_out || jsonb_build_object(v_k, v_slot); end if;
  end loop;
  return nullif(v_out, '{}'::jsonb);
end;
$$;
-- @@
revoke all on function public.clean_card(jsonb) from public, anon, authenticated;
