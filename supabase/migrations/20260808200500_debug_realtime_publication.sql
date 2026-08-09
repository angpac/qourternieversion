do $$
declare
  r record;
begin
  for r in
    select schemaname, tablename from pg_publication_tables where pubname = 'supabase_realtime'
  loop
    raise notice 'REALTIME TABLE: %.%', r.schemaname, r.tablename;
  end loop;
end $$;
