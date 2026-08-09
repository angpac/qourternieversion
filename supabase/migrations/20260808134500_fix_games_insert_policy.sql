-- games: a signed-in user can create a game they own. Split out from
-- "admins manage their games" because is_game_admin(id) looks up an
-- existing games row by id, which can't match yet on insert (the row
-- doesn't exist until this statement commits) — so that policy alone
-- always rejects inserts.
create policy "owners create their games"
  on games for insert
  with check (owner_id = auth.uid());
