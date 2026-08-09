do $$
declare
  r record;
begin
  for r in
    select g.id as game_id, g.name, g.status, g.join_code, gp.id as player_id,
           gp.display_name, gp.status as player_status, gp.profile_id, gp.joined_at
    from games g
    left join game_players gp on gp.game_id = g.id
    order by g.created_at desc, gp.joined_at desc
    limit 30
  loop
    raise notice 'GAME: % (id=%, status=%, code=%) | PLAYER: % status=% profile_id=% joined=%',
      r.name, r.game_id, r.status, r.join_code, r.display_name, r.player_status, r.profile_id, r.joined_at;
  end loop;
end $$;
