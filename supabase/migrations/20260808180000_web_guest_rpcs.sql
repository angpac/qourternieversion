-- Web guests aren't Supabase-authenticated users, so RLS (which keys off
-- auth.uid()) can't cover them directly. Rather than opening up raw table
-- access to the anon role, guests interact only through these two security
-- definer functions, authorizing themselves with a random session token
-- instead of a Supabase session — matching the approach already called out
-- in this schema's RLS comments for push_subscriptions.

create or replace function public.guest_join_game(
  p_join_code text,
  p_display_name text,
  p_skill_level text default 'Beginner'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game games;
  v_game_player_id uuid;
  v_session_token uuid;
begin
  select * into v_game from games where join_code = upper(p_join_code);

  if not found then
    raise exception 'No game found with that join code' using errcode = 'P0002';
  end if;

  if v_game.max_players is not null then
    if (select count(*) from game_players where game_id = v_game.id) >= v_game.max_players then
      raise exception 'This game is full' using errcode = 'P0001';
    end if;
  end if;

  insert into game_players (game_id, profile_id, display_name, skill_level, status, queue_position)
  values (
    v_game.id,
    null,
    p_display_name,
    p_skill_level,
    'queued',
    (select coalesce(max(queue_position), -1) + 1 from game_players where game_id = v_game.id)
  )
  returning id into v_game_player_id;

  v_session_token := gen_random_uuid();

  insert into web_guests (game_id, game_player_id, session_token)
  values (v_game.id, v_game_player_id, v_session_token::text);

  return jsonb_build_object(
    'session_token', v_session_token,
    'game_name', v_game.name,
    'game_format', v_game.format,
    'join_code', v_game.join_code
  );
end;
$$;

grant execute on function public.guest_join_game(text, text, text) to anon;

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
    'team_b', v_team_b
  );
end;
$$;

grant execute on function public.guest_status(uuid) to anon;
