-- match_players had row_security enabled with zero policies defined,
-- meaning default-deny blocked everyone, including game admins — a schema
-- oversight caught while wiring up starting a match from the dashboard.
create policy "admins manage match players"
  on match_players for all
  using (is_game_admin((select game_id from matches where id = match_id)))
  with check (is_game_admin((select game_id from matches where id = match_id)));

create policy "players read match players"
  on match_players for select
  using (is_game_player((select game_id from matches where id = match_id)));
