-- Root cause of the persistent "new row violates row-level security policy
-- for table games" on every insert: PostgREST's insert always chains
-- .select() to return the created row, which compiles to INSERT ... RETURNING.
-- Postgres enforces the SELECT policy against that row before returning it,
-- and "admins select their games" checks is_game_admin(id), which runs its
-- own subquery against games — but a statement can never see rows it is
-- itself still inserting (standard command-visibility rule), so that
-- subquery always finds nothing for a brand new row and the whole insert
-- aborts, even though the insert's own WITH CHECK already passed.
--
-- Fix: add a SELECT policy that checks owner_id = auth.uid() directly
-- against the row's own column value (no subquery), which is visible
-- immediately, so RETURNING succeeds right after an owner's own insert.
create policy "owners select their games"
  on games for select
  using (owner_id = auth.uid());
