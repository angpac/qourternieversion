-- Expands push notifications beyond the original two events.
--
-- Adds:
--   * "your turn is coming up" for players near the front of the queue
--   * a nudge to the host when a player quits or steps out
--   * App Clip as a third APNs delivery target alongside iOS and watchOS
--
-- Announcements already notified every player, so nothing changes there.

-- ---------- App Clip push tokens ----------
-- The App Clip is a separate bundle id and therefore a separate APNs
-- topic, so the send-push function has to know which app a token came
-- from. 'appclip' rows behave like 'ios' rows otherwise.
alter table apns_device_tokens drop constraint if exists apns_device_tokens_platform_check;
alter table apns_device_tokens
  add constraint apns_device_tokens_platform_check
  check (platform in ('ios', 'watchos', 'appclip'));

-- ---------- "your turn is coming up" ----------
-- Stamped when a player has been told their turn is near, so a queue that
-- shuffles repeatedly can't notify the same person over and over. Cleared
-- whenever they re-enter the queue, so a later session notifies again.
alter table game_players
  add column if not exists turn_soon_notified_at timestamptz;

create or replace function public.reset_turn_soon_notice()
returns trigger
language plpgsql
as $$
begin
  -- Re-queued (came off court, or an admin put them back): they're
  -- eligible for a fresh "coming up" notice.
  if new.status = 'queued' and old.status is distinct from 'queued' then
    new.turn_soon_notified_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists reset_turn_soon_notice on game_players;
create trigger reset_turn_soon_notice
  before update on game_players
  for each row execute function public.reset_turn_soon_notice();

-- Everyone behind a player who leaves the queue moves up, so that is the
-- only moment positions actually change. Firing on every game_players
-- update instead would push a webhook on unrelated edits (rename, skill
-- level) and hammer the Edge Function.
create or replace function public.trigger_push_on_queue_advanced()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- NEW is unassigned in a DELETE trigger: referencing new.game_id there
  -- raises "record new is not assigned yet" and would abort the delete.
  -- So the two operations are handled separately rather than coalesced.
  if tg_op = 'DELETE' then
    if old.status = 'queued' then
      perform public.notify_send_push(jsonb_build_object(
        'type', 'queue_advanced',
        'game_id', old.game_id
      ));
    end if;
    return old;
  end if;

  if old.status = 'queued' and new.status is distinct from 'queued' then
    perform public.notify_send_push(jsonb_build_object(
      'type', 'queue_advanced',
      'game_id', new.game_id
    ));
  end if;
  return new;
end;
$$;

drop trigger if exists push_on_queue_advanced on game_players;
create trigger push_on_queue_advanced
  after update or delete on game_players
  for each row execute function public.trigger_push_on_queue_advanced();

-- ---------- host nudge when a player drops out ----------
-- 'removed' is a player quitting the game, 'resting' is stepping out for a
-- round. Both leave the host with a gap to fill, which is the whole point
-- of the nudge.
create or replace function public.trigger_push_on_player_left()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status is distinct from new.status
     and new.status in ('removed', 'resting') then
    perform public.notify_send_push(jsonb_build_object(
      'type', 'player_left',
      'game_player_id', new.id,
      'new_status', new.status::text
    ));
  end if;
  return new;
end;
$$;

drop trigger if exists push_on_player_left on game_players;
create trigger push_on_player_left
  after update on game_players
  for each row execute function public.trigger_push_on_player_left();
