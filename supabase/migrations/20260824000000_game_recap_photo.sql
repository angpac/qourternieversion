-- Recap photo: one photo per game, posted by an admin/co-admin as "evidence
-- for the day," visible read-only to everyone connected to that game.
-- Storage, not a base64 column — Postgres row size and PostgREST payload
-- limits aren't meant for images.

alter table games add column recap_photo_url text;

insert into storage.buckets (id, name, public)
values ('game-recaps', 'game-recaps', true)
on conflict (id) do nothing;

-- Object path convention: <game_id>/<filename>. Checking is_game_admin()
-- against the first path segment means no separate lookup table is needed —
-- the same helper already used everywhere else on the games/game_admins
-- relationship (see is_game_admin() in the initial schema migration).
create policy "game admins upload recap photos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'game-recaps'
    and is_game_admin((storage.foldername(name))[1]::uuid)
  );

create policy "game admins replace recap photos"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'game-recaps'
    and is_game_admin((storage.foldername(name))[1]::uuid)
  )
  with check (
    bucket_id = 'game-recaps'
    and is_game_admin((storage.foldername(name))[1]::uuid)
  );

-- Public bucket: the photo is low-sensitivity "evidence for the day," not
-- account data, and the web guest client (no auth at all) is the same
-- reason every other guest-visible read in this app goes through a public
-- or RPC-mediated path rather than requiring a Supabase session.
create policy "anyone can view recap photos"
  on storage.objects for select
  using (bucket_id = 'game-recaps');

-- No new policy needed on games.recap_photo_url itself — the existing
-- "admins update their games" policy (is_game_admin(id)) already covers
-- every column, this one included.
