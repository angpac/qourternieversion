-- Challenge Court: one physical court where the winning team keeps
-- defending against new challengers pulled from the queue, until they hit
-- the win cap (2 or 3 in a row) and step off even if still winning.
-- is_challenge_court marks which physical court this is (the first court
-- created for a Challenge Court game, by convention — matches the existing
-- is_lane_split convention for Half-Court Kingminton); win_streak tracks
-- the current defender's consecutive wins.
alter table courts add column is_challenge_court boolean not null default false;
alter table courts add column win_streak int not null default 0;
