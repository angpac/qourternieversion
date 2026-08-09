create or replace function public.debug_games_policies()
returns jsonb
language sql
security definer
as $$
  select jsonb_build_object(
    'row_security_enabled', (select relrowsecurity from pg_class where oid = 'public.games'::regclass),
    'force_row_security', (select relforcerowsecurity from pg_class where oid = 'public.games'::regclass),
    'policies', (
      select jsonb_agg(jsonb_build_object(
        'name', polname,
        'permissive', polpermissive,
        'cmd', polcmd,
        'roles', (select array_agg(rolname) from pg_roles where oid = any(polroles)),
        'using', pg_get_expr(polqual, polrelid),
        'check', pg_get_expr(polwithcheck, polrelid)
      ))
      from pg_policy where polrelid = 'public.games'::regclass
    ),
    'triggers', (
      select jsonb_agg(tgname) from pg_trigger
      where tgrelid = 'public.games'::regclass and not tgisinternal
    ),
    'column_defaults', (
      select jsonb_object_agg(attname, pg_get_expr(adbin, adrelid))
      from pg_attribute
      join pg_attrdef on adrelid = attrelid and adnum = attnum
      where attrelid = 'public.games'::regclass
    )
  );
$$;

grant execute on function public.debug_games_policies() to authenticated;
