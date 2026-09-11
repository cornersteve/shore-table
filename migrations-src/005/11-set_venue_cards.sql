drop function if exists public.set_venue_cards(text, text, jsonb, text);
-- @@
create or replace function public.set_venue_cards(p_venue_id text, p_key text, p_cards jsonb, p_pass text default null)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row   public.venues%rowtype;
  v_gate  text;
  v_cards jsonb;
begin
  v_gate := public.owner_gate(p_venue_id, p_key, p_pass);
  if v_gate <> 'ok' then
    return json_build_object('ok', false, 'error', v_gate);
  end if;
  select * into v_row from public.venues where id = p_venue_id;

  -- the cleaned set goes back to the dashboard so what the owner sees
  -- after Save is exactly what the tables show (trimmed, capped, links
  -- normalized), never a local copy that only looks saved
  v_cards := public.clean_cards(p_cards, v_row.card_cap);
  update public.venues set cards = v_cards where id = p_venue_id;
  return json_build_object('ok', true, 'cards', coalesce(v_cards, '[]'::jsonb));
end;
$$;
-- @@
revoke all on function public.set_venue_cards(text, text, jsonb, text) from public;
-- @@
grant execute on function public.set_venue_cards(text, text, jsonb, text) to anon, authenticated;
