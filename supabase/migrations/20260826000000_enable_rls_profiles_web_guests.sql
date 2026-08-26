-- profiles and web_guests were the only two tables in the schema that
-- never had row level security enabled — Supabase's default table grants
-- give anon *and* authenticated full select/insert/update/delete/truncate,
-- so with RLS off both roles had unrestricted access via the public anon
-- key (which is, by design, embedded in every client). Confirmed against
-- the live database before writing this: relrowsecurity was false on
-- both, and role_table_grants showed the full grant set to both roles.
--
-- profiles.id is what games.owner_id cascades from (`references
-- profiles (id) on delete cascade`), so this wasn't just "anyone can
-- rename anyone" — anyone holding the anon key could delete any user's
-- profile row and cascade-delete every game they own, or truncate the
-- whole table.
--
-- web_guests.session_token is the sole credential guest_status/
-- guest_report_score/etc. check before acting as a guest — reading the
-- table directly handed over every guest session on every game.

alter table profiles enable row level security;

-- Only ever queried by AuthViewModel for the signed-in user's own row
-- (upsert/select/update all `.eq("id", userID)`) — other players' names
-- are read from game_players.display_name, a separate denormalized
-- column, never from profiles directly. So "own row only" costs nothing
-- functionally.
create policy "profiles select own"
  on profiles for select
  using (auth.uid() = id);

create policy "profiles insert own"
  on profiles for insert
  with check (auth.uid() = id);

create policy "profiles update own"
  on profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- No delete policy: a profile disappears via auth.users' own cascade,
-- never by a user deleting their own row directly.

alter table web_guests enable row level security;

-- No policies at all, deliberately: every legitimate access already goes
-- through the guest_* RPCs (guest_status, guest_report_score,
-- guest_join_game, guest_leave_game, guest_step_in/out,
-- guest_pick_board_start_match, guest_announcements,
-- guest_subscribe_push), all SECURITY DEFINER — confirmed via
-- pg_proc.prosecdef before writing this — so they bypass RLS entirely
-- and are unaffected. This just closes the table off from being read or
-- written directly through the REST API.
