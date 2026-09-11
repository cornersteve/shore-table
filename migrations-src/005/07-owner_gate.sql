create table if not exists public.owner_auth_attempts (
  venue_id      text        primary key references public.venues(id),
  fails         smallint    not null default 0,
  first_fail_at timestamptz,
  locked_until  timestamptz
);
-- @@
comment on table public.owner_auth_attempts is 'Wrong owner-passphrase attempts per venue, for the lockout in owner_gate(). Sealed: written only by the definer functions. Cleared on a correct passphrase.';
-- @@
alter table public.owner_auth_attempts enable row level security;
-- @@
revoke all on public.owner_auth_attempts from public, anon, authenticated;
-- @@
create or replace function public.owner_gate(p_venue_id text, p_key text, p_pass text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row   public.venues%rowtype;
  v_a     public.owner_auth_attempts%rowtype;
  v_fresh boolean;
  v_fails integer;
begin
  -- one door for every owner-dashboard call. Answers:
  --   ok        key matches and the passphrase (if the venue has one) matches
  --   bad_key   no such venue, or the link's key is wrong
  --   need_pass the venue has a passphrase and none / a wrong one arrived
  --   locked    ten wrong passphrases inside fifteen minutes: fifteen minutes off
  select * into v_row from public.venues where id = p_venue_id;
  if v_row.id is null or p_key is null or v_row.owner_key is distinct from p_key then
    return 'bad_key';
  end if;
  if v_row.owner_pass is null then
    return 'ok';
  end if;

  select * into v_a from public.owner_auth_attempts where venue_id = p_venue_id;
  if v_a.locked_until is not null and v_a.locked_until > now() then
    return 'locked';
  end if;
  if p_pass is null then
    return 'need_pass';   -- first visit: nothing to count
  end if;
  if extensions.crypt(p_pass, v_row.owner_pass) = v_row.owner_pass then
    delete from public.owner_auth_attempts where venue_id = p_venue_id;
    return 'ok';
  end if;

  v_fresh := v_a.venue_id is not null and v_a.first_fail_at > now() - interval '15 minutes';
  v_fails := case when v_fresh then v_a.fails + 1 else 1 end;
  insert into public.owner_auth_attempts (venue_id, fails, first_fail_at, locked_until)
  values (p_venue_id, v_fails,
          case when v_fresh then v_a.first_fail_at else now() end,
          case when v_fails >= 10 then now() + interval '15 minutes' else null end)
  on conflict (venue_id) do update
    set fails = excluded.fails, first_fail_at = excluded.first_fail_at, locked_until = excluded.locked_until;
  return case when v_fails >= 10 then 'locked' else 'need_pass' end;
end;
$$;
-- @@
revoke all on function public.owner_gate(text, text, text) from public, anon, authenticated;
