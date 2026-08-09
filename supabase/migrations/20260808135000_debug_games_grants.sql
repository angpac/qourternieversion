do $$
declare
  r record;
begin
  for r in
    select grantee, privilege_type
    from information_schema.role_table_grants
    where table_name = 'games'
  loop
    raise notice 'GRANT: % -> %', r.grantee, r.privilege_type;
  end loop;

  for r in
    select policyname, cmd, roles, qual, with_check
    from pg_policies
    where tablename = 'games'
  loop
    raise notice 'POLICY: % cmd=% roles=% using=% check=%', r.policyname, r.cmd, r.roles, r.qual, r.with_check;
  end loop;
end $$;
