-- Temporary diagnostic RPC: lets an authenticated client see exactly what
-- Postgres believes about its own request — not a simulation, the real
-- thing, from inside the real PostgREST request path. Safe to drop once
-- the games-insert RLS issue is resolved.
create or replace function public.debug_auth_context()
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'auth_uid', auth.uid(),
    'auth_role', auth.role(),
    'current_user', current_user,
    'session_user', session_user,
    'claim_sub', current_setting('request.jwt.claim.sub', true),
    'claim_role', current_setting('request.jwt.claim.role', true),
    'claims_json', current_setting('request.jwt.claims', true)
  );
$$;

grant execute on function public.debug_auth_context() to authenticated;
