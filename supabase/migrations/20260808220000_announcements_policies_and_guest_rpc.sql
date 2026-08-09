-- announcements had row_security enabled with zero policies, meaning
-- default-deny blocked everyone — same oversight caught earlier with
-- match_players.
create policy "admins manage announcements"
  on announcements for all
  using (is_game_admin(game_id))
  with check (is_game_admin(game_id));

create policy "players read their announcements"
  on announcements for select
  using (
    is_game_player(game_id)
    and (
      target_player_id is null
      or target_player_id in (
        select id from game_players
        where game_id = announcements.game_id and profile_id = auth.uid()
      )
    )
  );

-- Web guests aren't Supabase-authenticated, so they read announcements
-- through the same session-token pattern as guest_status.
create or replace function public.guest_announcements(p_session_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guest web_guests;
  v_result jsonb;
begin
  select * into v_guest from web_guests where session_token = p_session_token::text;
  if not found then
    raise exception 'Session not found' using errcode = 'P0002';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id,
    'message', a.message,
    'sent_at', a.sent_at
  ) order by a.sent_at desc), '[]'::jsonb)
  into v_result
  from (
    select *
    from announcements
    where game_id = v_guest.game_id
      and (target_player_id is null or target_player_id = v_guest.game_player_id)
    order by sent_at desc
    limit 10
  ) a;

  return v_result;
end;
$$;

grant execute on function public.guest_announcements(uuid) to anon;
