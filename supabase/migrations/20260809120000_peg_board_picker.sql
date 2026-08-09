-- Peg Board / Racket Staking: the player at the front of the queue becomes
-- the "Picker" and hand-picks 3 others from the next players in line to
-- build a doubles match. Unlike every other format, this is a PLAYER
-- action, not an admin one — "players update own row" only covers a
-- player's own game_players row, not starting a match involving others, so
-- this needs its own security definer function that validates the caller
-- really is the Picker right now before doing anything.
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

  if array_length(p_teammate_ids, 1) is distinct from 3 then
    raise exception 'Pick exactly 3 teammates' using errcode = 'P0001';
  end if;

  if (
    select count(*) from game_players
    where id = any(p_teammate_ids) and game_id = p_game_id and status = 'queued'
  ) <> 3 then
    raise exception 'One of your picks is no longer available' using errcode = 'P0001';
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

  insert into matches (game_id, court_id, status)
  values (p_game_id, v_court.id, 'in_progress')
  returning id into v_new_match_id;

  insert into match_players (match_id, game_player_id, team)
  values
    (v_new_match_id, v_picker.id, 'a'),
    (v_new_match_id, p_teammate_ids[1], 'a'),
    (v_new_match_id, p_teammate_ids[2], 'b'),
    (v_new_match_id, p_teammate_ids[3], 'b');

  update game_players set status = 'on_court'
  where id in (v_picker.id, p_teammate_ids[1], p_teammate_ids[2], p_teammate_ids[3]);

  return v_new_match_id;
end;
$$;

grant execute on function public.pick_board_start_match(uuid, uuid[]) to authenticated;

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

  if array_length(p_teammate_ids, 1) is distinct from 3 then
    raise exception 'Pick exactly 3 teammates' using errcode = 'P0001';
  end if;

  if (
    select count(*) from game_players
    where id = any(p_teammate_ids) and game_id = v_guest.game_id and status = 'queued'
  ) <> 3 then
    raise exception 'One of your picks is no longer available' using errcode = 'P0001';
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

  insert into matches (game_id, court_id, status)
  values (v_guest.game_id, v_court.id, 'in_progress')
  returning id into v_new_match_id;

  insert into match_players (match_id, game_player_id, team)
  values
    (v_new_match_id, v_picker.id, 'a'),
    (v_new_match_id, p_teammate_ids[1], 'a'),
    (v_new_match_id, p_teammate_ids[2], 'b'),
    (v_new_match_id, p_teammate_ids[3], 'b');

  update game_players set status = 'on_court'
  where id in (v_picker.id, p_teammate_ids[1], p_teammate_ids[2], p_teammate_ids[3]);

  return v_new_match_id;
end;
$$;

grant execute on function public.guest_pick_board_start_match(uuid, uuid[]) to anon;
