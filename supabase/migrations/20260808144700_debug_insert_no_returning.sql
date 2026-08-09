create or replace function public.debug_insert_no_returning()
returns jsonb
language plpgsql
as $$
begin
  insert into games (owner_id, name, format, join_code)
  values (auth.uid(), 'RLS TEST NORET', 'king_of_the_court', 'ZZTESTNR');

  delete from games where join_code = 'ZZTESTNR';

  return jsonb_build_object('outcome', 'success', 'auth_uid', auth.uid());
exception when others then
  return jsonb_build_object('outcome', 'failed', 'sqlstate', SQLSTATE, 'message', SQLERRM, 'auth_uid', auth.uid());
end;
$$;

grant execute on function public.debug_insert_no_returning() to authenticated;
