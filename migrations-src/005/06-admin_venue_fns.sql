create or replace function public.admin_add_venue(
  p_id text, p_name text, p_accent text,
  p_logo text default null, p_review text default null,
  p_header_bg text default null, p_owner_email text default null)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_key    text;
  v_review text := nullif(btrim(coalesce(p_review,'')),'');
  v_logo   text := nullif(btrim(coalesce(p_logo,'')),'');
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;

  if p_id is null or p_id !~ '^[a-z0-9-]{2,40}$' then
    return json_build_object('ok', false, 'error', 'bad_id');
  end if;
  if exists (select 1 from public.venues where id = p_id) then
    return json_build_object('ok', false, 'error', 'id_taken');
  end if;
  if p_name is null or btrim(p_name) = '' or char_length(btrim(p_name)) > 80 then
    return json_build_object('ok', false, 'error', 'bad_name');
  end if;
  if p_accent is null or p_accent !~* '^#[0-9a-f]{6}$' then
    return json_build_object('ok', false, 'error', 'bad_accent');
  end if;
  if p_header_bg is not null and p_header_bg !~* '^#[0-9a-f]{6}$' then
    return json_build_object('ok', false, 'error', 'bad_header_bg');
  end if;
  -- the review link lands in every diner's thank-you screen as a real
  -- link, so it is https or nothing (no javascript:, no quotes, no spaces)
  if v_review is not null and v_review !~* '^https://[^\s"''<>]+$' then
    return json_build_object('ok', false, 'error', 'bad_review');
  end if;
  if v_logo is not null and (char_length(v_logo) > 500 or v_logo ~ '[<>"]') then
    return json_build_object('ok', false, 'error', 'bad_logo');
  end if;

  v_key := gen_random_uuid()::text;

  insert into public.venues (id, name, accent, logo, google_review_link, header_bg, owner_email, owner_key, status)
  values (p_id, btrim(p_name), lower(p_accent), v_logo,
          v_review, lower(p_header_bg),
          nullif(btrim(coalesce(p_owner_email,'')),''), v_key, 'lead');

  return json_build_object('ok', true, 'id', p_id, 'owner_key', v_key);
end;
$$;
-- @@
create or replace function public.admin_update_venue(
  p_id text, p_name text default null, p_accent text default null,
  p_logo text default null, p_review text default null,
  p_header_bg text default null, p_owner_email text default null)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_review text := case when p_review is null then null else nullif(btrim(p_review),'') end;
  v_logo   text := case when p_logo is null then null else nullif(btrim(p_logo),'') end;
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  if not exists (select 1 from public.venues where id = p_id) then
    return json_build_object('ok', false, 'error', 'no_such_venue');
  end if;
  if p_name is not null and char_length(btrim(p_name)) > 80 then
    return json_build_object('ok', false, 'error', 'bad_name');
  end if;
  if p_accent is not null and p_accent !~* '^#[0-9a-f]{6}$' then
    return json_build_object('ok', false, 'error', 'bad_accent');
  end if;
  if p_header_bg is not null and p_header_bg <> '' and p_header_bg !~* '^#[0-9a-f]{6}$' then
    return json_build_object('ok', false, 'error', 'bad_header_bg');
  end if;
  if v_review is not null and v_review !~* '^https://[^\s"''<>]+$' then
    return json_build_object('ok', false, 'error', 'bad_review');
  end if;
  if v_logo is not null and (char_length(v_logo) > 500 or v_logo ~ '[<>"]') then
    return json_build_object('ok', false, 'error', 'bad_logo');
  end if;

  update public.venues set
    name               = coalesce(nullif(btrim(coalesce(p_name,'')),''), name),
    accent             = coalesce(lower(p_accent), accent),
    logo               = case when p_logo is null then logo else v_logo end,
    google_review_link = case when p_review is null then google_review_link else v_review end,
    header_bg          = case when p_header_bg is null then header_bg else lower(nullif(btrim(p_header_bg),'')) end,
    owner_email        = case when p_owner_email is null then owner_email else nullif(btrim(p_owner_email),'') end
  where id = p_id;

  return json_build_object('ok', true);
end;
$$;
