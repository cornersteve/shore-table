create or replace function public.set_venue_card(p_venue_id text, p_key text, p_card jsonb, p_pass text default null)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_gate text;
  v_card jsonb;
begin
  v_gate := public.owner_gate(p_venue_id, p_key, p_pass);
  if v_gate <> 'ok' then
    return json_build_object('ok', false, 'error', v_gate);
  end if;
  v_card := public.clean_card(p_card);
  update public.venues set card = v_card where id = p_venue_id;
  return json_build_object('ok', true, 'card', v_card);
end;
$$;
-- @@
revoke all on function public.set_venue_card(text, text, jsonb, text) from public;
-- @@
grant execute on function public.set_venue_card(text, text, jsonb, text) to anon, authenticated;
