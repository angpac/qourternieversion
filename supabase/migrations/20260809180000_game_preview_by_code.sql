-- A public, read-only "peek" so the join screen can confirm the game's
-- actual name (not just its code) before someone fills out their name to
-- join — and so a scanned/typed code for an ended game fails fast instead
-- of only failing after the form is filled out. Safe to expose broadly:
-- it returns only what's already printed on the shared QR/invite anyway.
create or replace function public.game_preview_by_code(p_join_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game games;
begin
  select * into v_game from games where join_code = upper(p_join_code);

  if not found then
    raise exception 'No game found with that join code' using errcode = 'P0002';
  end if;

  return jsonb_build_object(
    'name', v_game.name,
    'status', v_game.status,
    'join_code', v_game.join_code
  );
end;
$$;

grant execute on function public.game_preview_by_code(text) to anon, authenticated;
