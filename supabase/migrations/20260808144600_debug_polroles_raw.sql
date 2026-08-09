do $$
declare
  r record;
begin
  for r in
    select polname, polroles, array_length(polroles, 1) as roles_count
    from pg_policy
    where polrelid = 'public.games'::regclass
  loop
    raise notice 'RAW ROLES: % polroles=% count=%', r.polname, r.polroles, r.roles_count;
  end loop;
end $$;
