-- tournaments/tournament_matches have existed since the start (referenced
-- by rotation_format's tournament_single_elim/tournament_double_elim
-- values) but, like several other tables this session, were enabled for
-- RLS with zero policies defined — locked out for everyone until now.
create policy "admins manage tournaments"
  on tournaments for all
  using (is_game_admin(game_id))
  with check (is_game_admin(game_id));

create policy "players read tournaments"
  on tournaments for select
  using (is_game_player(game_id));

create policy "admins manage tournament matches"
  on tournament_matches for all
  using (is_game_admin((select game_id from tournaments where id = tournament_id)))
  with check (is_game_admin((select game_id from tournaments where id = tournament_id)));

create policy "players read tournament matches"
  on tournament_matches for select
  using (is_game_player((select game_id from tournaments where id = tournament_id)));

-- Bracket routing needs somewhere to hold "who's playing this match" before
-- the match itself exists — a not-yet-started tournament_matches row has no
-- `matches`/`match_players` rows yet, so the participants (seeded in round
-- 1, or advanced from a feeder match in later rounds) live here instead.
alter table tournament_matches add column team_a_player_ids uuid[];
alter table tournament_matches add column team_b_player_ids uuid[];

-- Which side of next_match_id the winner fills in — without this, two
-- different feeder matches advancing into the same next match would have
-- no deterministic way to avoid overwriting each other's slot.
alter table tournament_matches add column advances_to_slot text check (advances_to_slot in ('a', 'b'));

-- Double elimination only: where the LOSER of this match goes. Null means
-- losing here eliminates the player/team (true for every single-elim
-- match, and for the losers-bracket in double-elim).
alter table tournament_matches add column loser_next_match_id uuid references tournament_matches (id);
alter table tournament_matches add column loser_advances_to_slot text check (loser_advances_to_slot in ('a', 'b'));

alter publication supabase_realtime add table tournaments, tournament_matches;
