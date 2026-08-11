-- King of the Court: a short "get to your court" buffer after each
-- rotation, before the next round's timer actually starts counting down.
-- While this is set and in the future, the round timer hasn't started yet
-- (that only happens once it passes) — same one-timestamp approach as
-- current_round_started_at, so every device just watches a Date rather
-- than needing per-second sync.
alter table games add column prep_ends_at timestamptz;
