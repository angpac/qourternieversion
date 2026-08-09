-- Save a game's setup (courts, format, format settings, approval
-- requirement) to reuse next time, per PRD's Templates screen. Templates
-- are personal to the admin who saved them — not shared with co-admins —
-- so a simple owner-only policy is enough, no is_game_admin() needed.
create table game_templates (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles (id) on delete cascade,
  name text not null,
  num_courts int not null default 1,
  is_doubles boolean not null default true,
  requires_approval boolean not null default false,
  format rotation_format not null,
  format_settings jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index game_templates_owner_id_idx on game_templates (owner_id);

alter table game_templates enable row level security;

create policy "owners manage their templates"
  on game_templates for all
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());
