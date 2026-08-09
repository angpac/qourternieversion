-- Replace the single "FOR ALL" admin policy plus a separate "FOR INSERT"
-- owner policy (which should combine via OR per Postgres RLS semantics, but
-- reliably failed on device and in a direct SQL repro under the exact same
-- authenticated JWT claims) with explicit per-command policies. This removes
-- any ambiguity about how a FOR ALL policy and a same-command FOR INSERT
-- policy interact, and keeps insert authorization dead simple: an owner can
-- always insert a game for themselves.

drop policy if exists "admins manage their games" on games;
drop policy if exists "owners create their games" on games;

create policy "owners insert their games"
  on games for insert
  with check (owner_id = auth.uid());

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
