create or replace function public.admin_set_card(p_id text, p_card jsonb)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_card jsonb;
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  v_card := public.clean_card(p_card);
  update public.venues set card = v_card where id = p_id;
  if not found then return json_build_object('ok', false, 'error', 'no_such_venue'); end if;
  return json_build_object('ok', true, 'card', v_card);
end;
$$;
-- @@
revoke all on function public.admin_set_card(text, jsonb) from public;
-- @@
revoke execute on function public.admin_set_card(text, jsonb) from anon;
-- @@
grant execute on function public.admin_set_card(text, jsonb) to authenticated;
