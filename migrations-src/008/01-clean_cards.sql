create or replace function public.clean_cards(p jsonb, p_cap integer)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_out   jsonb := '[]'::jsonb;
  v_el    jsonb;
  v_c     jsonb;
  v_t     text;
  v_title text;
  v_days  jsonb;
  v_items jsonb;
  v_mode  text;
begin
  if p is null or jsonb_typeof(p) <> 'array' then return null; end if;
  for v_el in select * from jsonb_array_elements(p) loop
    exit when jsonb_array_length(v_out) >= greatest(coalesce(p_cap, 4), 0);
    continue when jsonb_typeof(v_el) <> 'object';
    v_t := v_el->>'t';
    continue when v_t is null or v_t not in ('schedule','list','notice');
    v_title := nullif(left(btrim(coalesce(v_el->>'title', '')), 40), '');
    continue when v_title is null;

    v_c := jsonb_build_object(
      't', v_t, 'title', v_title,
      'icon', case when coalesce(v_el->>'icon', '') ~ '^[a-z0-9_]{1,24}$' then v_el->>'icon' end,
      'off',  v_el->'off' = 'true'::jsonb,
      'desc', nullif(left(btrim(coalesce(v_el->>'desc', '')), 240), ''));

    if v_t = 'schedule' then
      select jsonb_object_agg(d.k, left(btrim(v_el->'days'->>d.k), 200))
        into v_days
        from (values ('mon'),('tue'),('wed'),('thu'),('fri'),('sat'),('sun')) d(k)
       where jsonb_typeof(v_el->'days') = 'object'
         and nullif(btrim(coalesce(v_el->'days'->>d.k, '')), '') is not null;
      v_c := v_c || jsonb_build_object(
        'days',   coalesce(v_days, '{}'::jsonb),
        'always', v_el->'always' = 'true'::jsonb);
    elsif v_t = 'list' then
      select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
               'n', left(btrim(i.el->>'n'), 60),
               'd', nullif(left(btrim(coalesce(i.el->>'d', '')), 120), ''),
               'p', nullif(left(btrim(coalesce(i.el->>'p', '')), 20), ''))) order by i.ord), '[]'::jsonb)
        into v_items
        from (select t.el, t.ord from jsonb_array_elements(
                case when jsonb_typeof(v_el->'items') = 'array' then v_el->'items' else '[]'::jsonb end)
                with ordinality t(el, ord)
               limit 40) i
       where jsonb_typeof(i.el) = 'object'
         and nullif(btrim(coalesce(i.el->>'n', '')), '') is not null;
      v_c := v_c || jsonb_build_object('items', coalesce(v_items, '[]'::jsonb));
    else  -- notice
      v_mode := v_el->>'mode';
      if v_mode is null or v_mode not in ('inline','link','page') then v_mode := 'inline'; end if;
      v_c := v_c || jsonb_build_object(
        'mode', v_mode,
        'body', nullif(left(btrim(coalesce(v_el->>'body', '')), 1500), ''),
        'url',  public.clean_card_url(v_el->>'url'),
        'hot',  v_el->'hot' = 'true'::jsonb,
        'btn',  nullif(left(btrim(coalesce(v_el->>'btn', '')), 30), ''),
        'until', case when coalesce(v_el->>'until', '') ~ '^\d{4}-\d{2}-\d{2}$' then v_el->>'until' end);
    end if;

    v_out := v_out || jsonb_build_array(jsonb_strip_nulls(v_c));
  end loop;
  return nullif(v_out, '[]'::jsonb);
end;
$$;
-- @@
revoke all on function public.clean_cards(jsonb, integer) from public, anon, authenticated;
