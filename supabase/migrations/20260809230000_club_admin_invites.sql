-- Same invite-code pattern already used for co-admins on a single game,
-- one level up: a club owner shares this code, and anyone who redeems it
-- becomes a club admin — which (per is_game_admin()'s club-inheritance
-- logic added earlier) immediately makes them an admin of every game
-- under that club too, without touching any individual game.
alter table clubs add column club_admin_invite_code text unique;

create or replace function public.redeem_club_admin_invite(p_invite_code text)
returns clubs
language plpgsql
security definer
set search_path = public
as $$
declare
  v_club clubs;
begin
  select * into v_club from clubs where club_admin_invite_code = upper(p_invite_code);

  if not found then
    raise exception 'No club found with that invite code' using errcode = 'P0002';
  end if;

  insert into club_admins (club_id, profile_id)
  values (v_club.id, auth.uid())
  on conflict (club_id, profile_id) do nothing;

  return v_club;
end;
$$;

grant execute on function public.redeem_club_admin_invite(text) to authenticated;
