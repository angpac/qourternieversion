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
  requires_approval boolean not null default false,
  max_players int,
  rules_message text,
  status game_status not null default 'draft',
  created_at timestamptz not null default now()
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
  is_lane_split boolean not null default false -- Half-Court Kingminton
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

-- games: admins manage their own; joined players can read
create policy "admins manage their games"
  on games for all
  using (is_game_admin(id))
  with check (is_game_admin(id));

create policy "players read joined games"
  on games for select
  using (is_game_player(id));

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

-- Note: web guests are not Supabase-authenticated users, so they
-- can't be granted RLS access via auth.uid(). Serve their reads and
-- writes (join, self-report, and push_subscriptions insert) through
-- a Supabase Edge Function that validates the game's join_code +
-- session_token server-side, then uses the service role key to
-- read/write on their behalf.

alter table push_subscriptions enable row level security;

-- push_subscriptions has no direct client access at all: guests write
-- to it only through the same session-token-validated Edge Function
-- above, and admins never need to read raw subscription rows. The
-- Edge Function that SENDS the push (on a court-assignment or timer
-- event) reads this table using the service role key, which bypasses
-- RLS by design — no policy is needed for that path.
