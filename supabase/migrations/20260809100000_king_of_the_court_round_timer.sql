-- King of the Court uses one shared round timer across every court, not a
-- per-match timer ("A timer runs each round... when time runs out, the
-- winner on each court moves up one court, and the loser moves down one
-- court"). Tracking the current round's start time on the game itself is
-- enough to derive a countdown (round_minutes lives in format_settings).
alter table games add column current_round_started_at timestamptz;
