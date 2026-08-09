do $$
declare
  r record;
begin
  for r in
    select policyname, cmd, qual, with_check
    from pg_policies
    where tablename = 'games'
    order by cmd
  loop
    raise notice 'POLICY: % cmd=% using=% check=%', r.policyname, r.cmd, r.qual, r.with_check;
  end loop;
end $$;
