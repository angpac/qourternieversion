-- ============================================================
-- Qourt — starter Postgres schema for Supabase
-- Covers: profiles, games, courts, roster/queue, matches,
-- tournaments/brackets, web guests, and row-level security
-- so each admin's games stay fully isolated (per PRD assumption).
-- ============================================================

-- ---------- enums ----------

create type rotation_format as enum (
  'king_of_the_court',
  'peg_board',
  'four_off_four_on',
  'challenge_court',
  'half_court_kingminton',
  'tournament_single_elim',
  'tournament_double_elim'
);

create type player_status as enum (
  'pending',
  'queued',
  'on_court',
  'resting',
  'removed'
);

create type match_status as enum (
  'in_progress',
  'awaiting_confirmation',
  'confirmed',
  'cancelled'
);

create type game_status as enum (
  'draft',
  'live',
  'paused',
  'ended'
);

-- ---------- profiles ----------
-- extends Supabase's built-in auth.users (populated on Sign In with Apple)

create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  default_skill_level text default 'Beginner',
  watch_paired boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------- games ----------

create table games (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles (id) on delete cascade,
  name text not null,
  location text,
  starts_at timestamptz,
  num_courts int not null default 1,
  is_doubles boolean not null default true,
  format rotation_format not null,
  format_settings jsonb not null default '{}',  -- round length, point cap, win cap, bracket size, etc.
  join_code text not null unique,
  -- A co-admin invite is a separate code from join_code, so sharing one
  -- never accidentally lets someone in as a co-admin instead of a player.
  admin_invite_code text unique,
  requires_approval boolean not null default false,
  max_players int,
  rules_message text,
  status game_status not null default 'draft',
  created_at timestamptz not null default now(),
  -- King of the Court uses one shared round timer across every court, not
  -- a per-match timer; round_minutes lives in format_settings.
  current_round_started_at timestamptz,
  -- Lets an admin tidy up My Games without losing anything — archiving
  -- only hides a game from the default list; the game, its roster,
  -- matches, and Game Summary stats are untouched and still reachable.
  archived boolean not null default false
);

create index games_owner_id_idx on games (owner_id);
create index games_join_code_idx on games (join_code);

-- co-admins: lets more than one profile manage the same game
create table game_admins (
  game_id uuid not null references games (id) on delete cascade,
  profile_id uuid not null references profiles (id) on delete cascade,
  added_at timestamptz not null default now(),
  primary key (game_id, profile_id)
);

-- ---------- courts ----------

create table courts (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references games (id) on delete cascade,
  name text not null,
  position int not null default 0,   -- for King of the Court ranking, lane order, etc.
  is_lane_split boolean not null default false, -- Half-Court Kingminton
  -- Challenge Court: which physical court is the challenge court (the first
  -- court created for a Challenge Court game, by convention), and the
  -- current defender's consecutive-win streak on it.
  is_challenge_court boolean not null default false,
  win_streak int not null default 0
);

create index courts_game_id_idx on courts (game_id);

-- ---------- roster / queue ----------

create table game_players (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references games (id) on delete cascade,
  profile_id uuid references profiles (id) on delete set null, -- null for walk-ins added by hand
  display_name text not null,        -- copied in case profile_id is null
  skill_level text not null default 'Beginner',
  status player_status not null default 'queued',
  queue_position int,
  joined_at timestamptz not null default now(),
  unique (game_id, profile_id)
);

create index game_players_game_id_idx on game_players (game_id);
create index game_players_status_idx on game_players (game_id, status);

-- ---------- push subscriptions (Web Push, for browser/web guests) ----------
-- One row per subscribed browser. A guest can have more than one (phone + laptop),
-- and a signed-in player could also subscribe from a browser session, not just APNs.
-- iOS Safari only allows this once the guest has added the page to their Home Screen;
-- everyone else (desktop, Android Chrome) can subscribe straight from the open tab.

create table push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  game_player_id uuid not null references game_players (id) on delete cascade,
  endpoint text not null unique,       -- browser's push service URL
  p256dh_key text not null,            -- subscription public key
  auth_key text not null,              -- subscription auth secret
  user_agent text,                     -- for debugging/cleanup of dead subscriptions
  created_at timestamptz not null default now()
);

create index push_subscriptions_game_player_id_idx on push_subscriptions (game_player_id);

-- APNs device tokens for the iPhone app and Watch companion. One row per
-- device — a player signed in on their phone AND wearing the Watch gets
-- two rows, both under the same profile.
create table apns_device_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles (id) on delete cascade,
  device_token text not null unique,
  platform text not null check (platform in ('ios', 'watchos')),
  created_at timestamptz not null default now()
);

create index apns_device_tokens_profile_id_idx on apns_device_tokens (profile_id);

-- ---------- web guests ----------
-- players without the app or an account; scoped to one game + browser session

create table web_guests (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references games (id) on delete cascade,
  game_player_id uuid not null references game_players (id) on delete cascade,
  session_token text not null unique, -- stored in the guest's browser
  created_at timestamptz not null default now()
);

-- ---------- matches ----------

create table matches (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references games (id) on delete cascade,
  court_id uuid references courts (id) on delete set null,
  status match_status not null default 'in_progress',
  score_a int,
  score_b int,
  reported_by uuid references profiles (id),
  confirmed_by uuid references profiles (id),
  started_at timestamptz not null default now(),
  ended_at timestamptz
);

create index matches_game_id_idx on matches (game_id);
create index matches_court_id_idx on matches (court_id);

create table match_players (
  match_id uuid not null references matches (id) on delete cascade,
  game_player_id uuid not null references game_players (id) on delete cascade,
  team text not null check (team in ('a', 'b')),
  primary key (match_id, game_player_id)
);

-- ---------- tournaments / brackets ----------

create table tournaments (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references games (id) on delete cascade,
  bracket_size int not null,
  elimination_type text not null check (elimination_type in ('single', 'double')),
  seeding_method text not null default 'skill' check (seeding_method in ('skill', 'random', 'manual')),
  created_at timestamptz not null default now()
);

create table tournament_matches (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references tournaments (id) on delete cascade,
  match_id uuid references matches (id) on delete set null,
  bracket text not null default 'winners' check (bracket in ('winners', 'losers', 'final')),
  round int not null,
  slot int not null,             -- position within the round
  next_match_id uuid references tournament_matches (id), -- where the winner advances to
  -- Bracket routing needs somewhere to hold "who's playing this match"
  -- before the match itself exists — a not-yet-started row has no
  -- matches/match_players rows yet, so participants (seeded in round 1, or
  -- advanced from a feeder match) live here instead.
  team_a_player_ids uuid[],
  team_b_player_ids uuid[],
  -- Which side of next_match_id the winner fills — without this, two
  -- different feeder matches advancing into the same next match would have
  -- no deterministic way to avoid overwriting each other's slot.
  advances_to_slot text check (advances_to_slot in ('a', 'b')),
  -- Double elimination only: where the LOSER of this match goes. Null
  -- means losing here eliminates the player/team (true for every
  -- single-elim match, and for the losers-bracket in double-elim).
  loser_next_match_id uuid references tournament_matches (id),
  loser_advances_to_slot text check (loser_advances_to_slot in ('a', 'b')),
  created_at timestamptz not null default now()
);

create index tournament_matches_tournament_id_idx on tournament_matches (tournament_id);

-- ---------- announcements ----------

create table announcements (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references games (id) on delete cascade,
  sender_id uuid not null references profiles (id),
  target_player_id uuid references game_players (id), -- null = everyone
  message text not null,
  sent_at timestamptz not null default now()
);

-- ============================================================
-- Row Level Security
-- Goal: an admin only ever sees/edits their own games (or ones
-- they co-admin), and players only see games they've joined.
-- ============================================================

alter table games enable row level security;
alter table game_admins enable row level security;
alter table courts enable row level security;
alter table game_players enable row level security;
alter table matches enable row level security;
alter table match_players enable row level security;
alter table tournaments enable row level security;
alter table tournament_matches enable row level security;
alter table announcements enable row level security;

-- helper: is this user an admin (owner or co-admin) of the game?
create or replace function is_game_admin(g_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from games where id = g_id and owner_id = auth.uid()
    union
    select 1 from game_admins where game_id = g_id and profile_id = auth.uid()
  );
$$;

-- helper: has this user joined the game as a player?
create or replace function is_game_player(g_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from game_players where game_id = g_id and profile_id = auth.uid()
  );
$$;

-- games: admins manage their own (per command, not a single FOR ALL policy —
-- a FOR ALL policy combined with a separate same-command FOR INSERT policy
-- reliably rejected inserts in testing despite matching Postgres's documented
-- OR-combination semantics, so each command gets its own explicit policy).
create policy "owners insert their games"
  on games for insert
  with check (owner_id = auth.uid());

-- A client's insert() is typically chained with .select() to get the created
-- row back, which compiles to INSERT ... RETURNING. Postgres enforces a
-- SELECT policy against that row before returning it, and is_game_admin(id)
-- runs its own subquery against games — but a statement can never see rows
-- it is itself still inserting (standard command-visibility rule), so that
-- subquery always finds nothing for a brand new row and the whole insert
-- aborts even though its own WITH CHECK already passed. This policy checks
-- owner_id = auth.uid() directly against the row's own column value instead
-- of re-querying the table, so it's visible immediately on insert.
create policy "owners select their games"
  on games for select
  using (owner_id = auth.uid());

create policy "admins select their games"
  on games for select
  using (is_game_admin(id));

create policy "admins update their games"
  on games for update
  using (is_game_admin(id))
  with check (is_game_admin(id));

create policy "admins delete their games"
  on games for delete
  using (is_game_admin(id));

create policy "players read joined games"
  on games for select
  using (is_game_player(id));

create policy "admins manage tournaments"
  on tournaments for all
  using (is_game_admin(game_id))
  with check (is_game_admin(game_id));

create policy "players read tournaments"
  on tournaments for select
  using (is_game_player(game_id));

create policy "admins manage tournament matches"
  on tournament_matches for all
  using (is_game_admin((select game_id from tournaments where id = tournament_id)))
  with check (is_game_admin((select game_id from tournaments where id = tournament_id)));

create policy "players read tournament matches"
  on tournament_matches for select
  using (is_game_player((select game_id from tournaments where id = tournament_id)));

create policy "admins manage co-admins"
  on game_admins for all
  using (is_game_admin(game_id))
  with check (is_game_admin(game_id));

-- courts / game_players / matches / etc: admins full access,
-- joined players read-only. Repeat this pattern per table.
create policy "admins manage courts"
  on courts for all
  using (is_game_admin(game_id))
  with check (is_game_admin(game_id));

create policy "players read courts"
  on courts for select
  using (is_game_player(game_id));

create policy "admins manage roster"
  on game_players for all
  using (is_game_admin(game_id))
  with check (is_game_admin(game_id));

create policy "players read roster"
  on game_players for select
  using (is_game_player(game_id));

create policy "players update own row"
  on game_players for update
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

create policy "admins manage matches"
  on matches for all
  using (is_game_admin(game_id))
  with check (is_game_admin(game_id));

create policy "players read and self-report matches"
  on matches for select
  using (is_game_player(game_id));

create policy "players self-report score"
  on matches for update
  using (is_game_player(game_id))
  with check (is_game_player(game_id));

create policy "admins manage match players"
  on match_players for all
  using (is_game_admin((select game_id from matches where id = match_id)))
  with check (is_game_admin((select game_id from matches where id = match_id)));

create policy "players read match players"
  on match_players for select
  using (is_game_player((select game_id from matches where id = match_id)));

create policy "admins manage announcements"
  on announcements for all
  using (is_game_admin(game_id))
  with check (is_game_admin(game_id));

create policy "players read their announcements"
  on announcements for select
  using (
    is_game_player(game_id)
    and (
      target_player_id is null
      or target_player_id in (
        select id from game_players
        where game_id = announcements.game_id and profile_id = auth.uid()
      )
    )
  );

-- Note: web guests are not Supabase-authenticated users, so they
-- can't be granted RLS access via auth.uid(). Serve their reads and
-- writes (join, self-report, and push_subscriptions insert) through
-- a Supabase Edge Function that validates the game's join_code +
-- session_token server-side, then uses the service role key to
-- read/write on their behalf.

alter table push_subscriptions enable row level security;

-- push_subscriptions has no direct client access at all: guests write to
-- it only through guest_subscribe_push (a session-token-validated security
-- definer function, same pattern as every other guest_* function), and
-- admins never need to read raw subscription rows. The send-push Edge
-- Function reads this table using the service role key, which bypasses
-- RLS by design — no policy is needed for that path.

alter table apns_device_tokens enable row level security;

create policy "players manage own device tokens"
  on apns_device_tokens for all
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- ============================================================
-- Joining a game (signed-in app players)
-- ============================================================

-- A player can't SELECT a game via RLS until they've already joined it
-- (the "players read joined games" policy requires is_game_player(id)),
-- so looking a game up by its join code needs a security definer function
-- that can see the games table regardless, validate the code, and create
-- the game_players row atomically.
create or replace function public.join_game_by_code(
  p_join_code text,
  p_display_name text,
  p_skill_level text default 'Beginner'
)
returns games
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game games;
  v_existing game_players;
  -- Must be typed player_status, not text — Postgres only auto-coerces
  -- untyped string literals into an enum column, not a typed variable, so
  -- a plain `text` here fails on insert with "column is of type
  -- player_status but expression is of type text".
  v_status player_status;
begin
  select * into v_game from games where join_code = upper(p_join_code);

  if not found then
    raise exception 'No game found with that join code' using errcode = 'P0002';
  end if;

  -- Each game gets its own random join_code, and a saved link/QR/code from a
  -- past, now-ended game must not work for any future game, so joins are
  -- rejected outright once the game has ended.
  if v_game.status = 'ended' then
    raise exception 'This game has ended' using errcode = 'P0003';
  end if;

  if v_game.max_players is not null then
    if (select count(*) from game_players where game_id = v_game.id) >= v_game.max_players then
      raise exception 'This game is full' using errcode = 'P0001';
    end if;
  end if;

  select * into v_existing from game_players where game_id = v_game.id and profile_id = auth.uid();

  if not found then
    -- A game with requires_approval set puts new joiners in 'pending'
    -- (no queue position) until an admin approves them from the Roster.
    v_status := case when v_game.requires_approval then 'pending' else 'queued' end;

    insert into game_players (game_id, profile_id, display_name, skill_level, status, queue_position)
    values (
      v_game.id,
      auth.uid(),
      p_display_name,
      p_skill_level,
      v_status,
      case when v_status = 'queued'
        then (select coalesce(max(queue_position), -1) + 1 from game_players where game_id = v_game.id)
        else null
      end
    );
  end if;

  return v_game;
end;
$$;

grant execute on function public.join_game_by_code(text, text, text) to authenticated;

-- A public, read-only "peek" so the join screen can confirm the game's
-- actual name (not just its code) before someone fills out their name to
-- join — and so a scanned/typed code for an ended game fails fast instead
-- of only failing after the form is filled out. Safe to expose broadly:
-- it returns only what's already printed on the shared QR/invite anyway.
create or replace function public.game_preview_by_code(p_join_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game games;
begin
  select * into v_game from games where join_code = upper(p_join_code);

  if not found then
    raise exception 'No game found with that join code' using errcode = 'P0002';
  end if;

  return jsonb_build_object(
    'name', v_game.name,
    'status', v_game.status,
    'join_code', v_game.join_code
  );
end;
$$;

grant execute on function public.game_preview_by_code(text) to anon, authenticated;

-- Redeeming a co-admin invite has to be security definer because, before
-- the insert, the redeemer isn't an admin of the game yet, so "admins
-- manage co-admins" (which checks is_game_admin) would otherwise block the
-- very row that makes them one.
create or replace function public.redeem_admin_invite(p_invite_code text)
returns games
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game games;
begin
  select * into v_game from games where admin_invite_code = upper(p_invite_code);

  if not found then
    raise exception 'No game found with that invite code' using errcode = 'P0002';
  end if;

  insert into game_admins (game_id, profile_id)
  values (v_game.id, auth.uid())
  on conflict (game_id, profile_id) do nothing;

  return v_game;
end;
$$;

grant execute on function public.redeem_admin_invite(text) to authenticated;

-- ============================================================
-- Joining a game (web guests, no account)
-- ============================================================

-- Web guests aren't Supabase-authenticated users, so RLS (which keys off
-- auth.uid()) can't cover them directly. Rather than opening up raw table
-- access to the anon role, guests interact only through these two security
-- definer functions, authorizing themselves with a random session token
-- instead of a Supabase session — matching the approach already called out
-- above for push_subscriptions.

create or replace function public.guest_join_game(
  p_join_code text,
  p_display_name text,
  p_skill_level text default 'Beginner'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game games;
  v_game_player_id uuid;
  v_session_token uuid;
  v_status player_status;
begin
  select * into v_game from games where join_code = upper(p_join_code);

  if not found then
    raise exception 'No game found with that join code' using errcode = 'P0002';
  end if;

  if v_game.status = 'ended' then
    raise exception 'This game has ended' using errcode = 'P0003';
  end if;

  if v_game.max_players is not null then
    if (select count(*) from game_players where game_id = v_game.id) >= v_game.max_players then
      raise exception 'This game is full' using errcode = 'P0001';
    end if;
  end if;

  v_status := case when v_game.requires_approval then 'pending' else 'queued' end;

  insert into game_players (game_id, profile_id, display_name, skill_level, status, queue_position)
  values (
    v_game.id,
    null,
    p_display_name,
    p_skill_level,
    v_status,
    case when v_status = 'queued'
      then (select coalesce(max(queue_position), -1) + 1 from game_players where game_id = v_game.id)
      else null
    end
  )
  returning id into v_game_player_id;

  v_session_token := gen_random_uuid();

  insert into web_guests (game_id, game_player_id, session_token)
  values (v_game.id, v_game_player_id, v_session_token::text);

  return jsonb_build_object(
    'session_token', v_session_token,
    'game_name', v_game.name,
    'game_format', v_game.format,
    'join_code', v_game.join_code
  );
end;
$$;

grant execute on function public.guest_join_game(text, text, text) to anon;

create or replace function public.guest_status(p_session_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guest web_guests;
  v_player game_players;
  v_game games;
  v_queue_position int;
  v_match matches;
  v_court courts;
  v_team_a jsonb;
  v_team_b jsonb;
  v_last_match_score_a int;
  v_last_match_score_b int;
  v_last_match_team text;
  v_is_picker boolean := false;
  v_picker_pool jsonb;
  v_pool_size int;
begin
  select * into v_guest from web_guests where session_token = p_session_token::text;
  if not found then
    raise exception 'Session not found' using errcode = 'P0002';
  end if;

  select * into v_player from game_players where id = v_guest.game_player_id;
  select * into v_game from games where id = v_guest.game_id;

  if v_player.status = 'queued' then
    select count(*) + 1 into v_queue_position
    from game_players
    where game_id = v_guest.game_id
      and status = 'queued'
      and (
        queue_position < v_player.queue_position
        or (queue_position is null and joined_at < v_player.joined_at)
      );

    -- Peg Board: whoever's at the front of the line is the Picker, and gets
    -- to see the next `picker_pool_size` players in line to build a match.
    if v_game.format = 'peg_board' and v_queue_position = 1 then
      v_is_picker := true;
      v_pool_size := coalesce((v_game.format_settings->>'picker_pool_size')::int, 10);

      select jsonb_agg(jsonb_build_object('id', gp.id, 'display_name', gp.display_name, 'skill_level', gp.skill_level))
        into v_picker_pool
        from (
          select gp.id, gp.display_name, gp.skill_level
          from game_players gp
          where gp.game_id = v_guest.game_id
            and gp.status = 'queued'
            and gp.id <> v_player.id
          order by gp.queue_position nulls last, gp.joined_at
          limit v_pool_size
        ) gp;
    end if;
  end if;

  if v_player.status = 'on_court' then
    select m.* into v_match
    from matches m
    join match_players mp on mp.match_id = m.id
    where mp.game_player_id = v_player.id
      and m.status in ('in_progress', 'awaiting_confirmation')
    order by m.started_at desc
    limit 1;

    if found then
      select c.* into v_court from courts c where c.id = v_match.court_id;

      select jsonb_agg(jsonb_build_object('id', gp.id, 'display_name', gp.display_name))
        into v_team_a
        from match_players mp join game_players gp on gp.id = mp.game_player_id
        where mp.match_id = v_match.id and mp.team = 'a';

      select jsonb_agg(jsonb_build_object('id', gp.id, 'display_name', gp.display_name))
        into v_team_b
        from match_players mp join game_players gp on gp.id = mp.game_player_id
        where mp.match_id = v_match.id and mp.team = 'b';
    end if;
  end if;

  select m.score_a, m.score_b, mp.team
    into v_last_match_score_a, v_last_match_score_b, v_last_match_team
  from matches m
  join match_players mp on mp.match_id = m.id
  where mp.game_player_id = v_player.id and m.status = 'confirmed'
  order by m.ended_at desc
  limit 1;

  return jsonb_build_object(
    'game_name', v_game.name,
    'game_format', v_game.format,
    'join_code', v_game.join_code,
    'player_status', v_player.status,
    'queue_position', v_queue_position,
    'court_name', v_court.name,
    'match_status', v_match.status,
    'score_a', v_match.score_a,
    'score_b', v_match.score_b,
    'team_a', v_team_a,
    'team_b', v_team_b,
    'last_match_score_a', v_last_match_score_a,
    'last_match_score_b', v_last_match_score_b,
    'last_match_my_team', v_last_match_team,
    'is_picker', v_is_picker,
    'picker_pool', v_picker_pool,
    'my_display_name', v_player.display_name,
    'my_skill_level', v_player.skill_level
  );
end;
$$;

grant execute on function public.guest_status(uuid) to anon;

-- Guest self-service actions (step out, step back in, leave, self-report),
-- mirroring what a signed-in app player can already do directly via RLS
-- ("players update own row" / "players self-report score").

create or replace function public.guest_step_out(p_session_token uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guest web_guests;
begin
  select * into v_guest from web_guests where session_token = p_session_token::text;
  if not found then
    raise exception 'Session not found' using errcode = 'P0002';
  end if;

  update game_players set status = 'resting' where id = v_guest.game_player_id;
end;
$$;

create or replace function public.guest_step_in(p_session_token uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guest web_guests;
  v_next_position int;
begin
  select * into v_guest from web_guests where session_token = p_session_token::text;
  if not found then
    raise exception 'Session not found' using errcode = 'P0002';
  end if;

  select coalesce(max(queue_position), -1) + 1 into v_next_position
  from game_players where game_id = v_guest.game_id;

  update game_players
  set status = 'queued', queue_position = v_next_position
  where id = v_guest.game_player_id;
end;
$$;

create or replace function public.guest_leave_game(p_session_token uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guest web_guests;
begin
  select * into v_guest from web_guests where session_token = p_session_token::text;
  if not found then
    raise exception 'Session not found' using errcode = 'P0002';
  end if;

  update game_players set status = 'removed' where id = v_guest.game_player_id;
end;
$$;

grant execute on function public.guest_step_out(uuid) to anon;
grant execute on function public.guest_step_in(uuid) to anon;
grant execute on function public.guest_leave_game(uuid) to anon;

-- Lets a web guest self-report their match score, mirroring the signed-in
-- app player's "players self-report score" RLS-backed update.
create or replace function public.guest_report_score(
  p_session_token uuid,
  p_score_a int,
  p_score_b int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guest web_guests;
  v_match_id uuid;
begin
  select * into v_guest from web_guests where session_token = p_session_token::text;
  if not found then
    raise exception 'Session not found' using errcode = 'P0002';
  end if;

  select m.id into v_match_id
  from matches m
  join match_players mp on mp.match_id = m.id
  where mp.game_player_id = v_guest.game_player_id
    and m.status = 'in_progress'
  order by m.started_at desc
  limit 1;

  if v_match_id is null then
    raise exception 'No in-progress match found' using errcode = 'P0002';
  end if;

  update matches
  set score_a = p_score_a, score_b = p_score_b, status = 'awaiting_confirmation'
  where id = v_match_id;
end;
$$;

grant execute on function public.guest_report_score(uuid, int, int) to anon;

-- Web guests read announcements through the same session-token pattern.
create or replace function public.guest_announcements(p_session_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guest web_guests;
  v_result jsonb;
begin
  select * into v_guest from web_guests where session_token = p_session_token::text;
  if not found then
    raise exception 'Session not found' using errcode = 'P0002';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id,
    'message', a.message,
    'sent_at', a.sent_at
  ) order by a.sent_at desc), '[]'::jsonb)
  into v_result
  from (
    select *
    from announcements
    where game_id = v_guest.game_id
      and (target_player_id is null or target_player_id = v_guest.game_player_id)
    order by sent_at desc
    limit 10
  ) a;

  return v_result;
end;
$$;

grant execute on function public.guest_announcements(uuid) to anon;

create or replace function public.guest_subscribe_push(
  p_session_token uuid,
  p_endpoint text,
  p_p256dh_key text,
  p_auth_key text,
  p_user_agent text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guest web_guests;
begin
  select * into v_guest from web_guests where session_token = p_session_token::text;
  if not found then
    raise exception 'Session not found' using errcode = 'P0002';
  end if;

  insert into push_subscriptions (game_player_id, endpoint, p256dh_key, auth_key, user_agent)
  values (v_guest.game_player_id, p_endpoint, p_p256dh_key, p_auth_key, p_user_agent)
  on conflict (endpoint) do update set
    game_player_id = excluded.game_player_id,
    p256dh_key = excluded.p256dh_key,
    auth_key = excluded.auth_key,
    user_agent = excluded.user_agent;
end;
$$;

grant execute on function public.guest_subscribe_push(uuid, text, text, text, text) to anon;

-- ============================================================
-- Peg Board / Racket Staking
-- ============================================================

-- The player at the front of the queue becomes the "Picker" and hand-picks
-- 3 others from the next players in line to build a doubles match. Unlike
-- every other format, this is a PLAYER action, not an admin one —
-- "players update own row" only covers a player's own game_players row,
-- not starting a match involving others, so this needs its own security
-- definer function that validates the caller really is the Picker right
-- now before doing anything.
create or replace function public.pick_board_start_match(
  p_game_id uuid,
  p_teammate_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_picker game_players;
  v_court courts;
  v_new_match_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not signed in' using errcode = 'P0002';
  end if;

  select * into v_picker from game_players
    where game_id = p_game_id and profile_id = auth.uid() and status = 'queued';
  if not found then
    raise exception 'You are not queued in this game' using errcode = 'P0002';
  end if;

  if exists (
    select 1 from game_players
    where game_id = p_game_id and status = 'queued'
      and (
        queue_position < v_picker.queue_position
        or (queue_position is null and joined_at < v_picker.joined_at)
      )
  ) then
    raise exception 'You are not the Picker right now' using errcode = 'P0003';
  end if;

  if array_length(p_teammate_ids, 1) is distinct from 3 then
    raise exception 'Pick exactly 3 teammates' using errcode = 'P0001';
  end if;

  if (
    select count(*) from game_players
    where id = any(p_teammate_ids) and game_id = p_game_id and status = 'queued'
  ) <> 3 then
    raise exception 'One of your picks is no longer available' using errcode = 'P0001';
  end if;

  select c.* into v_court
  from courts c
  where c.game_id = p_game_id
    and not exists (
      select 1 from matches m where m.court_id = c.id and m.status in ('in_progress', 'awaiting_confirmation')
    )
  order by c.position
  limit 1;

  if not found then
    raise exception 'No open court right now' using errcode = 'P0002';
  end if;

  insert into matches (game_id, court_id, status)
  values (p_game_id, v_court.id, 'in_progress')
  returning id into v_new_match_id;

  insert into match_players (match_id, game_player_id, team)
  values
    (v_new_match_id, v_picker.id, 'a'),
    (v_new_match_id, p_teammate_ids[1], 'a'),
    (v_new_match_id, p_teammate_ids[2], 'b'),
    (v_new_match_id, p_teammate_ids[3], 'b');

  update game_players set status = 'on_court'
  where id in (v_picker.id, p_teammate_ids[1], p_teammate_ids[2], p_teammate_ids[3]);

  return v_new_match_id;
end;
$$;

grant execute on function public.pick_board_start_match(uuid, uuid[]) to authenticated;

-- Same thing for web guests, session-token authorized instead of auth.uid().
create or replace function public.guest_pick_board_start_match(
  p_session_token uuid,
  p_teammate_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guest web_guests;
  v_picker game_players;
  v_court courts;
  v_new_match_id uuid;
begin
  select * into v_guest from web_guests where session_token = p_session_token::text;
  if not found then
    raise exception 'Session not found' using errcode = 'P0002';
  end if;

  select * into v_picker from game_players where id = v_guest.game_player_id and status = 'queued';
  if not found then
    raise exception 'You are not queued in this game' using errcode = 'P0002';
  end if;

  if exists (
    select 1 from game_players
    where game_id = v_guest.game_id and status = 'queued'
      and (
        queue_position < v_picker.queue_position
        or (queue_position is null and joined_at < v_picker.joined_at)
      )
  ) then
    raise exception 'You are not the Picker right now' using errcode = 'P0003';
  end if;

  if array_length(p_teammate_ids, 1) is distinct from 3 then
    raise exception 'Pick exactly 3 teammates' using errcode = 'P0001';
  end if;

  if (
    select count(*) from game_players
    where id = any(p_teammate_ids) and game_id = v_guest.game_id and status = 'queued'
  ) <> 3 then
    raise exception 'One of your picks is no longer available' using errcode = 'P0001';
  end if;

  select c.* into v_court
  from courts c
  where c.game_id = v_guest.game_id
    and not exists (
      select 1 from matches m where m.court_id = c.id and m.status in ('in_progress', 'awaiting_confirmation')
    )
  order by c.position
  limit 1;

  if not found then
    raise exception 'No open court right now' using errcode = 'P0002';
  end if;

  insert into matches (game_id, court_id, status)
  values (v_guest.game_id, v_court.id, 'in_progress')
  returning id into v_new_match_id;

  insert into match_players (match_id, game_player_id, team)
  values
    (v_new_match_id, v_picker.id, 'a'),
    (v_new_match_id, p_teammate_ids[1], 'a'),
    (v_new_match_id, p_teammate_ids[2], 'b'),
    (v_new_match_id, p_teammate_ids[3], 'b');

  update game_players set status = 'on_court'
  where id in (v_picker.id, p_teammate_ids[1], p_teammate_ids[2], p_teammate_ids[3]);

  return v_new_match_id;
end;
$$;

grant execute on function public.guest_pick_board_start_match(uuid, uuid[]) to anon;

-- ============================================================
-- Templates
-- ============================================================

-- Save a game's setup (courts, format, format settings, approval
-- requirement) to reuse next time, per PRD's Templates screen. Templates
-- are personal to the admin who saved them — not shared with co-admins —
-- so a simple owner-only policy is enough, no is_game_admin() needed.
create table game_templates (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles (id) on delete cascade,
  name text not null,
  num_courts int not null default 1,
  is_doubles boolean not null default true,
  requires_approval boolean not null default false,
  format rotation_format not null,
  format_settings jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index game_templates_owner_id_idx on game_templates (owner_id);

alter table game_templates enable row level security;

create policy "owners manage their templates"
  on game_templates for all
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- ============================================================
-- Realtime
-- ============================================================

-- Supabase does not auto-enable Realtime for new tables — a table only
-- streams postgres_changes to subscribed clients once it's added to this
-- publication. Without this, every dashboard silently falls back to
-- whatever it fetched at mount/navigation time.
alter publication supabase_realtime add table games, courts, game_players, matches, match_players, announcements, tournaments, tournament_matches;

-- ============================================================
-- Push notifications
-- ============================================================

-- Fires the send-push Edge Function on the two events that warrant a push:
-- a player gets assigned to a fresh match ("you're up!") and an admin sends
-- an announcement. The trigger authenticates its call with a random shared
-- secret (stored in Vault, also set as the Edge Function's own
-- PUSH_WEBHOOK_SECRET env var) rather than the project's service role key —
-- the function already holds its own service role key in its environment
-- for the privileged reads/sends it needs, so the trigger only needs to
-- prove the call really came from this database, not carry a key that
-- bypasses RLS entirely.
create extension if not exists pg_net with schema extensions;

-- One-time secret registration (real value set directly on the remote
-- project, not this file — see the 20260809140100 migration).
-- select vault.create_secret('<random hex>', 'push_webhook_secret');

create or replace function public.notify_send_push(p_payload jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_secret text;
begin
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'push_webhook_secret';

  perform net.http_post(
    url := 'https://izanyjrbgguidttflpvp.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', v_secret),
    body := p_payload
  );
end;
$$;

create or replace function public.trigger_push_on_match_assigned()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.notify_send_push(jsonb_build_object('type', 'match_assigned', 'match_player_id', new.id));
  return new;
end;
$$;

create trigger push_on_match_assigned
  after insert on match_players
  for each row execute function public.trigger_push_on_match_assigned();

create or replace function public.trigger_push_on_announcement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.notify_send_push(jsonb_build_object('type', 'announcement', 'announcement_id', new.id));
  return new;
end;
$$;

create trigger push_on_announcement
  after insert on announcements
  for each row execute function public.trigger_push_on_announcement();
