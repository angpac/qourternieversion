-- game_admins has existed since the start (is_game_admin() already checks
-- it) but was enabled for RLS with zero policies defined — the same
-- "enabled but no policies = locked out for everyone" gap found earlier
-- this session on match_players/announcements. Nothing could read or write
-- it directly, so there was never a way to actually add a co-admin.
create policy "admins manage co-admins"
  on game_admins for all
  using (is_game_admin(game_id))
  with check (is_game_admin(game_id));

-- A co-admin invite is a separate code from the player join_code, so
-- sharing one never accidentally lets someone in as a co-admin instead of
-- a player (or vice versa).
alter table games add column admin_invite_code text unique;

-- Redeeming an invite inserts the redeemer as a co-admin of THAT game —
-- this has to be security definer because, before the insert, the
-- redeemer isn't an admin yet, so "admins manage co-admins" (which checks
-- is_game_admin) would otherwise block the very row that makes them one.
create or replace function public.redeem_admin_invite(p_invite_code text)
returns games
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game games;
begin
  select * into v_game from games where admin_invite_code = upper(p_invite_code);

  if not found then
    raise exception 'No game found with that invite code' using errcode = 'P0002';
  end if;

  insert into game_admins (game_id, profile_id)
  values (v_game.id, auth.uid())
  on conflict (game_id, profile_id) do nothing;

  return v_game;
end;
$$;

grant execute on function public.redeem_admin_invite(text) to authenticated;
