-- Fires the send-push Edge Function on the two events that warrant a push:
-- a player gets assigned to a fresh match ("you're up!") and an admin sends
-- an announcement. The trigger authenticates its call with a random shared
-- secret (stored in Vault, also set as the Edge Function's own
-- PUSH_WEBHOOK_SECRET env var) rather than the project's service role key —
-- the function already holds its own service role key in its environment
-- for the privileged reads/sends it needs, so the trigger only needs to
-- prove the call really came from this database, not carry a key that
-- bypasses RLS entirely.
create extension if not exists pg_net with schema extensions;

select vault.create_secret(
  'f1a1a65a63b81c07b55b0d27e22efd0b7bf54db2679315a9a4d121deb9ef6272',
  'push_webhook_secret'
);

create or replace function public.notify_send_push(p_payload jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_secret text;
begin
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'push_webhook_secret';

  perform net.http_post(
    url := 'https://izanyjrbgguidttflpvp.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', v_secret),
    body := p_payload
  );
end;
$$;

create or replace function public.trigger_push_on_match_assigned()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.notify_send_push(jsonb_build_object('type', 'match_assigned', 'match_player_id', new.id));
  return new;
end;
$$;

drop trigger if exists push_on_match_assigned on match_players;
create trigger push_on_match_assigned
  after insert on match_players
  for each row execute function public.trigger_push_on_match_assigned();

create or replace function public.trigger_push_on_announcement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.notify_send_push(jsonb_build_object('type', 'announcement', 'announcement_id', new.id));
  return new;
end;
$$;

drop trigger if exists push_on_announcement on announcements;
create trigger push_on_announcement
  after insert on announcements
  for each row execute function public.trigger_push_on_announcement();
