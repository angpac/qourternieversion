-- One push token per player's currently-running Live Activity (Lock
-- Screen / Dynamic Island). Only for the signed-in iPhone app — web
-- guests and Watch don't run Live Activities. Unique per game_player_id
-- since a player only ever has one running activity at a time; a new
-- activity (e.g. rejoining a game) just replaces the old token.
create table live_activity_tokens (
  id uuid primary key default gen_random_uuid(),
  game_player_id uuid not null references game_players (id) on delete cascade unique,
  push_token text not null,
  updated_at timestamptz not null default now()
);

alter table live_activity_tokens enable row level security;

create policy "players manage own activity token"
  on live_activity_tokens for all
  using (exists (
    select 1 from game_players where id = game_player_id and profile_id = auth.uid()
  ))
  with check (exists (
    select 1 from game_players where id = game_player_id and profile_id = auth.uid()
  ));
