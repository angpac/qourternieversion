-- A player can't SELECT a game via RLS until they've already joined it
-- (the "players read joined games" policy requires is_game_player(id)),
-- so looking a game up by its join code needs a security definer function
-- that can see the games table regardless, validate the code, and create
-- the game_players row atomically.
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

  select * into v_existing from game_players where game_id = v_game.id and profile_id = auth.uid();

  if not found then
    insert into game_players (game_id, profile_id, display_name, skill_level, status, queue_position)
    values (
      v_game.id,
      auth.uid(),
      p_display_name,
      p_skill_level,
      'queued',
      (select coalesce(max(queue_position), -1) + 1 from game_players where game_id = v_game.id)
    );
  end if;

  return v_game;
end;
$$;

grant execute on function public.join_game_by_code(text, text, text) to authenticated;
