-- Fixes device tokens sticking to the wrong account.
--
-- apns_device_tokens is unique on device_token, and its RLS policy is
-- `using (profile_id = auth.uid())`. So when a second person signs in on a
-- device the first person used, the client's upsert has to UPDATE a row it
-- cannot see — the policy blocks it and the write fails silently. The row
-- keeps the previous owner's profile_id, which means:
--   * the new user receives none of their own notifications, and
--   * the previous user's notifications keep arriving on this device.
--
-- A security definer function can reassign the row; the client can't.

create or replace function public.register_device_token(
  p_device_token text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile uuid := auth.uid();
begin
  if v_profile is null then
    raise exception 'not authenticated';
  end if;

  -- Mirrors the table's own check constraint. Validated here too so a bad
  -- client can't get a confusing constraint error from inside the function.
  if p_platform not in ('ios', 'watchos', 'appclip') then
    raise exception 'unsupported platform: %', p_platform;
  end if;

  insert into apns_device_tokens (profile_id, device_token, platform)
  values (v_profile, p_device_token, p_platform)
  on conflict (device_token) do update
    set profile_id = excluded.profile_id,
        platform   = excluded.platform,
        created_at = now();
end;
$$;

revoke all on function public.register_device_token(text, text) from public;
grant execute on function public.register_device_token(text, text) to authenticated;

-- Sign-out cleanup. Scoped to one token on purpose: deleting every token for
-- the profile would silently disable push on that person's other devices.
create or replace function public.unregister_device_token(p_device_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return;
  end if;

  delete from apns_device_tokens
   where device_token = p_device_token
     and profile_id = auth.uid();
end;
$$;

revoke all on function public.unregister_device_token(text) from public;
grant execute on function public.unregister_device_token(text) to authenticated;
