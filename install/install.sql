-- ============================================================================
--  PLATFORM INSTALL  ·  one paste, one database, run ONCE
-- ============================================================================
--  Run this whole file in your Supabase project's SQL editor, ONCE, after:
--    1. Creating your operator login under Authentication > Users, and
--       disabling public signups in Authentication > Settings.
--    2. Creating a PUBLIC storage bucket named exactly:  restaurant logos
--    3. EDITING THE ONE MARKED LINE near the bottom of this file
--       (">>> EDIT THIS LINE <<<") to your operator email.
--
--  The file runs as a single transaction: if anything fails (most commonly
--  the operator email line), NOTHING is kept - fix the line and run the
--  whole file again. After this, run install/baseline_content.sql (the
--  shared question library), then never touch SQL again: platform updates
--  apply their own migrations through the dashboard.
--
--  THE SECURITY MODEL, in one paragraph: the publishable (anon) key that
--  ships in the web pages can read venue branding via the public_venues
--  view, read ACTIVE game content, and call the narrow SECURITY DEFINER
--  functions below (submit a survey, cast a vote, bump counters, and the
--  owner-key-gated dashboard calls). It cannot read survey responses,
--  events, play counters, or the raw venues table (so never an owner_key
--  or owner_email), and it cannot write any table directly. Operator
--  functions all die at is_operator() without your authenticated session.
-- ============================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
--  ENUMS
-- ---------------------------------------------------------------------------
create type venue_status   as enum ('lead', 'active', 'inactive');
--   lead     -> page loads, games play, but NOTHING is counted or saved
--               (a live demo with the recorder off).
--   active   -> page loads AND votes / surveys / plays are saved.
--   inactive -> page does not load at all.

create type content_status as enum ('active', 'retired');
--   Question ids are permanent and never recycled. To retire a question,
--   set status = 'retired' (never DELETE). This keeps every phone's
--   per-device memory accurate as content changes over time.

-- ---------------------------------------------------------------------------
--  VENUES  (one row per restaurant; the id is permanent and QR-encoded)
-- ---------------------------------------------------------------------------
create table venues (
  id                 text        primary key,
  name               text        not null,
  logo               text,                             -- image URL, or plain text used as a wordmark
  accent             text        not null default '#3a6ea5',
  google_review_link text,                             -- shown to EVERY diner, never rating-gated (Google/FTC)
  status             venue_status not null default 'lead',
  pause_submissions  boolean     not null default false,
  created_at         timestamptz not null default now(),
  owner_key          text        not null
    default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  games              text[]      not null default
    array['who_knows_who','guess_the_split','wordy','trivia','who_invited_you','fortune_teller','all_talk','cornhole','quick_pour'],
  custom_questions   boolean     not null default false,
  header_bg          text check (header_bg is null or header_bg ~* '^#[0-9a-f]{6}$'),
  custom_only        text[]      not null default '{}',
  owner_pass         text,
  dark_mode          boolean     not null default false,
  cards              jsonb,
  card_cap           smallint    not null default 4 check (card_cap between 0 and 20),
  games_enabled      boolean     not null default true,
  form_custom        boolean     not null default false,
  report_county      boolean     not null default true,
  owner_email        text check (owner_email is null or owner_email ~* '^[^\s@]+@[^\s@]+\.[^\s@]+$')
);

comment on table  venues              is 'Per-venue branding + config. id is permanent and encoded in the QR; rebrands edit the other columns.';
comment on column venues.id           is 'Permanent slug. Chosen once, never changed or reused, even through a rebrand.';
comment on column venues.status       is 'lead = demo only (nothing saved); active = saves; inactive = does not load.';
comment on column venues.owner_key    is 'Secret per-venue token for the owner dashboard capability link. Rotatable any time; rotating invalidates the old link.';
comment on column venues.games        is 'Enabled game ids, in display order. Exclusive games (horse_racing, ring_toss) are never in the default and only the operator can grant them.';
comment on column venues.owner_email  is 'Owner contact email. PII: operator-facing only. NEVER expose via public_venues or get_owner_stats.';
comment on column venues.owner_pass   is 'Optional bcrypt hash gating the owner dashboard. NULL = link-only (default, and the off switch).';
comment on column venues.report_county is 'Show the "vs county" comparison on this venue''s guest report. Default true.';
comment on column venues.cards is 'Landing-screen cards, a jsonb array of preset card objects (schedule / list / notice). Written only through clean_cards; capped at card_cap.';
comment on column venues.card_cap is 'How many landing cards this venue may have. Operator-set per venue; the default is 4.';
comment on column venues.games_enabled is 'Operator-set. False hides the games side of the app entirely (feedback-and-cards venues); the landing always keeps feedback, so it can never be empty.';

-- ---------------------------------------------------------------------------
--  SURVEY RESPONSES  (anonymous; no device id, no ip, no name)
-- ---------------------------------------------------------------------------
create table survey_responses (
  id         bigint      generated always as identity primary key,
  venue_id   text        not null references venues(id),
  food       smallint    check (food    between 1 and 5),
  service    smallint    check (service between 1 and 5),
  discovery  text,
  plate      text,
  visit      text,
  comment    text        check (comment is null or char_length(comment) <= 1000),
  extra      jsonb,
  created_at timestamptz not null default now()
);

create index survey_responses_venue_created_idx on survey_responses (venue_id, created_at desc);

comment on table survey_responses is 'Anonymous suggestion-box submissions. food/service are private to the venue; discovery/plate/visit feed the cross-venue insights pool; extra holds custom-form answers.';

-- ---------------------------------------------------------------------------
--  GAME CONTENT TABLES  (shared pool; venue_id set = one venue's custom row)
-- ---------------------------------------------------------------------------
create table gts_questions (            -- Guess the Split
  id         bigint         generated always as identity primary key,
  option_a   text           not null,
  option_b   text           not null,
  count_a    integer        not null default 0 check (count_a >= 0),
  count_b    integer        not null default 0 check (count_b >= 0),
  status     content_status not null default 'active',
  created_at timestamptz    not null default now(),
  venue_id   text           references venues(id)
);
comment on table gts_questions is 'Binary polls pooled across every venue. Counters, not per-vote rows. Seeded low + lopsided so early demos never read 100%.';

create table wkw_questions (            -- Who Knows Who
  id         bigint         generated always as identity primary key,
  prompt     text           not null,
  option_a   text           not null,
  option_b   text           not null,
  option_c   text           not null,
  option_d   text           not null,
  status     content_status not null default 'active',
  created_at timestamptz    not null default now(),
  venue_id   text           references venues(id)
);
comment on column wkw_questions.prompt is 'Use {N} as the placeholder for the subject player''s name.';

create table trivia_questions (
  id             bigint         generated always as identity primary key,
  question       text           not null,
  correct_answer text           not null,
  wrong_1        text           not null,
  wrong_2        text           not null,
  wrong_3        text           not null,
  status         content_status not null default 'active',
  created_at     timestamptz    not null default now(),
  venue_id       text           references venues(id)
);

create table wordy_words (
  word       text           primary key check (word ~ '^[A-Z]{5}$'),
  status     content_status not null default 'active',
  created_at timestamptz    not null default now(),
  venue_id   text           references venues(id)
);

create table wiy_words (                -- Who Invited You?
  id         bigint         generated always as identity primary key,
  category   text           not null,
  word       text           not null,
  status     content_status not null default 'active',
  created_at timestamptz    not null default now(),
  venue_id   text           references venues(id)
);
comment on table wiy_words is 'Secret words for Who Invited You?. Everyone sees the word except the fake, who sees only the category.';

create table fortunes (                 -- Fortune Teller
  id         bigint         generated always as identity primary key,
  text       text           not null,
  status     content_status not null default 'active',
  created_at timestamptz    not null default now(),
  venue_id   text           references venues(id)
);

create table at_categories (            -- All Talk
  id         bigint         generated always as identity primary key,
  category   text           not null,
  status     content_status not null default 'active',
  created_at timestamptz    not null default now(),
  venue_id   text           references venues(id)
);

-- ---------------------------------------------------------------------------
--  COUNTERS + EVENTS  (sealed to the public key; write via functions only)
-- ---------------------------------------------------------------------------
create table game_plays (
  venue_id   text        not null references venues(id),
  game       text        not null check (game in
    ('guess_the_split','who_knows_who','wordy','trivia','who_invited_you','fortune_teller','all_talk','cornhole','quick_pour','horse_racing','ring_toss')),
  plays      integer     not null default 0 check (plays >= 0),
  updated_at timestamptz not null default now(),
  primary key (venue_id, game)
);
comment on table game_plays is 'Per-venue, per-game play counters. No PII. The public key can only increment via log_game_play(); it cannot read this table.';

create table events (
  id         bigint      generated always as identity primary key,
  venue_id   text        not null references venues(id),
  event      text        not null check (event in
               ('app_open','game_start','survey_submit','review_click','promo_click','card_open')),
  meta       text        check (meta is null or char_length(meta) <= 20),
  created_at timestamptz not null default now()
);
comment on table events is 'Anonymous per-venue analytics events with timestamps. Logs for lead AND active venues (demo tracking is the point). No PII.';
create index events_venue_time on events (venue_id, created_at desc);

-- ---------------------------------------------------------------------------
--  FEEDBACK FORM CONFIG
-- ---------------------------------------------------------------------------
create table feedback_forms (
  id         text        primary key,
  core       jsonb       not null default '{}'::jsonb,
  extras     jsonb       not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);
comment on table feedback_forms is 'Suggestion-box form config. Row id ''global'' is the operator-wide form; a venue id row is that venue''s custom form (used only while venues.form_custom is true).';
insert into feedback_forms (id) values ('global');

-- ---------------------------------------------------------------------------
--  OPERATOR GATE + SETTINGS + MIGRATIONS
-- ---------------------------------------------------------------------------
create table operator_users (
  uid        uuid        primary key references auth.users(id),
  created_at timestamptz not null default now()
);
comment on table operator_users is 'Auth user ids allowed to use the operator dashboard. No API policies on purpose; only the admin functions read it.';

create table operator_settings (
  key        text        primary key,
  value      text,
  updated_at timestamptz not null default now()
);
comment on table operator_settings is 'Operator-only key/value store (e.g. the GitHub token for one-button updates). Sealed: read/written only via the admin functions.';

create table schema_migrations (
  version    integer     primary key,
  applied_at timestamptz not null default now()
);
comment on table schema_migrations is 'Applied platform migration versions. Written only by admin_run_migration; a fresh install seeds every version it already includes.';
insert into schema_migrations (version) values (1), (2), (3), (4);

-- ---------------------------------------------------------------------------
--  ROW LEVEL SECURITY  (locked by default; policies below open exact doors)
-- ---------------------------------------------------------------------------
alter table venues            enable row level security;
alter table survey_responses  enable row level security;
alter table gts_questions     enable row level security;
alter table wkw_questions     enable row level security;
alter table trivia_questions  enable row level security;
alter table wordy_words       enable row level security;
alter table wiy_words         enable row level security;
alter table fortunes          enable row level security;
alter table at_categories     enable row level security;
alter table game_plays        enable row level security;
alter table events            enable row level security;
alter table feedback_forms    enable row level security;
alter table operator_users    enable row level security;
alter table operator_settings enable row level security;
alter table schema_migrations enable row level security;

revoke insert, update, delete on all tables in schema public from anon;
revoke select on public.venues            from anon;
revoke select on public.survey_responses  from anon;
revoke select, insert, update, delete on public.game_plays        from anon;
revoke select, insert, update, delete on public.events            from anon;
revoke select, insert, update, delete on public.operator_users    from anon;
revoke select, insert, update, delete on public.operator_settings from anon;
revoke select, insert, update, delete on public.schema_migrations from anon;

-- game content: anon reads ACTIVE rows only, read-only
create policy "anon reads active guess-the-split"
  on public.gts_questions for select to anon, authenticated
  using (status = 'active');
create policy "anon reads active who-knows-who"
  on public.wkw_questions for select to anon, authenticated
  using (status = 'active');
create policy "anon reads active trivia"
  on public.trivia_questions for select to anon, authenticated
  using (status = 'active');
create policy "anon reads active wordy words"
  on public.wordy_words for select to anon, authenticated
  using (status = 'active');
create policy "anon reads active who-invited-you words"
  on public.wiy_words for select to anon, authenticated
  using (status = 'active');
create policy "anon reads active fortunes"
  on public.fortunes for select to anon, authenticated
  using (status = 'active');
create policy "anon reads active all-talk categories"
  on public.at_categories for select to anon, authenticated
  using (status = 'active');

-- ---------------------------------------------------------------------------
--  TABLE-LEVEL GRANTS for the public read surface. Required when the
--  project was created with 'Automatically expose new tables' DISABLED
--  (the recommended setting), and harmless when it was not: RLS policies
--  filter rows, but the Data API also needs table privileges. Everything
--  not granted here stays sealed.
-- ---------------------------------------------------------------------------
grant select on public.gts_questions, public.wkw_questions,
  public.trivia_questions, public.wordy_words, public.wiy_words,
  public.fortunes, public.at_categories, public.feedback_forms
  to anon, authenticated;

-- form config is public-readable (labels only; answers are sealed)
create policy feedback_forms_read on feedback_forms
  for select to anon, authenticated using (true);

-- ---------------------------------------------------------------------------
--  PUBLIC VENUES VIEW  (the app's branding read; leads render so demos work)
-- ---------------------------------------------------------------------------
create or replace view public.public_venues
with (security_invoker = off) as
  select id, name, logo, accent, google_review_link,
         games,
         custom_questions,
         header_bg,
         custom_only,
         dark_mode,
         cards,
         games_enabled,
         form_custom,
         report_county,
         (status = 'lead') as demo
  from public.venues
  where status in ('lead', 'active');

grant select on public.public_venues to anon, authenticated;

-- ---------------------------------------------------------------------------
--  STORAGE POLICIES  (bucket "restaurant logos" must already exist, PUBLIC)
--  All three are authenticated + bucket-only. That is equivalent security BY
--  CONSTRUCTION while public signups are disabled: the operator is the only
--  authenticated user that can exist. If you ever enable signups or add
--  auth users, these policies must regain a real is_operator() check first.
--  The SELECT policy is required: storage uploads read their row back in the
--  same statement, and that read-back needs a SELECT policy under RLS.
-- ---------------------------------------------------------------------------
create policy "operator uploads logos"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'restaurant logos');
create policy "operator overwrites logos"
  on storage.objects for update to authenticated
  using (bucket_id = 'restaurant logos')
  with check (bucket_id = 'restaurant logos');
create policy "operator reads logo objects"
  on storage.objects for select to authenticated
  using (bucket_id = 'restaurant logos');

-- ============================================================================
--  FUNCTIONS  (every write path; the public key's only doors)
-- ============================================================================

create or replace function public.req_country()
returns text
language sql
stable
set search_path = ''
as $$
  select upper(coalesce((current_setting('request.headers', true))::json ->> 'cf-ipcountry', ''));
$$;

revoke all on function public.req_country() from public;
-- (called only from the definer functions below)

create or replace function public.submit_survey(
  p_venue_id  text,
  p_food      smallint,
  p_service   smallint,
  p_discovery text,
  p_plate     text,
  p_visit     text,
  p_comment   text,
  p_extra     jsonb default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status public.venue_status;
  v_paused boolean;
  v_fcustom boolean;
  v_country text;
  v_extra  jsonb := '{}'::jsonb;
  v_form   jsonb;
  v_q      jsonb;
  v_k      text;
  v_v      jsonb;
  v_n      int := 0;
  v_arr    jsonb;
  v_s      text;
  v_ok     boolean;
  -- keep in lockstep with SB_CORE in app.html
  c_disc  constant text[] := array['Word of mouth','Social media','Walked by','I''m a regular','Maps or search'];
  c_plate constant text[] := array['Quality ingredients','Healthy options','Big portions','Something new to try'];
  c_visit constant text[] := array['Fast service','Good value','Friendly staff','Great atmosphere'];
begin
  -- geo gate: known non-US = dropped (missing header fails open)
  v_country := public.req_country();
  if v_country <> '' and v_country <> 'US' then
    return;
  end if;

  select status, pause_submissions, form_custom
    into v_status, v_paused, v_fcustom
    from public.venues
   where id = p_venue_id;

  if v_status is distinct from 'active' or coalesce(v_paused, true) then
    return;
  end if;

  -- rate caps: generous ceilings real service never hits
  if (select count(*) from public.survey_responses
       where venue_id = p_venue_id and created_at > now() - interval '1 hour') >= 60
     or (select count(*) from public.survey_responses
       where venue_id = p_venue_id and created_at > now() - interval '24 hours') >= 300 then
    return;
  end if;

  -- extras validated against the venue's ACTIVE form
  if p_extra is not null and jsonb_typeof(p_extra) = 'object' then
    select extras into v_form from public.feedback_forms
     where id = case when coalesce(v_fcustom, false)
                      and exists (select 1 from public.feedback_forms where id = p_venue_id)
                     then p_venue_id else 'global' end;
    for v_k, v_v in select * from jsonb_each(p_extra) loop
      exit when v_n >= 12;
      if v_k !~ '^x[a-z0-9]{4,14}$' then continue; end if;
      -- the question must exist on the active form
      select q into v_q from jsonb_array_elements(coalesce(v_form, '[]'::jsonb)) q
       where q ->> 'id' = v_k limit 1;
      if v_q is null then continue; end if;

      if v_q ->> 'type' = 'rating' and jsonb_typeof(v_v) = 'number' then
        if (v_v::text)::numeric between 1 and 5 then
          v_extra := v_extra || jsonb_build_object(v_k, v_v); v_n := v_n + 1;
        end if;
      elsif v_q ->> 'type' = 'text' and jsonb_typeof(v_v) = 'string' then
        v_s := left(btrim(v_v #>> '{}'), 240);
        if v_s <> '' then
          v_extra := v_extra || jsonb_build_object(v_k, to_jsonb(v_s)); v_n := v_n + 1;
        end if;
      elsif v_q ->> 'type' = 'choice' then
        if jsonb_typeof(v_v) = 'string' then
          v_s := v_v #>> '{}';
          if exists (select 1 from jsonb_array_elements_text(coalesce(v_q -> 'opts', '[]'::jsonb)) o where o = v_s) then
            v_extra := v_extra || jsonb_build_object(v_k, v_v); v_n := v_n + 1;
          end if;
        elsif jsonb_typeof(v_v) = 'array' then
          v_arr := '[]'::jsonb; v_ok := true;
          for v_s in select value #>> '{}' from jsonb_array_elements(v_v) limit 8 loop
            if exists (select 1 from jsonb_array_elements_text(coalesce(v_q -> 'opts', '[]'::jsonb)) o where o = v_s) then
              v_arr := v_arr || to_jsonb(v_s);
            else
              v_ok := false;
            end if;
          end loop;
          if v_ok and jsonb_array_length(v_arr) > 0 then
            v_extra := v_extra || jsonb_build_object(v_k, v_arr); v_n := v_n + 1;
          end if;
        end if;
      end if;
    end loop;
  end if;

  insert into public.survey_responses
    (venue_id, food, service, discovery, plate, visit, comment, extra)
  values (
    p_venue_id,
    p_food,
    p_service,
    case when p_discovery = any(c_disc)  then p_discovery else null end,
    case when p_plate     = any(c_plate) then p_plate     else null end,
    case when p_visit     = any(c_visit) then p_visit     else null end,
    nullif(left(trim(coalesce(p_comment, '')), 1000), ''),
    case when v_extra = '{}'::jsonb then null else v_extra end
  );
end;
$$;

revoke all on function public.submit_survey(text, smallint, smallint, text, text, text, text, jsonb) from public;
grant execute on function public.submit_survey(text, smallint, smallint, text, text, text, text, jsonb) to anon, authenticated;

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

  if q_status = 'active' and v_status = 'active'
     and (v_country = '' or v_country = 'US') then
    update public.gts_questions as t
       set count_a = t.count_a + (case when p_side = 'a' then 1 else 0 end),
           count_b = t.count_b + (case when p_side = 'b' then 1 else 0 end)
     where t.id = p_question_id;
  end if;

  return query
    select t.count_a, t.count_b from public.gts_questions t where t.id = p_question_id;
end;
$$;

revoke all on function public.cast_gts_vote(bigint, text, text) from public;
grant execute on function public.cast_gts_vote(bigint, text, text) to anon, authenticated;

create or replace function public.log_game_play(p_venue_id text, p_game text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status public.venue_status;
begin
  if p_game not in ('guess_the_split','who_knows_who','wordy','trivia','who_invited_you','fortune_teller','all_talk','cornhole','quick_pour','horse_racing','ring_toss') then
    return;
  end if;

  select status into v_status from public.venues where id = p_venue_id;
  if v_status is distinct from 'active' then
    return;
  end if;

  insert into public.game_plays (venue_id, game, plays)
  values (p_venue_id, p_game, 1)
  on conflict (venue_id, game)
  do update set plays = game_plays.plays + 1,
                updated_at = now();
end;
$$;

revoke all on function public.log_game_play(text, text) from public;
grant execute on function public.log_game_play(text, text) to anon, authenticated;

create or replace function public.log_event(p_venue_id text, p_event text, p_meta text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status public.venue_status;
begin
  if p_event not in ('app_open','game_start','survey_submit','review_click','promo_click') then
    return;  -- ignore anything unexpected
  end if;
  if p_meta is not null and char_length(p_meta) > 20 then
    return;
  end if;

  select status into v_status from public.venues where id = p_venue_id;
  if v_status is distinct from 'lead' and v_status is distinct from 'active' then
    return;  -- unknown or inactive: nothing
  end if;

  insert into public.events (venue_id, event, meta)
  values (p_venue_id, p_event, p_meta);
end;
$$;

revoke all on function public.log_event(text, text, text) from public;
grant execute on function public.log_event(text, text, text) to anon, authenticated;

create or replace function public.owner_pass_ok(p_hash text, p_pass text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p_hash is null
      or (p_pass is not null and extensions.crypt(p_pass, p_hash) = p_hash);
$$;

revoke all on function public.owner_pass_ok(text, text) from public;
-- (called only from the definer functions below; no direct grants needed)

create or replace function public.get_owner_stats(p_venue_id text, p_key text, p_pass text default null)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row     public.venues%rowtype;
  v_tz      constant text := 'America/New_York';
  v_today   date;
  v_m0      date;
  v_m1      date;
begin
  select * into v_row from public.venues where id = p_venue_id;
  if v_row.id is null or p_key is null or v_row.owner_key is distinct from p_key then
    return null;
  end if;
  if not public.owner_pass_ok(v_row.owner_pass, p_pass) then
    return json_build_object('need_pass', true);
  end if;

  v_today := (now() at time zone v_tz)::date;
  v_m0 := date_trunc('month', v_today)::date;
  v_m1 := (date_trunc('month', v_today) - interval '1 month')::date;

  return json_build_object(
    'name',   v_row.name,
    'logo',   v_row.logo,
    'status', v_row.status,
    'games',  v_row.games,
    'cards', v_row.cards,
    'card_cap', v_row.card_cap,
    'games_enabled', v_row.games_enabled,
    'form_custom', v_row.form_custom,
    'extras_month', (
      select coalesce(json_agg(extra order by created_at desc), '[]'::json)
      from (select extra, created_at
              from public.survey_responses
             where venue_id = v_row.id
               and extra is not null
               and (created_at at time zone v_tz)::date >= v_m0
             order by created_at desc
             limit 500) x),
    'this_month', (
      select json_build_object(
        'count', count(*),
        'food',    round(avg(food)::numeric, 2),
        'service', round(avg(service)::numeric, 2))
      from public.survey_responses
      where venue_id = v_row.id
        and (created_at at time zone v_tz)::date >= v_m0),
    'last_month', (
      select json_build_object(
        'count', count(*),
        'food',    round(avg(food)::numeric, 2),
        'service', round(avg(service)::numeric, 2))
      from public.survey_responses
      where venue_id = v_row.id
        and (created_at at time zone v_tz)::date >= v_m1
        and (created_at at time zone v_tz)::date <  v_m0),
    'discovery_30d', (
      select coalesce(json_agg(json_build_object('k', discovery, 'n', n) order by n desc), '[]'::json)
      from (select discovery, count(*) as n
            from public.survey_responses
            where venue_id = v_row.id
              and discovery is not null
              and created_at > now() - interval '30 days'
            group by discovery) d),
    'comments', (
      select coalesce(json_agg(json_build_object('t', comment, 'at', created_at) order by created_at desc), '[]'::json)
      from (select comment, created_at
            from public.survey_responses
            where venue_id = v_row.id and comment is not null and btrim(comment) <> ''
            order by created_at desc
            limit 30) c),
    'game_plays', (
      select coalesce(json_agg(json_build_object('game', game, 'plays', plays) order by plays desc), '[]'::json)
      from public.game_plays where venue_id = v_row.id),
    'events_30d', (
      select json_build_object(
        'opens',         count(*) filter (where event = 'app_open'),
        'review_clicks', count(*) filter (where event = 'review_click'),
        'promo_clicks',  count(*) filter (where event = 'promo_click'),
        'card_opens',    count(*) filter (where event = 'card_open'))
      from public.events
      where venue_id = v_row.id and created_at > now() - interval '30 days')
  );
end;
$$;

revoke all on function public.get_owner_stats(text, text, text) from public;
grant execute on function public.get_owner_stats(text, text, text) to anon, authenticated;

-- Card links get the same server-side treatment owner promo links used to:
-- scheme allowlist (http/https/mailto/tel), scheme filled in for bare
-- domains, and everything else dies here so javascript: and data: never
-- reach a diner's phone. The app's safeUrl() is the second door.
create or replace function public.clean_card_url(p text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_url text;
begin
  v_url := nullif(btrim(coalesce(p, '')), '');
  if v_url is null then return null; end if;
  if v_url ~* '^mailto:' then
    -- kept exactly as typed; must still look like an address
    if v_url !~* '^mailto:[^\s@]+@[^\s@]+\.[^\s@]+$' then return null; end if;
  elsif v_url ~* '^tel:' then
    if v_url !~* '^tel:[+0-9().-]{5,}$' then return null; end if;
  else
    -- owners type "mysite.com/menu", so fill in the scheme for them
    if v_url !~* '^[a-z][a-z0-9+.-]*://' then
      v_url := 'https://' || v_url;
    end if;
    -- host must contain a dot. Anything not http/https lands here and dies.
    if v_url !~* '^https?://[^/\s]+\.[^/\s]+' then return null; end if;
  end if;
  if char_length(v_url) > 500 then return null; end if;
  return v_url;
end;
$$;

create or replace function public.set_venue_games(p_venue_id text, p_key text, p_games text[], p_pass text default null)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row     public.venues%rowtype;
  v_clean   text[];
  v_allowed constant text[] := array['who_knows_who','guess_the_split','wordy','trivia','who_invited_you','fortune_teller','all_talk','cornhole','quick_pour'];
  v_excl    constant text[] := array['horse_racing','ring_toss'];   -- keepable, never addable
begin
  select * into v_row from public.venues where id = p_venue_id;
  if v_row.id is null or p_key is null or v_row.owner_key is distinct from p_key then
    return false;
  end if;
  if not public.owner_pass_ok(v_row.owner_pass, p_pass) then
    return false;
  end if;

  select array_agg(g order by ord) into v_clean
    from (select g, min(ord) as ord
            from unnest(coalesce(p_games, array[]::text[])) with ordinality as t(g, ord)
           where g = any(v_allowed)
              or (g = any(v_excl) and g = any(coalesce(v_row.games, array[]::text[])))
           group by g) s;

  if v_clean is null or array_length(v_clean, 1) < 1 then
    return false;
  end if;

  update public.venues set games = v_clean where id = p_venue_id;
  return true;
end;
$$;

revoke all on function public.set_venue_games(text, text, text[], text) from public;
grant execute on function public.set_venue_games(text, text, text[], text) to anon, authenticated;

-- Landing cards: every write path funnels through this sanitizer. A card is
-- one of three preset shapes (schedule / list / notice); anything else, and
-- any field beyond each shape's whitelist, is dropped. Cards past the cap
-- are dropped from the tail. Booleans are compared as jsonb so a malformed
-- value can never abort the write.
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
      'desc', nullif(left(btrim(coalesce(v_el->>'desc', '')), 120), ''));

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

create or replace function public.set_venue_cards(p_venue_id text, p_key text, p_cards jsonb, p_pass text default null)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.venues%rowtype;
begin
  select * into v_row from public.venues where id = p_venue_id;
  if v_row.id is null or p_key is null or v_row.owner_key is distinct from p_key then
    return false;
  end if;
  if not public.owner_pass_ok(v_row.owner_pass, p_pass) then
    return false;
  end if;

  update public.venues
     set cards = public.clean_cards(p_cards, v_row.card_cap)
   where id = p_venue_id;
  return true;
end;
$$;

revoke all on function public.set_venue_cards(text, text, jsonb, text) from public;
grant execute on function public.set_venue_cards(text, text, jsonb, text) to anon, authenticated;

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
  select * into v_row from public.venues where id = p_venue_id;
  if v_row.id is null or p_key is null or v_row.owner_key is distinct from p_key then
    return false;
  end if;
  if not public.owner_pass_ok(v_row.owner_pass, p_pass) then
    return false;
  end if;
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

revoke all on function public.set_venue_form(text, text, jsonb, jsonb, text) from public;
grant execute on function public.set_venue_form(text, text, jsonb, jsonb, text) to anon, authenticated;

create or replace function public.get_report(
  p_venue_id text,
  p_key      text,
  p_pass     text default null,
  p_from     date default null,   -- inclusive; null with p_to null = all time
  p_to       date default null,   -- exclusive
  p_pf       date default null,   -- previous range (for deltas), optional
  p_pt       date default null
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.venues%rowtype;
  v_tz  constant text := 'America/New_York';
begin
  select * into v_row from public.venues where id = p_venue_id;
  if v_row.id is null or p_key is null or v_row.owner_key is distinct from p_key then
    return null;
  end if;
  if not public.owner_pass_ok(v_row.owner_pass, p_pass) then
    return json_build_object('need_pass', true);
  end if;

  return json_build_object(
    'name',  v_row.name,
    'logo',  v_row.logo,
    'accent', v_row.accent,
    'cur', (
      select json_build_object(
        'count', count(*),
        'food',    round(avg(food)::numeric, 2),
        'service', round(avg(service)::numeric, 2))
      from public.survey_responses
      where venue_id = v_row.id
        and (p_from is null or (created_at at time zone v_tz)::date >= p_from)
        and (p_to   is null or (created_at at time zone v_tz)::date <  p_to)),
    'prev', case when p_pf is null then null else (
      select json_build_object(
        'count', count(*),
        'food',    round(avg(food)::numeric, 2),
        'service', round(avg(service)::numeric, 2))
      from public.survey_responses
      where venue_id = v_row.id
        and (created_at at time zone v_tz)::date >= p_pf
        and (created_at at time zone v_tz)::date <  p_pt) end,
    'discovery', (
      select coalesce(json_agg(json_build_object('k', k, 'n', n) order by n desc), '[]'::json)
      from (select discovery as k, count(*) as n from public.survey_responses
            where venue_id = v_row.id and discovery is not null
              and (p_from is null or (created_at at time zone v_tz)::date >= p_from)
              and (p_to   is null or (created_at at time zone v_tz)::date <  p_to)
            group by discovery) d),
    'plate', (
      select coalesce(json_agg(json_build_object('k', k, 'n', n) order by n desc), '[]'::json)
      from (select plate as k, count(*) as n from public.survey_responses
            where venue_id = v_row.id and plate is not null
              and (p_from is null or (created_at at time zone v_tz)::date >= p_from)
              and (p_to   is null or (created_at at time zone v_tz)::date <  p_to)
            group by plate) d),
    'visit', (
      select coalesce(json_agg(json_build_object('k', k, 'n', n) order by n desc), '[]'::json)
      from (select visit as k, count(*) as n from public.survey_responses
            where venue_id = v_row.id and visit is not null
              and (p_from is null or (created_at at time zone v_tz)::date >= p_from)
              and (p_to   is null or (created_at at time zone v_tz)::date <  p_to)
            group by visit) d),
    'county', (
      select json_build_object(
        'food',    round(avg(sr.food)::numeric, 2),
        'service', round(avg(sr.service)::numeric, 2),
        'discovery', (
          select coalesce(json_agg(json_build_object('k', k, 'pct', pct) order by pct desc), '[]'::json)
          from (select discovery as k,
                       round(100.0 * count(*) / greatest(1, sum(count(*)) over ()), 0) as pct
                from public.survey_responses s2
                join public.venues vv2 on vv2.id = s2.venue_id and vv2.status = 'active'
                where s2.discovery is not null
                  and (p_from is null or (s2.created_at at time zone v_tz)::date >= p_from)
                  and (p_to   is null or (s2.created_at at time zone v_tz)::date <  p_to)
                group by s2.discovery) cd),
        'plate', (
          select coalesce(json_agg(json_build_object('k', k, 'pct', pct) order by pct desc), '[]'::json)
          from (select plate as k,
                       round(100.0 * count(*) / greatest(1, sum(count(*)) over ()), 0) as pct
                from public.survey_responses s2
                join public.venues vv2 on vv2.id = s2.venue_id and vv2.status = 'active'
                where s2.plate is not null
                  and (p_from is null or (s2.created_at at time zone v_tz)::date >= p_from)
                  and (p_to   is null or (s2.created_at at time zone v_tz)::date <  p_to)
                group by s2.plate) cp),
        'visit', (
          select coalesce(json_agg(json_build_object('k', k, 'pct', pct) order by pct desc), '[]'::json)
          from (select visit as k,
                       round(100.0 * count(*) / greatest(1, sum(count(*)) over ()), 0) as pct
                from public.survey_responses s2
                join public.venues vv2 on vv2.id = s2.venue_id and vv2.status = 'active'
                where s2.visit is not null
                  and (p_from is null or (s2.created_at at time zone v_tz)::date >= p_from)
                  and (p_to   is null or (s2.created_at at time zone v_tz)::date <  p_to)
                group by s2.visit) cv))
      from public.survey_responses sr
      join public.venues vv on vv.id = sr.venue_id and vv.status = 'active'
      where (p_from is null or (sr.created_at at time zone v_tz)::date >= p_from)
        and (p_to   is null or (sr.created_at at time zone v_tz)::date <  p_to)),
    'events', (
      select json_build_object(
        'opens',         count(*) filter (where event = 'app_open'),
        'review_clicks', count(*) filter (where event = 'review_click'),
        'promo_clicks',  count(*) filter (where event = 'promo_click'),
        'card_opens',    count(*) filter (where event = 'card_open'))
      from public.events
      where venue_id = v_row.id
        and (p_from is null or (created_at at time zone v_tz)::date >= p_from)
        and (p_to   is null or (created_at at time zone v_tz)::date <  p_to)),
    'events_prev', case when p_pf is null then null else (
      select json_build_object(
        'opens',         count(*) filter (where event = 'app_open'),
        'review_clicks', count(*) filter (where event = 'review_click'),
        'promo_clicks',  count(*) filter (where event = 'promo_click'),
        'card_opens',    count(*) filter (where event = 'card_open'))
      from public.events
      where venue_id = v_row.id
        and (created_at at time zone v_tz)::date >= p_pf
        and (created_at at time zone v_tz)::date <  p_pt) end,
    'games', (
      select coalesce(json_agg(json_build_object('game', game, 'plays', plays) order by plays desc), '[]'::json)
      from public.game_plays where venue_id = v_row.id),
    'comments', (
      select coalesce(json_agg(json_build_object('t', comment, 'at', created_at) order by created_at desc), '[]'::json)
      from (select comment, created_at from public.survey_responses
            where venue_id = v_row.id and comment is not null and btrim(comment) <> ''
              and (p_from is null or (created_at at time zone v_tz)::date >= p_from)
              and (p_to   is null or (created_at at time zone v_tz)::date <  p_to)
            order by created_at desc limit 200) c),
    'extras', (
      select coalesce(json_agg(extra order by created_at desc), '[]'::json)
      from (select extra, created_at from public.survey_responses
            where venue_id = v_row.id and extra is not null
              and (p_from is null or (created_at at time zone v_tz)::date >= p_from)
              and (p_to   is null or (created_at at time zone v_tz)::date <  p_to)
            order by created_at desc limit 500) x),
    'form_custom', v_row.form_custom
  );
end;
$$;

revoke all on function public.get_report(text, text, text, date, date, date, date) from public;
grant execute on function public.get_report(text, text, text, date, date, date, date) to anon, authenticated;

create or replace function public.is_operator()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.operator_users where uid = auth.uid());
$$;

revoke all on function public.is_operator() from public;
grant execute on function public.is_operator() to authenticated;

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
  v_key text;
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;

  if p_id is null or p_id !~ '^[a-z0-9-]{2,40}$' then
    return json_build_object('ok', false, 'error', 'bad_id');
  end if;
  if exists (select 1 from public.venues where id = p_id) then
    return json_build_object('ok', false, 'error', 'id_taken');
  end if;
  if p_name is null or btrim(p_name) = '' then
    return json_build_object('ok', false, 'error', 'bad_name');
  end if;
  if p_accent is null or p_accent !~* '^#[0-9a-f]{6}$' then
    return json_build_object('ok', false, 'error', 'bad_accent');
  end if;
  if p_header_bg is not null and p_header_bg !~* '^#[0-9a-f]{6}$' then
    return json_build_object('ok', false, 'error', 'bad_header_bg');
  end if;

  v_key := gen_random_uuid()::text;

  insert into public.venues (id, name, accent, logo, google_review_link, header_bg, owner_email, owner_key, status)
  values (p_id, btrim(p_name), lower(p_accent), nullif(btrim(coalesce(p_logo,'')),''),
          nullif(btrim(coalesce(p_review,'')),''), lower(p_header_bg),
          nullif(btrim(coalesce(p_owner_email,'')),''), v_key, 'lead');

  return json_build_object('ok', true, 'id', p_id, 'owner_key', v_key);
end;
$$;

revoke all on function public.admin_add_venue(text,text,text,text,text,text,text) from public;
grant execute on function public.admin_add_venue(text,text,text,text,text,text,text) to authenticated;

create or replace function public.admin_list_venues()
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_operator() then return null; end if;
  return (
    select coalesce(json_agg(json_build_object(
      'id', id, 'name', name, 'status', status, 'accent', accent,
      'logo', logo, 'header_bg', header_bg, 'review', google_review_link,
      'owner_email', owner_email, 'owner_key', owner_key,
      'custom_questions', custom_questions, 'games', games,
      'custom_only', custom_only, 'has_pass', owner_pass is not null,
      'dark_mode', dark_mode, 'cards', cards,
      'card_cap', card_cap, 'games_enabled', games_enabled,
      'form_custom', form_custom, 'report_county', report_county,
      'pause_submissions', pause_submissions, 'created_at', created_at
    ) order by created_at desc), '[]'::json)
    from public.venues
  );
end;
$$;

revoke all on function public.admin_list_venues() from public;
revoke execute on function public.admin_list_venues() from anon;
grant execute on function public.admin_list_venues() to authenticated;

create or replace function public.admin_update_venue(
  p_id text, p_name text default null, p_accent text default null,
  p_logo text default null, p_review text default null,
  p_header_bg text default null, p_owner_email text default null)
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  if not exists (select 1 from public.venues where id = p_id) then
    return json_build_object('ok', false, 'error', 'no_such_venue');
  end if;
  if p_accent is not null and p_accent !~* '^#[0-9a-f]{6}$' then
    return json_build_object('ok', false, 'error', 'bad_accent');
  end if;
  if p_header_bg is not null and p_header_bg <> '' and p_header_bg !~* '^#[0-9a-f]{6}$' then
    return json_build_object('ok', false, 'error', 'bad_header_bg');
  end if;

  update public.venues set
    name               = coalesce(nullif(btrim(coalesce(p_name,'')),''), name),
    accent             = coalesce(lower(p_accent), accent),
    logo               = case when p_logo is null then logo else nullif(btrim(p_logo),'') end,
    google_review_link = case when p_review is null then google_review_link else nullif(btrim(p_review),'') end,
    header_bg          = case when p_header_bg is null then header_bg else lower(nullif(btrim(p_header_bg),'')) end,
    owner_email        = case when p_owner_email is null then owner_email else nullif(btrim(p_owner_email),'') end
  where id = p_id;

  return json_build_object('ok', true);
end;
$$;

revoke all on function public.admin_update_venue(text,text,text,text,text,text,text) from public;
grant execute on function public.admin_update_venue(text,text,text,text,text,text,text) to authenticated;

create or replace function public.admin_set_status(p_id text, p_status text)
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  if p_status not in ('lead','active','inactive') then
    return json_build_object('ok', false, 'error', 'bad_status');
  end if;
  update public.venues set status = p_status::public.venue_status where id = p_id;
  if not found then return json_build_object('ok', false, 'error', 'no_such_venue'); end if;
  return json_build_object('ok', true);
end;
$$;

revoke all on function public.admin_set_status(text,text) from public;
grant execute on function public.admin_set_status(text,text) to authenticated;

create or replace function public.admin_rotate_owner_key(p_id text)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_key text;
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  v_key := gen_random_uuid()::text;
  update public.venues set owner_key = v_key where id = p_id;
  if not found then return json_build_object('ok', false, 'error', 'no_such_venue'); end if;
  return json_build_object('ok', true, 'owner_key', v_key);
end;
$$;

revoke all on function public.admin_rotate_owner_key(text) from public;
grant execute on function public.admin_rotate_owner_key(text) to authenticated;

create or replace function public.admin_demo_watch()
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_operator() then return null; end if;
  return (
    select coalesce(json_agg(json_build_object(
      'venue_id', e.venue_id, 'event', e.event, 'meta', e.meta, 'at', e.created_at
    ) order by e.created_at desc), '[]'::json)
    from (
      select e.venue_id, e.event, e.meta, e.created_at
      from public.events e
      join public.venues v on v.id = e.venue_id
      where v.status = 'lead' and e.created_at > now() - interval '14 days'
      order by e.created_at desc
      limit 200
    ) e
  );
end;
$$;

revoke all on function public.admin_demo_watch() from public;
grant execute on function public.admin_demo_watch() to authenticated;

create or replace function public.admin_venue_stats(p_id text)
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_operator() then return null; end if;
  if not exists (select 1 from public.venues where id = p_id) then return null; end if;

  return json_build_object(
    'events_30d', (
      select json_build_object(
        'opens',         count(*) filter (where event = 'app_open'),
        'game_starts',   count(*) filter (where event = 'game_start'),
        'surveys',       count(*) filter (where event = 'survey_submit'),
        'review_clicks', count(*) filter (where event = 'review_click'),
        'promo_clicks',  count(*) filter (where event = 'promo_click'),
        'card_opens',    count(*) filter (where event = 'card_open'))
      from public.events
      where venue_id = p_id and created_at > now() - interval '30 days'),
    'games_30d', (
      select coalesce(json_agg(json_build_object('game', meta, 'n', n) order by n desc), '[]'::json)
      from (select meta, count(*) as n
            from public.events
            where venue_id = p_id and event = 'game_start' and meta is not null
              and created_at > now() - interval '30 days'
            group by meta) g),
    'plays_all_time', (
      select coalesce(json_agg(json_build_object('game', game, 'plays', plays) order by plays desc), '[]'::json)
      from public.game_plays where venue_id = p_id),
    'last_event_at', (
      select max(created_at) from public.events where venue_id = p_id)
  );
end;
$$;

revoke all on function public.admin_venue_stats(text) from public;
revoke execute on function public.admin_venue_stats(text) from anon;
grant execute on function public.admin_venue_stats(text) to authenticated;

create or replace function public.admin_set_games(p_id text, p_games text[])
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_clean   text[];
  v_allowed constant text[] := array
    ['who_knows_who','guess_the_split','wordy','trivia','who_invited_you','fortune_teller','all_talk','cornhole','quick_pour','horse_racing','ring_toss'];
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  if not exists (select 1 from public.venues where id = p_id) then
    return json_build_object('ok', false, 'error', 'no_such_venue');
  end if;

  select array_agg(g order by ord) into v_clean
    from (select g, min(ord) as ord
            from unnest(coalesce(p_games, array[]::text[])) with ordinality as t(g, ord)
           where g = any(v_allowed)
           group by g) s;

  if v_clean is null or array_length(v_clean, 1) < 1 then
    return json_build_object('ok', false, 'error', 'empty_list');
  end if;

  update public.venues set games = v_clean where id = p_id;
  return json_build_object('ok', true, 'games', v_clean);
end;
$$;

revoke all on function public.admin_set_games(text, text[]) from public;
revoke execute on function public.admin_set_games(text, text[]) from anon;
grant execute on function public.admin_set_games(text, text[]) to authenticated;

create or replace function public.admin_set_custom_questions(p_id text, p_on boolean)
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  update public.venues set custom_questions = coalesce(p_on, false) where id = p_id;
  if not found then return json_build_object('ok', false, 'error', 'no_such_venue'); end if;
  return json_build_object('ok', true);
end;
$$;

revoke all on function public.admin_set_custom_questions(text, boolean) from public;
revoke execute on function public.admin_set_custom_questions(text, boolean) from anon;
grant execute on function public.admin_set_custom_questions(text, boolean) to authenticated;

create or replace function public.admin_list_custom(p_id text)
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_operator() then return null; end if;
  return (
    select coalesce(json_agg(json_build_object(
             'game', game, 'key', key, 'label', label,
             'status', status, 'created_at', created_at)
             order by game, created_at desc), '[]'::json)
    from (
      select 'guess_the_split' as game, id::text as key,
             option_a || ' vs ' || option_b as label, status::text, created_at
        from public.gts_questions where venue_id = p_id
      union all
      select 'who_knows_who', id::text, prompt, status::text, created_at
        from public.wkw_questions where venue_id = p_id
      union all
      select 'trivia', id::text, question, status::text, created_at
        from public.trivia_questions where venue_id = p_id
      union all
      select 'wordy', word, word, status::text, created_at
        from public.wordy_words where venue_id = p_id
      union all
      select 'who_invited_you', id::text, category || ': ' || word, status::text, created_at
        from public.wiy_words where venue_id = p_id
      union all
      select 'fortune_teller', id::text, text, status::text, created_at
        from public.fortunes where venue_id = p_id
      union all
      select 'all_talk', id::text, category, status::text, created_at
        from public.at_categories where venue_id = p_id
    ) rows
  );
end;
$$;

revoke all on function public.admin_list_custom(text) from public;
revoke execute on function public.admin_list_custom(text) from anon;
grant execute on function public.admin_list_custom(text) to authenticated;

create or replace function public.admin_add_content(p_game text, p_rows jsonb, p_venue_id text default null)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  r          jsonb;
  v_i        integer := 0;
  v_ok       integer := 0;
  v_errs     jsonb := '[]'::jsonb;
  v_w        text;
  f          text[];
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  if p_game not in ('guess_the_split','who_knows_who','trivia','wordy','who_invited_you','fortune_teller','all_talk') then
    return json_build_object('ok', false, 'error', 'bad_game');
  end if;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    return json_build_object('ok', false, 'error', 'rows_not_array');
  end if;
  if jsonb_array_length(p_rows) > 500 then
    return json_build_object('ok', false, 'error', 'too_many_rows');
  end if;
  if p_venue_id is not null and not exists (select 1 from public.venues where id = p_venue_id) then
    return json_build_object('ok', false, 'error', 'no_such_venue');
  end if;

  for r in select * from jsonb_array_elements(p_rows) loop
    v_i := v_i + 1;
    begin
      -- pull the fields this game needs; nulls/blanks/oversizes fail the row
      if p_game = 'guess_the_split' then
        f := array[btrim(r->>'a'), btrim(r->>'b')];
        if array_position(f, null) is not null or '' = any(f)
           or (select bool_or(char_length(x) > 300) from unnest(f) x) then
          raise exception 'bad_fields';
        end if;
        insert into public.gts_questions (option_a, option_b, venue_id)
        values (f[1], f[2], p_venue_id);

      elsif p_game = 'who_knows_who' then
        f := array[btrim(r->>'prompt'), btrim(r->>'a'), btrim(r->>'b'), btrim(r->>'c'), btrim(r->>'d')];
        if array_position(f, null) is not null or '' = any(f)
           or (select bool_or(char_length(x) > 300) from unnest(f) x) then
          raise exception 'bad_fields';
        end if;
        if position('{N}' in f[1]) = 0 then raise exception 'prompt_needs_{N}'; end if;
        insert into public.wkw_questions (prompt, option_a, option_b, option_c, option_d, venue_id)
        values (f[1], f[2], f[3], f[4], f[5], p_venue_id);

      elsif p_game = 'trivia' then
        f := array[btrim(r->>'question'), btrim(r->>'correct'), btrim(r->>'wrong1'), btrim(r->>'wrong2'), btrim(r->>'wrong3')];
        if array_position(f, null) is not null or '' = any(f)
           or (select bool_or(char_length(x) > 300) from unnest(f) x) then
          raise exception 'bad_fields';
        end if;
        insert into public.trivia_questions (question, correct_answer, wrong_1, wrong_2, wrong_3, venue_id)
        values (f[1], f[2], f[3], f[4], f[5], p_venue_id);

      elsif p_game = 'wordy' then
        v_w := upper(btrim(coalesce(r->>'word', '')));
        if v_w !~ '^[A-Z]{5}$' then raise exception 'bad_word'; end if;
        if exists (select 1 from public.wordy_words where word = v_w) then
          raise exception 'duplicate_word';
        end if;
        insert into public.wordy_words (word, venue_id) values (v_w, p_venue_id);

      elsif p_game = 'who_invited_you' then
        f := array[btrim(r->>'category'), btrim(r->>'word')];
        if array_position(f, null) is not null or '' = any(f)
           or (select bool_or(char_length(x) > 300) from unnest(f) x) then
          raise exception 'bad_fields';
        end if;
        insert into public.wiy_words (category, word, venue_id)
        values (f[1], f[2], p_venue_id);

      elsif p_game = 'fortune_teller' then
        v_w := btrim(coalesce(r->>'text', ''));
        if v_w = '' or char_length(v_w) > 300 then raise exception 'bad_fields'; end if;
        insert into public.fortunes (text, venue_id) values (v_w, p_venue_id);

      elsif p_game = 'all_talk' then
        v_w := btrim(coalesce(r->>'category', ''));
        if v_w = '' or char_length(v_w) > 300 then raise exception 'bad_fields'; end if;
        insert into public.at_categories (category, venue_id) values (v_w, p_venue_id);
      end if;

      v_ok := v_ok + 1;
    exception when others then
      v_errs := v_errs || jsonb_build_object('row', v_i, 'error', sqlerrm);
    end;
  end loop;

  return json_build_object('ok', true, 'inserted', v_ok,
                           'skipped', v_i - v_ok, 'errors', v_errs);
end;
$$;

revoke all on function public.admin_add_content(text, jsonb, text) from public;
revoke execute on function public.admin_add_content(text, jsonb, text) from anon;
grant execute on function public.admin_add_content(text, jsonb, text) to authenticated;

create or replace function public.admin_content_counts()
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_operator() then return null; end if;
  return (
    select json_agg(json_build_object(
      'game', game, 'active', active, 'retired', retired,
      'custom', custom, 'newest', newest) order by game)
    from (
      select 'guess_the_split' as game,
             count(*) filter (where status = 'active'  and venue_id is null) as active,
             count(*) filter (where status = 'retired' and venue_id is null) as retired,
             count(*) filter (where venue_id is not null) as custom,
             max(created_at) as newest
        from public.gts_questions
      union all
      select 'who_knows_who',
             count(*) filter (where status = 'active'  and venue_id is null),
             count(*) filter (where status = 'retired' and venue_id is null),
             count(*) filter (where venue_id is not null), max(created_at)
        from public.wkw_questions
      union all
      select 'trivia',
             count(*) filter (where status = 'active'  and venue_id is null),
             count(*) filter (where status = 'retired' and venue_id is null),
             count(*) filter (where venue_id is not null), max(created_at)
        from public.trivia_questions
      union all
      select 'wordy',
             count(*) filter (where status = 'active'  and venue_id is null),
             count(*) filter (where status = 'retired' and venue_id is null),
             count(*) filter (where venue_id is not null), max(created_at)
        from public.wordy_words
      union all
      select 'who_invited_you',
             count(*) filter (where status = 'active'  and venue_id is null),
             count(*) filter (where status = 'retired' and venue_id is null),
             count(*) filter (where venue_id is not null), max(created_at)
        from public.wiy_words
      union all
      select 'fortune_teller',
             count(*) filter (where status = 'active'  and venue_id is null),
             count(*) filter (where status = 'retired' and venue_id is null),
             count(*) filter (where venue_id is not null), max(created_at)
        from public.fortunes
      union all
      select 'all_talk',
             count(*) filter (where status = 'active'  and venue_id is null),
             count(*) filter (where status = 'retired' and venue_id is null),
             count(*) filter (where venue_id is not null), max(created_at)
        from public.at_categories
    ) t
  );
end;
$$;

revoke all on function public.admin_content_counts() from public;
revoke execute on function public.admin_content_counts() from anon;
grant execute on function public.admin_content_counts() to authenticated;

create or replace function public.admin_set_custom_only(p_id text, p_games text[])
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_clean   text[];
  v_allowed constant text[] := array
    ['who_knows_who','guess_the_split','wordy','trivia','who_invited_you','fortune_teller','all_talk'];
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  if not exists (select 1 from public.venues where id = p_id) then
    return json_build_object('ok', false, 'error', 'no_such_venue');
  end if;

  select coalesce(array_agg(distinct g), array[]::text[]) into v_clean
    from unnest(coalesce(p_games, array[]::text[])) g
   where g = any(v_allowed);

  update public.venues set custom_only = v_clean where id = p_id;
  return json_build_object('ok', true, 'custom_only', v_clean);
end;
$$;

revoke all on function public.admin_set_custom_only(text, text[]) from public;
revoke execute on function public.admin_set_custom_only(text, text[]) from anon;
grant execute on function public.admin_set_custom_only(text, text[]) to authenticated;

create or replace function public.content_floor(p_game text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case p_game
    when 'guess_the_split'    then 5
    when 'who_knows_who'        then 12
    when 'trivia'          then 8
    when 'wordy'           then 5
    when 'who_invited_you' then 5
    when 'fortune_teller'  then 3
    when 'all_talk'        then 5
    else 999999 end;
$$;

revoke all on function public.content_floor(text) from public;
revoke execute on function public.content_floor(text) from anon;
grant execute on function public.content_floor(text) to authenticated;

create or replace function public.shared_active_count(p_game text)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_n integer;
begin
  if p_game = 'guess_the_split' then
    select count(*) into v_n from public.gts_questions where status = 'active' and venue_id is null;
  elsif p_game = 'who_knows_who' then
    select count(*) into v_n from public.wkw_questions where status = 'active' and venue_id is null;
  elsif p_game = 'trivia' then
    select count(*) into v_n from public.trivia_questions where status = 'active' and venue_id is null;
  elsif p_game = 'wordy' then
    select count(*) into v_n from public.wordy_words where status = 'active' and venue_id is null;
  elsif p_game = 'who_invited_you' then
    select count(*) into v_n from public.wiy_words where status = 'active' and venue_id is null;
  elsif p_game = 'fortune_teller' then
    select count(*) into v_n from public.fortunes where status = 'active' and venue_id is null;
  elsif p_game = 'all_talk' then
    select count(*) into v_n from public.at_categories where status = 'active' and venue_id is null;
  else
    v_n := 0;
  end if;
  return v_n;
end;
$$;

revoke all on function public.shared_active_count(text) from public;
revoke execute on function public.shared_active_count(text) from anon;
grant execute on function public.shared_active_count(text) to authenticated;

create or replace function public.admin_retire_before(p_game text, p_before date, p_dry_run boolean default true)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_hit    integer := 0;
  v_active integer;
  v_floor  integer;
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  if p_before is null then return json_build_object('ok', false, 'error', 'bad_date'); end if;
  if p_game not in ('guess_the_split','who_knows_who','trivia','wordy','who_invited_you','fortune_teller','all_talk') then
    return json_build_object('ok', false, 'error', 'bad_game');
  end if;

  v_active := public.shared_active_count(p_game);
  v_floor  := public.content_floor(p_game);

  if p_game = 'guess_the_split' then
    select count(*) into v_hit from public.gts_questions
     where status = 'active' and venue_id is null and created_at < p_before;
  elsif p_game = 'who_knows_who' then
    select count(*) into v_hit from public.wkw_questions
     where status = 'active' and venue_id is null and created_at < p_before;
  elsif p_game = 'trivia' then
    select count(*) into v_hit from public.trivia_questions
     where status = 'active' and venue_id is null and created_at < p_before;
  elsif p_game = 'wordy' then
    select count(*) into v_hit from public.wordy_words
     where status = 'active' and venue_id is null and created_at < p_before;
  elsif p_game = 'who_invited_you' then
    select count(*) into v_hit from public.wiy_words
     where status = 'active' and venue_id is null and created_at < p_before;
  elsif p_game = 'fortune_teller' then
    select count(*) into v_hit from public.fortunes
     where status = 'active' and venue_id is null and created_at < p_before;
  elsif p_game = 'all_talk' then
    select count(*) into v_hit from public.at_categories
     where status = 'active' and venue_id is null and created_at < p_before;
  end if;

  if v_active - v_hit < v_floor then
    return json_build_object('ok', false, 'error', 'below_floor',
      'would_retire', v_hit, 'active_now', v_active, 'floor', v_floor);
  end if;

  if p_dry_run then
    return json_build_object('ok', true, 'dry_run', true,
      'would_retire', v_hit, 'active_now', v_active,
      'left_active', v_active - v_hit, 'floor', v_floor);
  end if;

  if p_game = 'guess_the_split' then
    update public.gts_questions set status = 'retired'
     where status = 'active' and venue_id is null and created_at < p_before;
  elsif p_game = 'who_knows_who' then
    update public.wkw_questions set status = 'retired'
     where status = 'active' and venue_id is null and created_at < p_before;
  elsif p_game = 'trivia' then
    update public.trivia_questions set status = 'retired'
     where status = 'active' and venue_id is null and created_at < p_before;
  elsif p_game = 'wordy' then
    update public.wordy_words set status = 'retired'
     where status = 'active' and venue_id is null and created_at < p_before;
  elsif p_game = 'who_invited_you' then
    update public.wiy_words set status = 'retired'
     where status = 'active' and venue_id is null and created_at < p_before;
  elsif p_game = 'fortune_teller' then
    update public.fortunes set status = 'retired'
     where status = 'active' and venue_id is null and created_at < p_before;
  elsif p_game = 'all_talk' then
    update public.at_categories set status = 'retired'
     where status = 'active' and venue_id is null and created_at < p_before;
  end if;

  return json_build_object('ok', true, 'dry_run', false,
    'retired', v_hit, 'left_active', v_active - v_hit);
end;
$$;

revoke all on function public.admin_retire_before(text, date, boolean) from public;
revoke execute on function public.admin_retire_before(text, date, boolean) from anon;
grant execute on function public.admin_retire_before(text, date, boolean) to authenticated;

create or replace function public.admin_set_content_status(p_game text, p_key text, p_status text)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n integer := 0;
  v_is_shared boolean;
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  if p_status not in ('active','retired') then
    return json_build_object('ok', false, 'error', 'bad_status');
  end if;

  if p_game = 'guess_the_split' then
    select venue_id is null into v_is_shared from public.gts_questions where id::text = p_key;
  elsif p_game = 'who_knows_who' then
    select venue_id is null into v_is_shared from public.wkw_questions where id::text = p_key;
  elsif p_game = 'trivia' then
    select venue_id is null into v_is_shared from public.trivia_questions where id::text = p_key;
  elsif p_game = 'wordy' then
    select venue_id is null into v_is_shared from public.wordy_words where word = p_key;
  elsif p_game = 'who_invited_you' then
    select venue_id is null into v_is_shared from public.wiy_words where id::text = p_key;
  elsif p_game = 'fortune_teller' then
    select venue_id is null into v_is_shared from public.fortunes where id::text = p_key;
  elsif p_game = 'all_talk' then
    select venue_id is null into v_is_shared from public.at_categories where id::text = p_key;
  else
    return json_build_object('ok', false, 'error', 'bad_game');
  end if;

  if v_is_shared is null then return json_build_object('ok', false, 'error', 'no_such_row'); end if;

  if v_is_shared and p_status = 'retired'
     and public.shared_active_count(p_game) - 1 < public.content_floor(p_game) then
    return json_build_object('ok', false, 'error', 'below_floor', 'floor', public.content_floor(p_game));
  end if;

  if p_game = 'guess_the_split' then
    update public.gts_questions set status = p_status::public.content_status where id::text = p_key;
  elsif p_game = 'who_knows_who' then
    update public.wkw_questions set status = p_status::public.content_status where id::text = p_key;
  elsif p_game = 'trivia' then
    update public.trivia_questions set status = p_status::public.content_status where id::text = p_key;
  elsif p_game = 'wordy' then
    update public.wordy_words set status = p_status::public.content_status where word = p_key;
  elsif p_game = 'who_invited_you' then
    update public.wiy_words set status = p_status::public.content_status where id::text = p_key;
  elsif p_game = 'fortune_teller' then
    update public.fortunes set status = p_status::public.content_status where id::text = p_key;
  elsif p_game = 'all_talk' then
    update public.at_categories set status = p_status::public.content_status where id::text = p_key;
  end if;

  get diagnostics v_n = row_count;
  if v_n = 0 then return json_build_object('ok', false, 'error', 'no_such_row'); end if;
  return json_build_object('ok', true);
end;
$$;

revoke all on function public.admin_set_content_status(text, text, text) from public;
revoke execute on function public.admin_set_content_status(text, text, text) from anon;
grant execute on function public.admin_set_content_status(text, text, text) to authenticated;

create or replace function public.admin_search_content(p_game text, p_q text)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_q text := '%' || lower(coalesce(p_q,'')) || '%';
begin
  if not public.is_operator() then return null; end if;
  if p_q is null or btrim(p_q) = '' then return '[]'::json; end if;

  if p_game = 'guess_the_split' then
    return (select coalesce(json_agg(j), '[]'::json) from (
      select json_build_object('game','guess_the_split','key',id::text,
        'label', option_a || ' vs ' || option_b, 'status', status::text,
        'venue_id', venue_id, 'created_at', created_at) j
      from public.gts_questions
      where lower(option_a || ' vs ' || option_b) like v_q
      order by created_at desc limit 50) s);
  elsif p_game = 'who_knows_who' then
    return (select coalesce(json_agg(j), '[]'::json) from (
      select json_build_object('game','who_knows_who','key',id::text,
        'label', prompt, 'status', status::text,
        'venue_id', venue_id, 'created_at', created_at) j
      from public.wkw_questions
      where lower(prompt || ' ' || option_a || ' ' || option_b || ' ' || option_c || ' ' || option_d) like v_q
      order by created_at desc limit 50) s);
  elsif p_game = 'trivia' then
    return (select coalesce(json_agg(j), '[]'::json) from (
      select json_build_object('game','trivia','key',id::text,
        'label', question || ' (' || correct_answer || ')', 'status', status::text,
        'venue_id', venue_id, 'created_at', created_at) j
      from public.trivia_questions
      where lower(question || ' ' || correct_answer || ' ' || wrong_1 || ' ' || wrong_2 || ' ' || wrong_3) like v_q
      order by created_at desc limit 50) s);
  elsif p_game = 'wordy' then
    return (select coalesce(json_agg(j), '[]'::json) from (
      select json_build_object('game','wordy','key',word,
        'label', word, 'status', status::text,
        'venue_id', venue_id, 'created_at', created_at) j
      from public.wordy_words
      where lower(word) like v_q
      order by created_at desc limit 50) s);
  elsif p_game = 'who_invited_you' then
    return (select coalesce(json_agg(j), '[]'::json) from (
      select json_build_object('game','who_invited_you','key',id::text,
        'label', category || ': ' || word, 'status', status::text,
        'venue_id', venue_id, 'created_at', created_at) j
      from public.wiy_words
      where lower(category || ' ' || word) like v_q
      order by created_at desc limit 50) s);
  elsif p_game = 'fortune_teller' then
    return (select coalesce(json_agg(j), '[]'::json) from (
      select json_build_object('game','fortune_teller','key',id::text,
        'label', text, 'status', status::text,
        'venue_id', venue_id, 'created_at', created_at) j
      from public.fortunes
      where lower(text) like v_q
      order by created_at desc limit 50) s);
  elsif p_game = 'all_talk' then
    return (select coalesce(json_agg(j), '[]'::json) from (
      select json_build_object('game','all_talk','key',id::text,
        'label', category, 'status', status::text,
        'venue_id', venue_id, 'created_at', created_at) j
      from public.at_categories
      where lower(category) like v_q
      order by created_at desc limit 50) s);
  end if;

  return json_build_object('ok', false, 'error', 'bad_game');
end;
$$;

revoke all on function public.admin_search_content(text, text) from public;
revoke execute on function public.admin_search_content(text, text) from anon;
grant execute on function public.admin_search_content(text, text) to authenticated;

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
  if v_pass is not null and (char_length(v_pass) < 4 or char_length(v_pass) > 72) then
    return json_build_object('ok', false, 'error', 'bad_length');
  end if;

  update public.venues
     set owner_pass = case when v_pass is null then null
                           else extensions.crypt(v_pass, extensions.gen_salt('bf')) end
   where id = p_id;
  if not found then return json_build_object('ok', false, 'error', 'no_such_venue'); end if;
  return json_build_object('ok', true, 'has_pass', v_pass is not null);
end;
$$;

revoke all on function public.admin_set_owner_pass(text, text) from public;
revoke execute on function public.admin_set_owner_pass(text, text) from anon;
grant execute on function public.admin_set_owner_pass(text, text) to authenticated;

create or replace function public.admin_set_dark_mode(p_id text, p_on boolean)
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  update public.venues set dark_mode = coalesce(p_on, false) where id = p_id;
  if not found then return json_build_object('ok', false, 'error', 'no_such_venue'); end if;
  return json_build_object('ok', true);
end;
$$;

revoke all on function public.admin_set_dark_mode(text, boolean) from public;
revoke execute on function public.admin_set_dark_mode(text, boolean) from anon;
grant execute on function public.admin_set_dark_mode(text, boolean) to authenticated;

create or replace function public.admin_set_cards(p_id text, p_cards jsonb)
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  update public.venues set cards = public.clean_cards(p_cards, card_cap) where id = p_id;
  if not found then return json_build_object('ok', false, 'error', 'no_such_venue'); end if;
  return json_build_object('ok', true);
end;
$$;

revoke all on function public.admin_set_cards(text, jsonb) from public;
revoke execute on function public.admin_set_cards(text, jsonb) from anon;
grant execute on function public.admin_set_cards(text, jsonb) to authenticated;

-- Raising the cap is the sellable knob; lowering it re-trims the saved cards
-- through the sanitizer so the app and the editors always agree.
create or replace function public.admin_set_card_cap(p_id text, p_cap integer)
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  if p_cap is null or p_cap < 0 or p_cap > 20 then return json_build_object('ok', false, 'error', 'bad_cap'); end if;
  update public.venues
     set card_cap = p_cap,
         cards    = public.clean_cards(cards, p_cap)
   where id = p_id;
  if not found then return json_build_object('ok', false, 'error', 'no_such_venue'); end if;
  return json_build_object('ok', true);
end;
$$;

revoke all on function public.admin_set_card_cap(text, integer) from public;
revoke execute on function public.admin_set_card_cap(text, integer) from anon;
grant execute on function public.admin_set_card_cap(text, integer) to authenticated;

create or replace function public.admin_set_games_enabled(p_id text, p_on boolean)
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  update public.venues set games_enabled = coalesce(p_on, true) where id = p_id;
  if not found then return json_build_object('ok', false, 'error', 'no_such_venue'); end if;
  return json_build_object('ok', true);
end;
$$;

revoke all on function public.admin_set_games_enabled(text, boolean) from public;
revoke execute on function public.admin_set_games_enabled(text, boolean) from anon;
grant execute on function public.admin_set_games_enabled(text, boolean) to authenticated;

create or replace function public.admin_set_form_custom(p_id text, p_on boolean)
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  update public.venues set form_custom = coalesce(p_on, false) where id = p_id;
  if not found then return json_build_object('ok', false, 'error', 'no_such_venue'); end if;
  return json_build_object('ok', true);
end;
$$;

revoke all on function public.admin_set_form_custom(text, boolean) from public;
revoke execute on function public.admin_set_form_custom(text, boolean) from anon;
grant execute on function public.admin_set_form_custom(text, boolean) to authenticated;

create or replace function public.admin_set_form(p_id text, p_core jsonb, p_extras jsonb)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
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
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  if p_id <> 'global' and not exists (select 1 from public.venues where id = p_id) then
    return json_build_object('ok', false, 'error', 'no_such_venue');
  end if;

  -- core: only the five known keys, booleans, default true
  foreach v_k in array array['food','service','discovery','plate','visit'] loop
    v_core := v_core || jsonb_build_object(v_k,
      coalesce((p_core ->> v_k)::boolean, true));
  end loop;

  -- extras: max 10, known types, clean labels/opts, unique ids
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
  values (p_id, v_core, v_extras, now())
  on conflict (id) do update
    set core = excluded.core, extras = excluded.extras, updated_at = now();

  return json_build_object('ok', true, 'core', v_core, 'extras', v_extras);
end;
$$;

revoke all on function public.admin_set_form(text, jsonb, jsonb) from public;
revoke execute on function public.admin_set_form(text, jsonb, jsonb) from anon;
grant execute on function public.admin_set_form(text, jsonb, jsonb) to authenticated;

create or replace function public.admin_set_report_county(p_id text, p_on boolean)
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  update public.venues set report_county = coalesce(p_on, true) where id = p_id;
  if not found then return json_build_object('ok', false, 'error', 'no_such_venue'); end if;
  return json_build_object('ok', true, 'report_county', coalesce(p_on, true));
end;
$$;

revoke all on function public.admin_set_report_county(text, boolean) from public;
revoke execute on function public.admin_set_report_county(text, boolean) from anon;
grant execute on function public.admin_set_report_county(text, boolean) to authenticated;

-- ============================================================================
--  PLATFORM UPDATE MACHINERY
-- ============================================================================
--  Updates ship as files in the repo plus numbered migrations under
--  public/migrations/. The dashboard's Platform section fetches pending
--  migrations and applies them through admin_run_migration: strictly
--  in order, each exactly once, every statement of a migration inside
--  this one call (one transaction). Only the operator can run it.
-- ---------------------------------------------------------------------------
create or replace function public.admin_run_migration(p_version integer, p_statements jsonb)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cur integer;
  v_s   text;
  v_n   integer := 0;
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  if p_version is null or p_statements is null or jsonb_typeof(p_statements) <> 'array' then
    return json_build_object('ok', false, 'error', 'bad_args');
  end if;

  select coalesce(max(version), 0) into v_cur from public.schema_migrations;
  if p_version <= v_cur then
    return json_build_object('ok', true, 'skipped', true, 'at', v_cur);
  end if;
  if p_version <> v_cur + 1 then
    return json_build_object('ok', false, 'error', 'out_of_order', 'at', v_cur, 'got', p_version);
  end if;

  for v_s in select value #>> '{}' from jsonb_array_elements(p_statements) loop
    if nullif(btrim(coalesce(v_s, '')), '') is null then continue; end if;
    execute v_s;
    v_n := v_n + 1;
  end loop;

  insert into public.schema_migrations (version) values (p_version);
  return json_build_object('ok', true, 'version', p_version, 'statements', v_n);
end;
$$;

revoke all on function public.admin_run_migration(integer, jsonb) from public;
revoke execute on function public.admin_run_migration(integer, jsonb) from anon;
grant execute on function public.admin_run_migration(integer, jsonb) to authenticated;

create or replace function public.admin_schema_version()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select case when public.is_operator()
              then (select coalesce(max(version), 0) from public.schema_migrations)
              else null end;
$$;

revoke all on function public.admin_schema_version() from public;
revoke execute on function public.admin_schema_version() from anon;
grant execute on function public.admin_schema_version() to authenticated;

-- operator key/value settings (e.g. GitHub token + repo for one-button sync)
create or replace function public.admin_set_setting(p_key text, p_value text)
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_operator() then return json_build_object('ok', false, 'error', 'not_operator'); end if;
  if p_key is null or p_key !~ '^[a-z0-9_.-]{1,64}$' then
    return json_build_object('ok', false, 'error', 'bad_key');
  end if;
  if p_value is null or btrim(p_value) = '' then
    delete from public.operator_settings where key = p_key;
  else
    insert into public.operator_settings (key, value, updated_at)
    values (p_key, left(btrim(p_value), 2000), now())
    on conflict (key) do update set value = excluded.value, updated_at = now();
  end if;
  return json_build_object('ok', true);
end;
$$;

revoke all on function public.admin_set_setting(text, text) from public;
revoke execute on function public.admin_set_setting(text, text) from anon;
grant execute on function public.admin_set_setting(text, text) to authenticated;

create or replace function public.admin_get_settings()
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_operator() then return null; end if;
  return (
    select coalesce(json_object_agg(key, value), '{}'::json)
    from public.operator_settings
  );
end;
$$;

revoke all on function public.admin_get_settings() from public;
revoke execute on function public.admin_get_settings() from anon;
grant execute on function public.admin_get_settings() to authenticated;

-- ============================================================================
--  STARTER DATA
-- ============================================================================
--  One demo venue for your homepage's "Try the demo" button and your sales
--  demos. Rebrand it from the dashboard (name, logo, colors); its id stays
--  'demo'. Status 'lead' renders and plays but saves nothing except
--  app_open events, which is exactly what a demo should do.
insert into venues (id, name, logo, accent, status)
values ('demo', 'Demo Restaurant', 'DEMO RESTAURANT', '#3a6ea5', 'lead');

-- ============================================================================
--  OPERATOR ACCOUNT  ·  >>> EDIT THIS LINE <<<
-- ============================================================================
--  Replace you@example.com with the email of the Supabase auth user you
--  created in step 1 of the header. Keep the quotes.
insert into operator_users (uid)
select id from auth.users where email = 'you@example.com';

--  Abort-and-rollback guard: if the email above matched no auth user,
--  NOTHING in this file survives. Fix the line and run the file again.
do $$
begin
  if not exists (select 1 from operator_users) then
    raise exception 'No auth user found with that email. Create the user under Authentication > Users, edit the >>> EDIT THIS LINE <<< insert above, and run this whole file again.';
  end if;
end $$;

-- ============================================================================
--  Done. Next: run install/baseline_content.sql, then follow SETUP.md.
-- ============================================================================
