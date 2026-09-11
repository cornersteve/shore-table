alter table public.gts_questions
  add column if not exists votes_day date,
  add column if not exists votes_today integer not null default 0;
-- @@
create or replace function public.cast_gts_vote(
  p_question_id bigint,
  p_side        text,
  p_venue_id    text
)
returns table (count_a integer, count_b integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status public.venue_status;
  q_status public.content_status;
  v_country text;
begin
  if p_side not in ('a', 'b') then
    raise exception 'side must be a or b';
  end if;

  select status into q_status from public.gts_questions where id = p_question_id;
  if q_status is null then
    raise exception 'unknown question';
  end if;

  select status into v_status from public.venues where id = p_venue_id;
  if v_status is null or v_status = 'inactive' then
    raise exception 'venue not available';
  end if;

  v_country := public.req_country();

  -- daily budget: one question takes at most 2000 counted votes a day
  -- across the whole instance, so a script cannot tilt a split overnight;
  -- past the budget the tap still shows the split but counts nothing
  if q_status = 'active' and v_status = 'active'
     and (v_country = '' or v_country = 'US') then
    update public.gts_questions as t
       set count_a = t.count_a + (case when p_side = 'a' then 1 else 0 end),
           count_b = t.count_b + (case when p_side = 'b' then 1 else 0 end),
           votes_today = case when t.votes_day = current_date then t.votes_today + 1 else 1 end,
           votes_day   = current_date
     where t.id = p_question_id
       and (t.votes_day is distinct from current_date or t.votes_today < 2000);
  end if;

  return query
    select t.count_a, t.count_b from public.gts_questions t where t.id = p_question_id;
end;
$$;
