-- "Find the Groom" — Prague stag hunt, Fri 21 Aug 2026
-- Deployed on Supabase project yfzbgvqthrgqardavayq. All objects are prefixed
-- stag_ so they can be dropped cleanly afterwards.
--
-- SECURITY MODEL
-- RLS is ON with NO policies on the stag_ tables, so the anon key cannot touch
-- them directly. Everything goes through SECURITY DEFINER functions, which is
-- what keeps target_bar off the wire while the game is running (a team learns
-- it only once they find it, or at the reveal).
--
-- SCORING
-- Finding the groom = 5 pts and play CONTINUES; every other pub = mult pts
-- (1, or 2/4 when banana'd). The game ends on admin reveal, or once all three
-- teams have found him. Winner = most points.
--
-- THE WHEEL
-- Segments live in JSON: [{"t":"SHOTS","w":20,"free":true,"after":3}, ...]
--   t     segment name
--   w     relative share; weights summing to 100 read straight as percentages
--   free  a free pass: nobody drinks and no proof photo is owed
--   after segment only appears once the team has done this many pubs
-- stag_game.wheel_options is the default; stag_pub_wheels overrides it per pub.
-- The effective list (after per-team `after` filtering) is stamped onto each
-- guess as rig_opts, so editing a wheel never rewrites a forfeit already dealt.
--
-- PROOF GATE
-- A wrong, non-free-pass spin must have its photo uploaded before that team's
-- next guess is accepted, however long ago the cooldown expired. An admin
-- unlock waives both the cooldown and the proof debt.
--
-- NOTE: the live admin_pass has been rotated away from this default.

-- ---------------------------------------------------------------- tables ---

create table if not exists public.stag_game (
  id               smallint primary key default 1 check (id = 1),
  target_bar       text,
  status           text        not null default 'running'
                     check (status in ('running', 'won', 'revealed')),
  winning_team     text,        -- legacy, unused since the scoring model
  won_at           timestamptz, -- legacy, unused since the scoring model
  cooldown_seconds integer     not null default 600,
  hint_text        text,
  hint_after       integer     not null default 4,
  wheel_enabled    boolean     not null default true,
  wheel_options    jsonb       not null default
    '[{"t":"PINTS OF LAGER","w":20},{"t":"SHOTS","w":20},{"t":"MIXERS","w":20},{"t":"BARMAN''S CHOICE","w":20},{"t":"FREE PASS","w":20,"free":true}]'::jsonb,
  show_rivals      boolean     not null default false,
  admin_pass       text        not null default 'zizkov2026',
  updated_at       timestamptz not null default now()
);

insert into public.stag_game (id) values (1) on conflict (id) do nothing;

create table if not exists public.stag_guesses (
  id         bigint generated always as identity primary key,
  team       text        not null,
  bar        text        not null,
  correct    boolean     not null,
  mult       integer     not null default 1,    -- banana multiplier, stamped at guess time
  banana_by  text[],                            -- who trapped it (null if nobody)
  rig_drink  integer,                           -- index into rig_opts (null = wheel was off)
  rig_count  integer,
  rig_text   text,                              -- outcome name at stamp time
  rig_free   boolean     not null default false,-- outcome was a free pass
  rig_opts   jsonb,                             -- the exact wheel this guess was judged against
  rigged     boolean     not null default false,-- true only when an admin rig produced it
  created_at timestamptz not null default now()
);

-- The reliability guarantee: a retried request is rejected by this index and
-- served as an idempotent replay, so a team can never burn a pub twice.
create unique index if not exists stag_guesses_team_bar
  on public.stag_guesses (team, bar);

create table if not exists public.stag_unlock (
  team      text primary key,
  waived_at timestamptz not null default now()
);

create table if not exists public.stag_bananas (
  id         bigint generated always as identity primary key,
  team       text        not null,
  bar        text        not null,
  created_at timestamptz not null default now()
);
create unique index if not exists stag_bananas_team_bar
  on public.stag_bananas (team, bar);

create table if not exists public.stag_photos (
  team       text        not null,
  bar        text        not null,
  path       text        not null,   -- object key in the public stag-photos bucket
  created_at timestamptz not null default now(),
  primary key (team, bar)
);

-- Admin-rigged spins, consumed by the team's next wrong guess. drink_text is
-- matched first so a rig fires on a pub whose custom wheel orders segments
-- differently; an unmatched rig is dropped and the spin is fair.
create table if not exists public.stag_rig (
  team        text primary key,
  drink_idx   integer not null,
  drink_text  text,
  drink_count integer not null default 3 check (drink_count between 1 and 5),
  created_at  timestamptz not null default now()
);

-- Per-pub wheel overrides. A pub with no row uses stag_game.wheel_options.
create table if not exists public.stag_pub_wheels (
  bar        text primary key,
  options    jsonb       not null,
  updated_at timestamptz not null default now()
);

alter table public.stag_game       enable row level security;
alter table public.stag_guesses    enable row level security;
alter table public.stag_unlock     enable row level security;
alter table public.stag_bananas    enable row level security;
alter table public.stag_photos     enable row level security;
alter table public.stag_rig        enable row level security;
alter table public.stag_pub_wheels enable row level security;

-- Photo files: public-read bucket, anon may INSERT only (no update/delete —
-- evidence is immutable; a replacement is a new file the row points at).
insert into storage.buckets (id, name, public)
values ('stag-photos', 'stag-photos', true)
on conflict (id) do update set public = true;

drop policy if exists "stag_photos_ins" on storage.objects;
create policy "stag_photos_ins" on storage.objects
  for insert to anon with check (bucket_id = 'stag-photos');

-- ------------------------------------------------------------- functions ---
-- Bodies below are the deployed definitions, dumped from the live database.

-- ------------------------------------------------------------ validation ---

create or replace function public.stag_valid_bar(p_bar text)
returns boolean
language sql
immutable
as $$
  select p_bar in (
    'U Sadu', 'Áčko Žižkov', 'Bukowski''s Bar', 'Woodoo', 'Bar Bohužel',
    'Theatrino Cocktail Bar', 'Maverick''s Irish pub', 'SMÄD craft beer bar',
    'Pivoteka Žižkoff', 'Pub a Bar Na Plech', 'Tiki Taky Bar', 'Vlkova 26',
    'U Vystřelenýho oka', 'U Slovanské lípy', 'Café Pavlač',
    'Hospůdka Nad Viktorkou', 'Sedm vlků', 'U Vodoucha');
$$;

-- Shared by the default wheel and every per-pub override.
create or replace function public.stag_valid_wheel(p_opts jsonb)
returns boolean
language sql
immutable
as $$
  select p_opts is not null
     and jsonb_typeof(p_opts) = 'array'
     and jsonb_array_length(p_opts) between 2 and 8
     and not exists (select 1 from jsonb_array_elements(p_opts) e
                      where coalesce(trim(e->>'t'), '') = '')
     and not exists (select 1 from jsonb_array_elements(p_opts) e
                      where (e ? 'w') and (jsonb_typeof(e->'w') <> 'number'
                                           or (e->>'w')::numeric <= 0))
     and not exists (select 1 from jsonb_array_elements(p_opts) e
                      where (e ? 'after') and (jsonb_typeof(e->'after') <> 'number'
                                               or (e->>'after')::numeric < 0
                                               or (e->>'after')::numeric > 30))
     -- at least two segments must be available from the very first pub,
     -- otherwise an early spin would have nothing to land on
     and (select count(*) from jsonb_array_elements(p_opts) e
           where coalesce((e->>'after')::numeric, 0) <= 0) >= 2;
$$;

-- ------------------------------------------------------------- read state ---

create or replace function public.stag_state(p_team text default null)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  g         public.stag_game;
  wrongs    integer := 0;
  waived    timestamptz;
  last_at   timestamptz;
  last_g    public.stag_guesses;
  i_found   boolean := false;
  proof_due text := null;
begin
  select * into g from public.stag_game where id = 1;

  select count(*) into wrongs
    from public.stag_guesses where team = p_team and not correct;

  select exists(select 1 from public.stag_guesses
                 where team = p_team and correct) into i_found;

  select * into last_g
    from public.stag_guesses where team = p_team
    order by created_at desc limit 1;
  last_at := last_g.created_at;

  select waived_at into waived
    from public.stag_unlock where team = p_team;

  -- mirrors the stag_guess proof gate so clients can hold the red screen
  if last_g.id is not null and not last_g.correct and g.wheel_enabled
     and last_g.rig_drink is not null and not coalesce(last_g.rig_free, false)
     and (waived is null or waived < last_g.created_at)
     and not exists(select 1 from public.stag_photos sp
                     where sp.team = p_team and sp.bar = last_g.bar) then
    proof_due := last_g.bar;
  end if;

  -- a waiver newer than the team's last guess cancels their cooldown
  if waived is not null and last_at is not null and waived > last_at then
    last_at := null;
  end if;

  return json_build_object(
    'server_now',       now(),
    'status',           g.status,
    'cooldown_seconds', g.cooldown_seconds,
    'wheel',            g.wheel_enabled,
    'wheel_options',    g.wheel_options,
    'target_bar',       case when g.status <> 'running' or i_found
                             then g.target_bar else null end,
    'hint',             case when p_team is not null and wrongs >= g.hint_after
                             then g.hint_text else null end,
    'last_guess_at',    last_at,
    'proof_due',        proof_due,
    'bananas_left',     3 - (select count(*) from public.stag_bananas where team = p_team),
    'my_bananas',       coalesce((
                          select json_agg(bar)
                          from public.stag_bananas where team = p_team), '[]'::json),
    'my_guesses',       coalesce((
                          select json_agg(json_build_object(
                                   'bar', gg.bar, 'correct', gg.correct, 'at', gg.created_at,
                                   'mult', gg.mult, 'by', gg.banana_by,
                                   'rig_d', gg.rig_drink, 'rig_c', gg.rig_count,
                                   'rig_t', gg.rig_text, 'rig_f', gg.rig_free,
                                   'rig_opts', gg.rig_opts,
                                   'photo', (select path from public.stag_photos sp
                                              where sp.team = gg.team and sp.bar = gg.bar))
                                 order by gg.created_at)
                          from public.stag_guesses gg where gg.team = p_team), '[]'::json),
    'scores',           coalesce((
                          select json_object_agg(team, pts)
                          from (select team,
                                       sum(case when correct then 5 else mult end) pts
                                from public.stag_guesses group by team) s), '{}'::json),
    'found',            coalesce((
                          select json_object_agg(team, created_at)
                          from public.stag_guesses where correct), '{}'::json),
    'counts',           coalesce((
                          select json_object_agg(team, n)
                          from (select team, count(*) n
                                from public.stag_guesses group by team) t), '{}'::json),
    'rival_bars',       case when g.show_rivals then coalesce((
                          select json_agg(distinct bar)
                          from public.stag_guesses
                          where team is distinct from p_team), '[]'::json)
                        else '[]'::json end
  );
end;
$$;

-- ------------------------------------------------------------------ guess ---

create or replace function public.stag_guess(p_team text, p_bar text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  g          public.stag_game;
  existing   public.stag_guesses;
  last_g     public.stag_guesses;
  last_at    timestamptz;
  waived     timestamptz;
  remaining  integer;
  is_correct boolean;
  attackers  text[];
  v_mult     integer;
  finders    integer;
  rig        public.stag_rig;
  eff        jsonb;
  eff_f      jsonb;
  pubs       integer;
  n_opts     integer;
  w_total    numeric;
  w_roll     numeric;
  w_acc      numeric;
  i          integer;
  hit        integer;
  v_rig_d    integer;
  v_rig_c    integer;
  v_rig_t    text;
  v_rig_f    boolean;
  v_rigged   boolean := false;
begin
  if p_team not in ('ALPHA', 'BRAVO', 'CHARLIE') then
    return json_build_object('result', 'error', 'message', 'Unknown team');
  end if;
  if not public.stag_valid_bar(p_bar) then
    return json_build_object('result', 'error', 'message', 'Unknown bar');
  end if;

  -- row lock serialises concurrent guesses across teams
  select * into g from public.stag_game where id = 1 for update;

  -- idempotent replay: a retried request returns the original answer, so a
  -- lost response can always be retried safely
  select * into existing
    from public.stag_guesses where team = p_team and bar = p_bar;
  if found then
    return json_build_object(
      'result',     case when existing.correct then 'correct' else 'wrong' end,
      'replay',     true,
      'at',         existing.created_at,
      'mult',       existing.mult,
      'by',         existing.banana_by,
      'rig_d',      existing.rig_drink,
      'rig_c',      existing.rig_count,
      'rig_t',      existing.rig_text,
      'rig_f',      existing.rig_free,
      'rig_opts',   existing.rig_opts,
      'server_now', now(),
      'cooldown_seconds', g.cooldown_seconds);
  end if;

  if g.status <> 'running' then
    return json_build_object('result', 'over', 'server_now', now());
  end if;

  select waived_at into waived from public.stag_unlock where team = p_team;

  -- proof gate: the previous non-free forfeit needs its photo, however long
  -- ago the cooldown expired. An admin unlock waives it.
  select * into last_g
    from public.stag_guesses where team = p_team
    order by created_at desc limit 1;
  if last_g.id is not null and not last_g.correct and g.wheel_enabled
     and last_g.rig_drink is not null and not coalesce(last_g.rig_free, false)
     and (waived is null or waived < last_g.created_at)
     and not exists(select 1 from public.stag_photos sp
                     where sp.team = p_team and sp.bar = last_g.bar) then
    return json_build_object('result', 'need_proof', 'bar', last_g.bar,
                             'server_now', now());
  end if;

  last_at := last_g.created_at;
  if waived is not null and last_at is not null and waived > last_at then
    last_at := null;
  end if;

  if last_at is not null then
    remaining := g.cooldown_seconds - floor(extract(epoch from (now() - last_at)));
    if remaining > 0 then
      return json_build_object('result', 'locked',
                               'remaining', remaining, 'server_now', now());
    end if;
  end if;

  is_correct := (g.target_bar is not null and p_bar = g.target_bar);

  -- rival bananas on this pub at the moment of guessing, stamped on the row
  select coalesce(array_agg(team order by team), '{}') into attackers
    from public.stag_bananas where bar = p_bar and team <> p_team;
  v_mult := power(2, coalesce(array_length(attackers, 1), 0))::integer;

  if not is_correct and g.wheel_enabled then
    -- this pub's own wheel if it has one, else the game-wide wheel
    select options into eff from public.stag_pub_wheels where bar = p_bar;
    if eff is null or jsonb_array_length(eff) < 2 then
      eff := g.wheel_options;
    end if;

    -- pubs this team has already done (this guess is their pubs+1'th)
    select count(*) into pubs from public.stag_guesses where team = p_team;

    -- drop segments still locked for this team
    select coalesce(jsonb_agg(e), '[]'::jsonb) into eff_f
      from jsonb_array_elements(eff) e
     where coalesce((e->>'after')::numeric, 0) <= pubs;
    if jsonb_array_length(eff_f) >= 2 then
      eff := eff_f;
    end if;

    n_opts := jsonb_array_length(eff);

    select * into rig from public.stag_rig where team = p_team;
    hit := null;
    if rig.team is not null then
      -- match the rigged segment by NAME inside this pub's wheel. The alias
      -- must not be `i` — it would shadow the loop variable declared above.
      if rig.drink_text is not null then
        select gs into hit
          from generate_series(0, n_opts - 1) gs
         where lower(eff->gs->>'t') = lower(rig.drink_text)
         limit 1;
      end if;
      if hit is null and rig.drink_idx >= 0 and rig.drink_idx < n_opts then
        hit := rig.drink_idx;
      end if;
      delete from public.stag_rig where team = p_team;
    end if;

    if hit is not null then
      v_rig_d  := hit;
      v_rig_c  := rig.drink_count;
      v_rigged := true;
    else
      -- weighted pick: walk the cumulative shares
      select coalesce(sum(greatest(coalesce((e->>'w')::numeric, 1), 0)), 0)
        into w_total from jsonb_array_elements(eff) e;
      if w_total <= 0 then
        v_rig_d := floor(random() * n_opts)::integer;
      else
        w_roll := random() * w_total;
        w_acc  := 0;
        v_rig_d := n_opts - 1;              -- fallback for float edge cases
        for i in 0 .. n_opts - 1 loop
          w_acc := w_acc + greatest(coalesce((eff->i->>'w')::numeric, 1), 0);
          if w_roll < w_acc then
            v_rig_d := i;
            exit;
          end if;
        end loop;
      end if;
      v_rig_c := (array[1,2,2,3,3,3,4,4,5,5])[1 + floor(random() * 10)::integer];
    end if;
    v_rig_t := eff -> v_rig_d ->> 't';
    v_rig_f := coalesce((eff -> v_rig_d ->> 'free')::boolean, false);
  end if;

  insert into public.stag_guesses (team, bar, correct, mult, banana_by,
                                   rig_drink, rig_count, rig_text, rig_free,
                                   rig_opts, rigged)
    values (p_team, p_bar, is_correct, v_mult,
            case when coalesce(array_length(attackers, 1), 0) > 0 then attackers end,
            v_rig_d, v_rig_c, v_rig_t, coalesce(v_rig_f, false), eff, v_rigged);

  -- finding him no longer ends the game; it ends when every team has
  if is_correct then
    select count(distinct team) into finders
      from public.stag_guesses where correct;
    if finders >= 3 then
      update public.stag_game set status = 'revealed', updated_at = now() where id = 1;
    end if;
  end if;

  return json_build_object(
    'result',           case when is_correct then 'correct' else 'wrong' end,
    'mult',             v_mult,
    'by',               case when coalesce(array_length(attackers, 1), 0) > 0 then attackers end,
    'rig_d',            v_rig_d,
    'rig_c',            v_rig_c,
    'rig_t',            v_rig_t,
    'rig_f',            v_rig_f,
    'rig_opts',         eff,
    'server_now',       now(),
    'cooldown_seconds', g.cooldown_seconds);
end;
$$;

-- ----------------------------------------------------------------- banana ---

create or replace function public.stag_banana(p_team text, p_bar text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  g        public.stag_game;
  n        integer;
  been     boolean;
  existing public.stag_bananas;
begin
  if p_team not in ('ALPHA', 'BRAVO', 'CHARLIE') then
    return json_build_object('result', 'error', 'message', 'Unknown team');
  end if;
  if not public.stag_valid_bar(p_bar) then
    return json_build_object('result', 'error', 'message', 'Unknown bar');
  end if;

  select * into g from public.stag_game where id = 1 for update;

  select * into existing
    from public.stag_bananas where team = p_team and bar = p_bar;
  if found then
    select count(*) into n from public.stag_bananas where team = p_team;
    return json_build_object('result', 'ok', 'replay', true,
                             'left', 3 - n, 'server_now', now());
  end if;

  if g.status <> 'running' then
    return json_build_object('result', 'error', 'message', 'Game is over');
  end if;

  select exists(select 1 from public.stag_guesses
                 where team = p_team and bar = p_bar) into been;
  if not been then
    return json_build_object('result', 'error',
                             'message', 'You can only trap a bar you have already been to');
  end if;

  select count(*) into n from public.stag_bananas where team = p_team;
  if n >= 3 then
    return json_build_object('result', 'error', 'message', 'No bananas left');
  end if;

  insert into public.stag_bananas (team, bar) values (p_team, p_bar);

  return json_build_object('result', 'ok', 'left', 3 - (n + 1), 'server_now', now());
end;
$$;

-- ------------------------------------------------------------------ photo ---

create or replace function public.stag_photo(p_team text, p_bar text, p_path text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  been boolean;
begin
  if p_team not in ('ALPHA', 'BRAVO', 'CHARLIE') then
    return json_build_object('result', 'error', 'message', 'Unknown team');
  end if;
  select exists(select 1 from public.stag_guesses
                 where team = p_team and bar = p_bar) into been;
  if not been then
    return json_build_object('result', 'error', 'message', 'No guess at that bar');
  end if;
  insert into public.stag_photos (team, bar, path)
    values (p_team, p_bar, p_path)
    on conflict (team, bar) do update set path = excluded.path, created_at = now();
  return json_build_object('result', 'ok', 'server_now', now());
end;
$$;

-- ------------------------------------------------------------------ admin ---

create or replace function public.stag_admin(p_pass   text,
                                             p_action text default 'read',
                                             p_value  text default null)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  g     public.stag_game;
  v_bar text;
  v_js  text;
begin
  select * into g from public.stag_game where id = 1;

  if p_pass is distinct from g.admin_pass then
    perform pg_sleep(0.5);  -- take the edge off brute forcing
    return json_build_object('ok', false, 'message', 'Wrong passphrase');
  end if;

  if p_action = 'set_target' then
    update public.stag_game set target_bar = nullif(p_value, ''), updated_at = now() where id = 1;
  elsif p_action = 'set_cooldown' then
    update public.stag_game
       set cooldown_seconds = greatest(0, p_value::integer), updated_at = now()
     where id = 1;
  elsif p_action = 'set_hint' then
    update public.stag_game set hint_text = nullif(p_value, ''), updated_at = now() where id = 1;
  elsif p_action = 'set_hint_after' then
    update public.stag_game
       set hint_after = greatest(1, p_value::integer), updated_at = now()
     where id = 1;
  elsif p_action = 'set_wheel' then
    update public.stag_game set wheel_enabled = (p_value = 'true'), updated_at = now() where id = 1;

  elsif p_action = 'set_wheel_options' then
    begin
      if public.stag_valid_wheel(p_value::jsonb) then
        update public.stag_game
           set wheel_options = p_value::jsonb, updated_at = now()
         where id = 1;
      end if;
    exception when others then null;   -- malformed JSON: ignore rather than 500
    end;

  elsif p_action = 'set_pub_wheel' then
    -- value: '<bar>|<json array>'
    begin
      v_bar := split_part(p_value, '|', 1);
      v_js  := substr(p_value, length(v_bar) + 2);
      if public.stag_valid_bar(v_bar) and public.stag_valid_wheel(v_js::jsonb) then
        insert into public.stag_pub_wheels (bar, options)
          values (v_bar, v_js::jsonb)
          on conflict (bar) do update
            set options = excluded.options, updated_at = now();
      end if;
    exception when others then null;
    end;

  elsif p_action = 'clear_pub_wheel' then
    delete from public.stag_pub_wheels where bar = p_value;

  elsif p_action = 'set_rivals' then
    update public.stag_game set show_rivals = (p_value = 'true'), updated_at = now() where id = 1;

  elsif p_action = 'unlock' then
    insert into public.stag_unlock (team, waived_at) values (p_value, now())
      on conflict (team) do update set waived_at = now();

  elsif p_action = 'set_rig' then
    -- value: 'TEAM|segment index|count'
    if split_part(p_value, '|', 1) in ('ALPHA', 'BRAVO', 'CHARLIE') then
      insert into public.stag_rig (team, drink_idx, drink_count, drink_text)
        values (split_part(p_value, '|', 1),
                greatest(0, split_part(p_value, '|', 2)::integer),
                least(5, greatest(1, split_part(p_value, '|', 3)::integer)),
                g.wheel_options -> greatest(0, split_part(p_value, '|', 2)::integer) ->> 't')
        on conflict (team) do update
          set drink_idx = excluded.drink_idx,
              drink_count = excluded.drink_count,
              drink_text = excluded.drink_text,
              created_at = now();
    end if;

  elsif p_action = 'clear_rig' then
    delete from public.stag_rig where team = p_value;

  elsif p_action = 'end_game' then
    update public.stag_game set status = 'revealed', updated_at = now() where id = 1;

  elsif p_action = 'reset' then
    -- "where true" is required: Supabase enables pg-safeupdate, which rejects
    -- an unqualified DELETE. Wheels and pub overrides deliberately survive.
    delete from public.stag_guesses where true;
    delete from public.stag_unlock  where true;
    delete from public.stag_bananas where true;
    delete from public.stag_photos  where true;
    delete from public.stag_rig     where true;
    update public.stag_game
       set status = 'running', winning_team = null, won_at = null, updated_at = now()
     where id = 1;

  elsif p_action = 'set_pass' then
    update public.stag_game set admin_pass = p_value where id = 1;
  end if;

  select * into g from public.stag_game where id = 1;

  return json_build_object(
    'ok',         true,
    'server_now', now(),
    'game', json_build_object(
      'target_bar',       g.target_bar,
      'status',           g.status,
      'cooldown_seconds', g.cooldown_seconds,
      'hint_text',        g.hint_text,
      'hint_after',       g.hint_after,
      'wheel_enabled',    g.wheel_enabled,
      'wheel_options',    g.wheel_options,
      'show_rivals',      g.show_rivals),
    'pub_wheels', coalesce((
      select jsonb_object_agg(bar, options) from public.stag_pub_wheels), '{}'::jsonb),
    'scores', coalesce((
      select json_object_agg(team, pts)
      from (select team, sum(case when correct then 5 else mult end) pts
            from public.stag_guesses group by team) s), '{}'::json),
    'found', coalesce((
      select json_object_agg(team, created_at)
      from public.stag_guesses where correct), '{}'::json),
    'counts', coalesce((
      select json_object_agg(team, n)
      from (select team, count(*) n from public.stag_guesses group by team) t), '{}'::json),
    'unlocks', coalesce((
      select json_object_agg(team, waived_at) from public.stag_unlock), '{}'::json),
    'rigs', coalesce((
      select json_object_agg(team, json_build_object('d', drink_idx, 'c', drink_count,
                                                     't', drink_text))
      from public.stag_rig), '{}'::json),
    'bananas', coalesce((
      select json_agg(json_build_object('team', team, 'bar', bar, 'at', created_at)
             order by created_at)
      from public.stag_bananas), '[]'::json),
    'guesses', coalesce((
      select json_agg(json_build_object(
               'team', gg.team, 'bar', gg.bar, 'correct', gg.correct, 'at', gg.created_at,
               'mult', gg.mult, 'by', gg.banana_by,
               'rig_d', gg.rig_drink, 'rig_c', gg.rig_count,
               'rig_t', gg.rig_text, 'rig_f', gg.rig_free, 'rigged', gg.rigged,
               'photo', (select path from public.stag_photos sp
                          where sp.team = gg.team and sp.bar = gg.bar))
             order by gg.created_at desc)
      from public.stag_guesses gg), '[]'::json));
end;
$$;

-- ----------------------------------------------------------------- grants ---

revoke all on function public.stag_valid_bar(text)            from public;
revoke all on function public.stag_valid_wheel(jsonb)         from public;
revoke all on function public.stag_state(text)                from public;
revoke all on function public.stag_guess(text, text)          from public;
revoke all on function public.stag_banana(text, text)         from public;
revoke all on function public.stag_photo(text, text, text)    from public;
revoke all on function public.stag_admin(text, text, text)    from public;

grant execute on function public.stag_valid_bar(text)         to anon, authenticated;
grant execute on function public.stag_valid_wheel(jsonb)      to anon, authenticated;
grant execute on function public.stag_state(text)             to anon, authenticated;
grant execute on function public.stag_guess(text, text)       to anon, authenticated;
grant execute on function public.stag_banana(text, text)      to anon, authenticated;
grant execute on function public.stag_photo(text, text, text) to anon, authenticated;
grant execute on function public.stag_admin(text, text, text) to anon, authenticated;
