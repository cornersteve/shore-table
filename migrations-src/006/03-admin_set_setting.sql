create or replace function public.admin_set_setting(p_key text, p_value text)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_json jsonb;
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  if p_key is null or p_key !~ '^[a-z0-9_.-]{1,64}$' then
    return json_build_object('ok', false, 'error', 'bad_key');
  end if;
  if p_value is null or btrim(p_value) = '' then
    delete from public.operator_settings where key = p_key;
    return json_build_object('ok', true);
  end if;
  -- over-long values are refused, never silently cut (a truncated brand
  -- JSON used to save as garbage); the brand must parse as a JSON object
  if char_length(p_value) > 4000 then
    return json_build_object('ok', false, 'error', 'too_long');
  end if;
  if p_key = 'brand' then
    begin
      v_json := p_value::jsonb;
    exception when others then
      return json_build_object('ok', false, 'error', 'bad_json');
    end;
    if jsonb_typeof(v_json) <> 'object' then
      return json_build_object('ok', false, 'error', 'bad_json');
    end if;
  end if;
  insert into public.operator_settings (key, value, updated_at)
  values (p_key, btrim(p_value), now())
  on conflict (key) do update set value = excluded.value, updated_at = now();
  return json_build_object('ok', true);
end;
$$;
