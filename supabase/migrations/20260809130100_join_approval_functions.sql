-- Wire games.requires_approval into both join paths: a joiner lands in
-- 'pending' (no queue position yet) instead of 'queued' when the game
-- requires it. Approval/rejection itself is just a plain admin update to
-- game_players.status via the existing "admins manage roster" RLS policy —
-- no new RPC needed for that side.
create or replace function public.join_game_by_code(
  p_join_code text,
  p_display_name text,
  p_skill_level text default 'Beginner'
)
returns games
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game games;
  v_existing game_players;
  v_status text;
begin
  select * into v_game from games where join_code = upper(p_join_code);

  if not found then
    raise exception 'No game found with that join code' using errcode = 'P0002';
  end if;

  if v_game.status = 'ended' then
    raise exception 'This game has ended' using errcode = 'P0003';
  end if;

  if v_game.max_players is not null then
    if (select count(*) from game_players where game_id = v_game.id) >= v_game.max_players then
      raise exception 'This game is full' using errcode = 'P0001';
    end if;
  end if;

  select * into v_existing from game_players where game_id = v_game.id and profile_id = auth.uid();

  if not found then
    v_status := case when v_game.requires_approval then 'pending' else 'queued' end;

    insert into game_players (game_id, profile_id, display_name, skill_level, status, queue_position)
    values (
      v_game.id,
      auth.uid(),
      p_display_name,
      p_skill_level,
      v_status,
      case when v_status = 'queued'
        then (select coalesce(max(queue_position), -1) + 1 from game_players where game_id = v_game.id)
        else null
      end
    );
  end if;

  return v_game;
end;
$$;

grant execute on function public.join_game_by_code(text, text, text) to authenticated;

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
  v_status text;
begin
  select * into v_game from games where join_code = upper(p_join_code);

  if not found then
    raise exception 'No game found with that join code' using errcode = 'P0002';
  end if;

  if v_game.status = 'ended' then
    raise exception 'This game has ended' using errcode = 'P0003';
  end if;

  if v_game.max_players is not null then
    if (select count(*) from game_players where game_id = v_game.id) >= v_game.max_players then
      raise exception 'This game is full' using errcode = 'P0001';
    end if;
  end if;

  v_status := case when v_game.requires_approval then 'pending' else 'queued' end;

  insert into game_players (game_id, profile_id, display_name, skill_level, status, queue_position)
  values (
    v_game.id,
    null,
    p_display_name,
    p_skill_level,
    v_status,
    case when v_status = 'queued'
      then (select coalesce(max(queue_position), -1) + 1 from game_players where game_id = v_game.id)
      else null
    end
  )
  returning id into v_game_player_id;

  v_session_token := gen_random_uuid();

  insert into web_guests (game_id, game_player_id, session_token)
  values (v_game.id, v_game_player_id, v_session_token::text);

  return jsonb_build_object(
    'session_token', v_session_token,
    'game_id', v_game.id,
    'game_name', v_game.name,
    'join_code', v_game.join_code
  );
end;
$$;

grant execute on function public.guest_join_game(text, text, text) to anon;
