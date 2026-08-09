drop policy if exists "owners insert their games" on games;
create policy "owners insert their games"
  on games for insert
  with check (true);
