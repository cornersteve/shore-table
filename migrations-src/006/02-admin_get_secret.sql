create or replace function public.admin_get_secret(p_key text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- one secret at a time, only the keys that are secrets, only for an
  -- operator, only when a button that needs it is pressed
  if not public.is_operator() then return null; end if;
  if p_key is null or p_key not in ('gh_token') then return null; end if;
  return (select value from public.operator_settings where key = p_key);
end;
$$;
-- @@
revoke all on function public.admin_get_secret(text) from public;
-- @@
revoke execute on function public.admin_get_secret(text) from anon;
-- @@
grant execute on function public.admin_get_secret(text) to authenticated;
