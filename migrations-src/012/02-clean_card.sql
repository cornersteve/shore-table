create or replace function public.clean_card(p jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_out jsonb;
  v_to  jsonb;
begin
  if p is null or jsonb_typeof(p) <> 'object' then return null; end if;
  v_out := coalesce(public.clean_card_design(p), '{}'::jsonb);
  v_to  := public.clean_card_design(p->'takeout');
  if v_to is not null then v_out := v_out || jsonb_build_object('takeout', v_to); end if;
  return nullif(v_out, '{}'::jsonb);
end;
$$;
-- @@
revoke all on function public.clean_card(jsonb) from public, anon, authenticated;
