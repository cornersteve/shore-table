create or replace function public.admin_set_owner_pass(p_id text, p_pass text default null)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pass text := nullif(btrim(coalesce(p_pass, '')), '');
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  -- eight characters minimum; bcrypt cost 10 (about a tenth of a second
  -- per check, which is nothing for an owner and everything for a guesser)
  if v_pass is not null and (char_length(v_pass) < 8 or char_length(v_pass) > 72) then
    return json_build_object('ok', false, 'error', 'bad_length');
  end if;

  update public.venues
     set owner_pass = case when v_pass is null then null
                           else extensions.crypt(v_pass, extensions.gen_salt('bf', 10)) end
   where id = p_id;
  if not found then return json_build_object('ok', false, 'error', 'no_such_venue'); end if;
  delete from public.owner_auth_attempts where venue_id = p_id;   -- a new passphrase starts clean
  return json_build_object('ok', true, 'has_pass', v_pass is not null);
end;
$$;
