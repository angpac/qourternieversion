-- Nothing was actually registered for Supabase Realtime, so every "live"
-- update seen so far came from the app re-fetching on view mount/navigation,
-- not genuine push — e.g. the admin dashboard staying on Queue (0) after a
-- guest joined until it was reopened. Add every table both dashboards
-- subscribe to.
alter publication supabase_realtime add table games, courts, game_players, matches, match_players;
