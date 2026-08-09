-- APNs device tokens for the iPhone app and Watch companion (Web Push
-- already has push_subscriptions for browser guests). One row per
-- device — a player signed in on their phone AND wearing the Watch gets
-- two rows, both under the same profile.
create table apns_device_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles (id) on delete cascade,
  device_token text not null unique,
  platform text not null check (platform in ('ios', 'watchos')),
  created_at timestamptz not null default now()
);

create index apns_device_tokens_profile_id_idx on apns_device_tokens (profile_id);

alter table apns_device_tokens enable row level security;

create policy "players manage own device tokens"
  on apns_device_tokens for all
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- Web guests can't use RLS (no auth.uid()), so subscribing goes through a
-- security definer function validated by session token, same pattern as
-- every other guest_* function.
create or replace function public.guest_subscribe_push(
  p_session_token uuid,
  p_endpoint text,
  p_p256dh_key text,
  p_auth_key text,
  p_user_agent text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guest web_guests;
begin
  select * into v_guest from web_guests where session_token = p_session_token::text;
  if not found then
    raise exception 'Session not found' using errcode = 'P0002';
  end if;

  insert into push_subscriptions (game_player_id, endpoint, p256dh_key, auth_key, user_agent)
  values (v_guest.game_player_id, p_endpoint, p_p256dh_key, p_auth_key, p_user_agent)
  on conflict (endpoint) do update set
    game_player_id = excluded.game_player_id,
    p256dh_key = excluded.p256dh_key,
    auth_key = excluded.auth_key,
    user_agent = excluded.user_agent;
end;
$$;

grant execute on function public.guest_subscribe_push(uuid, text, text, text, text) to anon;
