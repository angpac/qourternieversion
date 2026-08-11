-- The Live Activity push trigger referenced new.id on match_players, but
-- that table has no id column (its primary key is the composite
-- match_id, game_player_id) — every insert threw
-- 'record "new" has no field "id"' and Postgres rolled back the whole
-- statement, silently deleting every match's players on creation. This is
-- the real root cause behind every "court has no players" report so far,
-- not a client-side race. Pass the composite key through instead.
create or replace function public.trigger_push_on_match_assigned()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.notify_send_push(jsonb_build_object(
    'type', 'match_assigned',
    'match_id', new.match_id,
    'game_player_id', new.game_player_id
  ));
  return new;
end;
$$;
