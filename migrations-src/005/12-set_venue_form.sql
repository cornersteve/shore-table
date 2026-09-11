create or replace function public.set_venue_form(p_venue_id text, p_key text, p_core jsonb, p_extras jsonb, p_pass text default null)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row    public.venues%rowtype;
  v_core   jsonb := '{}'::jsonb;
  v_extras jsonb := '[]'::jsonb;
  v_seen   text[] := array[]::text[];
  v_k      text;
  v_e      jsonb;
  v_id     text;
  v_type   text;
  v_label  text;
  v_multi  boolean;
  v_opts   jsonb;
  v_o      text;
  v_clean_opts jsonb;
begin
  if public.owner_gate(p_venue_id, p_key, p_pass) <> 'ok' then
    return false;
  end if;
  select * into v_row from public.venues where id = p_venue_id;
  -- the paid switch stays operator-only; without it this venue's form row
  -- is dormant anyway (the app serves the global form)
  if v_row.form_custom is distinct from true then
    return false;
  end if;

  -- core: only the five known keys, booleans, default true (as 35)
  foreach v_k in array array['food','service','discovery','plate','visit'] loop
    v_core := v_core || jsonb_build_object(v_k,
      coalesce((p_core ->> v_k)::boolean, true));
  end loop;

  -- extras: max 10, known types, clean labels/opts, unique ids (as 35)
  if p_extras is not null and jsonb_typeof(p_extras) = 'array' then
    for v_e in select * from jsonb_array_elements(p_extras) limit 10 loop
      v_id    := v_e ->> 'id';
      v_type  := v_e ->> 'type';
      v_label := left(btrim(coalesce(v_e ->> 'label', '')), 120);
      v_multi := coalesce((v_e ->> 'multi')::boolean, false);
      if v_id is null or v_id !~ '^x[a-z0-9]{4,14}$' or v_id = any(v_seen) then continue; end if;
      if v_type not in ('rating','choice','text') or v_label = '' then continue; end if;

      if v_type = 'choice' then
        v_clean_opts := '[]'::jsonb;
        v_opts := v_e -> 'opts';
        if v_opts is null or jsonb_typeof(v_opts) <> 'array' then continue; end if;
        for v_o in select value #>> '{}' from jsonb_array_elements(v_opts) limit 12 loop
          v_o := left(btrim(coalesce(v_o, '')), 60);
          if v_o <> '' then v_clean_opts := v_clean_opts || to_jsonb(v_o); end if;
        end loop;
        if jsonb_array_length(v_clean_opts) < 2 then continue; end if;
        v_extras := v_extras || jsonb_build_array(jsonb_build_object(
          'id', v_id, 'type', v_type, 'label', v_label, 'opts', v_clean_opts, 'multi', v_multi));
      else
        v_extras := v_extras || jsonb_build_array(jsonb_build_object(
          'id', v_id, 'type', v_type, 'label', v_label));
      end if;
      v_seen := v_seen || v_id;
    end loop;
  end if;

  insert into public.feedback_forms (id, core, extras, updated_at)
  values (p_venue_id, v_core, v_extras, now())
  on conflict (id) do update
    set core = excluded.core, extras = excluded.extras, updated_at = now();

  return true;
end;
$$;
