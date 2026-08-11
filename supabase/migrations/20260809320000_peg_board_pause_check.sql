-- Pausing a game must actually stop new matches from starting via Peg
-- Board too, not just admin-driven auto-assign/manual-start paths.
-- Peg Board was hardcoded to "pick exactly 3 teammates" (always 2v2),
-- regardless of the game's overall singles/doubles setting or a court's
-- singles_override. Now the required team size comes from whichever open
-- court the Picker is about to land on (same lowest-position selection as
-- before), falling back to the game's overall is_doubles when that court
-- has no override — so a singles-override court asks the Picker for 1
-- opponent instead of 3 teammates.
create or replace function public.pick_board_start_match(
  p_game_id uuid,
  p_teammate_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_picker game_players;
  v_court courts;
  v_game games;
  v_required int;
  v_new_match_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not signed in' using errcode = 'P0002';
  end if;

  select * into v_picker from game_players
    where game_id = p_game_id and profile_id = auth.uid() and status = 'queued';
  if not found then
    raise exception 'You are not queued in this game' using errcode = 'P0002';
  end if;

  if exists (
    select 1 from game_players
    where game_id = p_game_id and status = 'queued'
      and (
        queue_position < v_picker.queue_position
        or (queue_position is null and joined_at < v_picker.joined_at)
      )
  ) then
    raise exception 'You are not the Picker right now' using errcode = 'P0003';
  end if;

  select c.* into v_court
  from courts c
  where c.game_id = p_game_id
    and not exists (
      select 1 from matches m where m.court_id = c.id and m.status in ('in_progress', 'awaiting_confirmation')
    )
  order by c.position
  limit 1;

  if not found then
    raise exception 'No open court right now' using errcode = 'P0002';
  end if;

  select * into v_game from games where id = p_game_id;

  if v_game.status = 'paused' then
    raise exception 'Game is paused' using errcode = 'P0002';
  end if;

  v_required := coalesce(
    case v_court.singles_override when true then 1 when false then 2 else null end,
    case when v_game.is_doubles then 2 else 1 end
  );

  if array_length(p_teammate_ids, 1) is distinct from (2 * v_required - 1) then
    raise exception 'Pick exactly % player(s) for this court', (2 * v_required - 1) using errcode = 'P0001';
  end if;

  if (
    select count(*) from game_players
    where id = any(p_teammate_ids) and game_id = p_game_id and status = 'queued'
  ) <> (2 * v_required - 1) then
    raise exception 'One of your picks is no longer available' using errcode = 'P0001';
  end if;

  insert into matches (game_id, court_id, status)
  values (p_game_id, v_court.id, 'in_progress')
  returning id into v_new_match_id;

  insert into match_players (match_id, game_player_id, team)
  values (v_new_match_id, v_picker.id, 'a');

  if v_required > 1 then
    insert into match_players (match_id, game_player_id, team)
    select v_new_match_id, unnest(p_teammate_ids[1 : v_required - 1]), 'a';
  end if;

  insert into match_players (match_id, game_player_id, team)
  select v_new_match_id, unnest(p_teammate_ids[v_required : 2 * v_required - 1]), 'b';

  update game_players set status = 'on_court'
  where id = v_picker.id or id = any(p_teammate_ids);

  return v_new_match_id;
end;
$$;

-- Same thing for web guests, session-token authorized instead of auth.uid().
create or replace function public.guest_pick_board_start_match(
  p_session_token uuid,
  p_teammate_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guest web_guests;
  v_picker game_players;
  v_court courts;
  v_game games;
  v_required int;
  v_new_match_id uuid;
begin
  select * into v_guest from web_guests where session_token = p_session_token::text;
  if not found then
    raise exception 'Session not found' using errcode = 'P0002';
  end if;

  select * into v_picker from game_players where id = v_guest.game_player_id and status = 'queued';
  if not found then
    raise exception 'You are not queued in this game' using errcode = 'P0002';
  end if;

  if exists (
    select 1 from game_players
    where game_id = v_guest.game_id and status = 'queued'
      and (
        queue_position < v_picker.queue_position
        or (queue_position is null and joined_at < v_picker.joined_at)
      )
  ) then
    raise exception 'You are not the Picker right now' using errcode = 'P0003';
  end if;

  select c.* into v_court
  from courts c
  where c.game_id = v_guest.game_id
    and not exists (
      select 1 from matches m where m.court_id = c.id and m.status in ('in_progress', 'awaiting_confirmation')
    )
  order by c.position
  limit 1;

  if not found then
    raise exception 'No open court right now' using errcode = 'P0002';
  end if;

  select * into v_game from games where id = v_guest.game_id;

  if v_game.status = 'paused' then
    raise exception 'Game is paused' using errcode = 'P0002';
  end if;

  v_required := coalesce(
    case v_court.singles_override when true then 1 when false then 2 else null end,
    case when v_game.is_doubles then 2 else 1 end
  );

  if array_length(p_teammate_ids, 1) is distinct from (2 * v_required - 1) then
    raise exception 'Pick exactly % player(s) for this court', (2 * v_required - 1) using errcode = 'P0001';
  end if;

  if (
    select count(*) from game_players
    where id = any(p_teammate_ids) and game_id = v_guest.game_id and status = 'queued'
  ) <> (2 * v_required - 1) then
    raise exception 'One of your picks is no longer available' using errcode = 'P0001';
  end if;

  insert into matches (game_id, court_id, status)
  values (v_guest.game_id, v_court.id, 'in_progress')
  returning id into v_new_match_id;

  insert into match_players (match_id, game_player_id, team)
  values (v_new_match_id, v_picker.id, 'a');

  if v_required > 1 then
    insert into match_players (match_id, game_player_id, team)
    select v_new_match_id, unnest(p_teammate_ids[1 : v_required - 1]), 'a';
  end if;

  insert into match_players (match_id, game_player_id, team)
  select v_new_match_id, unnest(p_teammate_ids[v_required : 2 * v_required - 1]), 'b';

  update game_players set status = 'on_court'
  where id = v_picker.id or id = any(p_teammate_ids);

  return v_new_match_id;
end;
$$;
