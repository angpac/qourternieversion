-- Belt-and-suspenders against the exact race that caused empty phantom
-- matches: two near-simultaneous auto-fill/start attempts could both see
-- a court as open before either write finished, and both insert a match
-- for it. App-level guards reduce this but can't fully close a
-- time-of-check-to-time-of-use race — a database constraint can. Only one
-- match can be in_progress/awaiting_confirmation per court at a time; a
-- second concurrent attempt now fails outright at the database instead of
-- silently creating a duplicate/empty match.
create unique index one_active_match_per_court
  on matches (court_id)
  where status in ('in_progress', 'awaiting_confirmation');
