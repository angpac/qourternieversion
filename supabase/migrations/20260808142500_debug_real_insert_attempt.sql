-- Runs as the REAL caller (no SECURITY DEFINER, no simulated GUCs) so this
-- is the truest possible reproduction of what a PostgREST insert experiences.
create or replace function public.debug_real_insert_attempt()
returns jsonb
language plpgsql
as $$
declare
  new_id uuid;
  result jsonb;
begin
  begin
    insert into games (owner_id, name, format, join_code)
    values (auth.uid(), 'RLS TEST REAL', 'king_of_the_court', 'ZZTESTR')
    returning id into new_id;

    result := jsonb_build_object('outcome', 'success', 'id', new_id, 'auth_uid', auth.uid());
    delete from games where id = new_id;
  exception when others then
    result := jsonb_build_object(
      'outcome', 'failed',
      'sqlstate', SQLSTATE,
      'message', SQLERRM,
      'auth_uid', auth.uid()
    );
  end;

  return result;
end;
$$;

grant execute on function public.debug_real_insert_attempt() to authenticated;
