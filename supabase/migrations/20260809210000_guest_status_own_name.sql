-- Surface the guest's own name/skill level on their status screen, so an
-- admin can glance at a player's phone courtside to confirm who they are.
create or replace function public.guest_status(p_session_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guest web_guests;
  v_player game_players;
  v_game games;
  v_queue_position int;
  v_match matches;
  v_court courts;
  v_team_a jsonb;
  v_team_b jsonb;
  v_last_match_score_a int;
  v_last_match_score_b int;
  v_last_match_team text;
  v_is_picker boolean := false;
  v_picker_pool jsonb;
  v_pool_size int;
begin
  select * into v_guest from web_guests where session_token = p_session_token::text;
  if not found then
    raise exception 'Session not found' using errcode = 'P0002';
  end if;

  select * into v_player from game_players where id = v_guest.game_player_id;
  select * into v_game from games where id = v_guest.game_id;

  if v_player.status = 'queued' then
    select count(*) + 1 into v_queue_position
    from game_players
    where game_id = v_guest.game_id
      and status = 'queued'
      and (
        queue_position < v_player.queue_position
        or (queue_position is null and joined_at < v_player.joined_at)
      );

    if v_game.format = 'peg_board' and v_queue_position = 1 then
      v_is_picker := true;
      v_pool_size := coalesce((v_game.format_settings->>'picker_pool_size')::int, 10);

      select jsonb_agg(jsonb_build_object('id', gp.id, 'display_name', gp.display_name, 'skill_level', gp.skill_level))
        into v_picker_pool
        from (
          select gp.id, gp.display_name, gp.skill_level
          from game_players gp
          where gp.game_id = v_guest.game_id
            and gp.status = 'queued'
            and gp.id <> v_player.id
          order by gp.queue_position nulls last, gp.joined_at
          limit v_pool_size
        ) gp;
    end if;
  end if;

  if v_player.status = 'on_court' then
    select m.* into v_match
    from matches m
    join match_players mp on mp.match_id = m.id
    where mp.game_player_id = v_player.id
      and m.status in ('in_progress', 'awaiting_confirmation')
    order by m.started_at desc
    limit 1;

    if found then
      select c.* into v_court from courts c where c.id = v_match.court_id;

      select jsonb_agg(jsonb_build_object('id', gp.id, 'display_name', gp.display_name))
        into v_team_a
        from match_players mp join game_players gp on gp.id = mp.game_player_id
        where mp.match_id = v_match.id and mp.team = 'a';

      select jsonb_agg(jsonb_build_object('id', gp.id, 'display_name', gp.display_name))
        into v_team_b
        from match_players mp join game_players gp on gp.id = mp.game_player_id
        where mp.match_id = v_match.id and mp.team = 'b';
    end if;
  end if;

  select m.score_a, m.score_b, mp.team
    into v_last_match_score_a, v_last_match_score_b, v_last_match_team
  from matches m
  join match_players mp on mp.match_id = m.id
  where mp.game_player_id = v_player.id and m.status = 'confirmed'
  order by m.ended_at desc
  limit 1;

  return jsonb_build_object(
    'game_name', v_game.name,
    'game_format', v_game.format,
    'join_code', v_game.join_code,
    'player_status', v_player.status,
    'queue_position', v_queue_position,
    'court_name', v_court.name,
    'match_status', v_match.status,
    'score_a', v_match.score_a,
    'score_b', v_match.score_b,
    'team_a', v_team_a,
    'team_b', v_team_b,
    'last_match_score_a', v_last_match_score_a,
    'last_match_score_b', v_last_match_score_b,
    'last_match_my_team', v_last_match_team,
    'is_picker', v_is_picker,
    'picker_pool', v_picker_pool,
    'my_display_name', v_player.display_name,
    'my_skill_level', v_player.skill_level
  );
end;
$$;

grant execute on function public.guest_status(uuid) to anon;
