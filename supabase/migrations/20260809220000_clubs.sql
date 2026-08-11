-- Clubs sit above games, optionally — a solo admin running a one-off
-- pickup session never touches this table. A club owner (or anyone on its
-- admin list) automatically administers every game linked to that club,
-- with no need to add them to each game's own game_admins individually —
-- is_game_admin() below is what makes that inheritance automatic.
--
-- `sports` is an array, not a single value, because a club can run more
-- than one sport (e.g. badminton nights and pickleball nights under the
-- same club) — this is also the seed for eventually making the app
-- multi-sport rather than badminton-only.
create table clubs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles (id) on delete cascade,
  name text not null,
  sports text[] not null default '{}',
  created_at timestamptz not null default now()
);

create index clubs_owner_id_idx on clubs (owner_id);

-- club-level co-admins, same shape as game_admins
create table club_admins (
  club_id uuid not null references clubs (id) on delete cascade,
  profile_id uuid not null references profiles (id) on delete cascade,
  added_at timestamptz not null default now(),
  primary key (club_id, profile_id)
);

-- Nullable: a game only belongs to a club if its admin chose to link it.
alter table games add column club_id uuid references clubs (id) on delete set null;
create index games_club_id_idx on games (club_id);

alter table clubs enable row level security;
alter table club_admins enable row level security;

-- Direct column check (not a subquery through a function) so INSERT ...
-- RETURNING can see the row it just created — the same fix already
-- applied to "owners select their games" earlier this session; a
-- self-referential subquery can't see a row still being inserted.
create policy "owners select their clubs"
  on clubs for select
  using (owner_id = auth.uid());

create policy "owners update their clubs"
  on clubs for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "owners delete their clubs"
  on clubs for delete
  using (owner_id = auth.uid());

create policy "owners insert their clubs"
  on clubs for insert
  with check (owner_id = auth.uid());

-- helper: is this user an admin (owner or co-admin) of the club?
create or replace function is_club_admin(c_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from clubs where id = c_id and owner_id = auth.uid()
    union
    select 1 from club_admins where club_id = c_id and profile_id = auth.uid()
  );
$$;

create policy "club admins select their clubs"
  on clubs for select
  using (is_club_admin(id));

create policy "club admins manage club admins"
  on club_admins for all
  using (is_club_admin(club_id))
  with check (is_club_admin(club_id));

-- Now the actual inheritance: a game's admin set is the union of its own
-- owner/game_admins AND (if it's linked to a club) that club's
-- owner/club_admins. Adding someone to club_admins once makes them an
-- admin of every current and future game under that club automatically.
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
    union
    select 1 from games g join clubs c on c.id = g.club_id
      where g.id = g_id and c.owner_id = auth.uid()
    union
    select 1 from games g join club_admins ca on ca.club_id = g.club_id
      where g.id = g_id and ca.profile_id = auth.uid()
  );
$$;
