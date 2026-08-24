-- Lets a player swipe-delete an ended game off their OWN "My games" list
-- without touching the shared game itself — the game, its roster, and its
-- history stay intact for the admin and every other player. Distinct from
-- `status = 'removed'` (leaving the game), which is a different, already
-- user-visible state (moves the game to the player's own Ended section
-- rather than dropping it from their list entirely).

alter table game_players add column hidden_at timestamptz;

-- No new RLS policy needed: "players update own row" (init schema) already
-- lets a player update any column on their own game_players row via
-- `profile_id = auth.uid()`, hidden_at included.
