-- Closes a race in guest_report_score: it only checked for an in_progress
-- match, not whether the game itself had ended, so a guest whose submit
-- request was already in flight the moment the admin ended the game could
-- still write a score into a match with no admin screen left to confirm
-- it. Ending a game never touches matches rows, so the in_progress check
-- alone couldn't catch this.
create or replace function public.guest_report_score(
  p_session_token uuid,
  p_score_a int,
  p_score_b int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guest web_guests;
  v_match_id uuid;
  v_game_status text;
begin
  select * into v_guest from web_guests where session_token = p_session_token::text;
  if not found then
    raise exception 'Session not found' using errcode = 'P0002';
  end if;

  select status into v_game_status from games where id = v_guest.game_id;
  if v_game_status = 'ended' then
    raise exception 'This game has ended' using errcode = 'P0002';
  end if;

  select m.id into v_match_id
  from matches m
  join match_players mp on mp.match_id = m.id
  where mp.game_player_id = v_guest.game_player_id
    and m.status = 'in_progress'
  order by m.started_at desc
  limit 1;

  if v_match_id is null then
    raise exception 'No in-progress match found' using errcode = 'P0002';
  end if;

  update matches
  set score_a = p_score_a, score_b = p_score_b, status = 'awaiting_confirmation'
  where id = v_match_id;
end;
$$;

grant execute on function public.guest_report_score(uuid, int, int) to anon;
