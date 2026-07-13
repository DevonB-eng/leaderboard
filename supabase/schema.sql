-- Leaderboard app schema for Supabase
-- Run this once in Supabase SQL Editor.

create extension if not exists "pgcrypto";

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  email text not null,
  group_id uuid null,
  created_at timestamptz not null default now()
);

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  name_lower text not null unique,
  password_hash text not null,
  member_ids text[] not null default '{}',
  app_votes jsonb not null default '{}'::jsonb,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.users
  add constraint users_group_id_fkey
  foreign key (group_id) references public.groups(id) on delete set null;

create table if not exists public.screentime (
  user_id uuid primary key references auth.users(id) on delete cascade,
  total_bad_minutes double precision not null default 0,
  bad_apps_breakdown jsonb not null default '[]'::jsonb,
  last_updated timestamptz null
);

create table if not exists public.screentime_history (
  user_id uuid not null references auth.users(id) on delete cascade,
  date_key text not null,
  total_bad_minutes double precision not null default 0,
  bad_apps_breakdown jsonb not null default '[]'::jsonb,
  recorded_at timestamptz not null default now(),
  primary key (user_id, date_key)
);

create table if not exists public.group_history (
  group_id uuid not null references public.groups(id) on delete cascade,
  date_key text not null,
  average_bad_minutes double precision not null default 0,
  recorded_at timestamptz not null default now(),
  primary key (group_id, date_key)
);

create table if not exists public.group_leaderboard (
  group_id uuid primary key references public.groups(id) on delete cascade,
  entries jsonb not null default '[]'::jsonb,
  last_updated timestamptz not null default now()
);

create index if not exists idx_users_group_id on public.users(group_id);
create index if not exists idx_groups_name_lower on public.groups(name_lower);
create index if not exists idx_screentime_history_user_date
  on public.screentime_history(user_id, date_key);
create index if not exists idx_group_history_group_date
  on public.group_history(group_id, date_key);

alter publication supabase_realtime add table public.group_leaderboard;

-- RLS
alter table public.users enable row level security;
alter table public.groups enable row level security;
alter table public.screentime enable row level security;
alter table public.screentime_history enable row level security;
alter table public.group_history enable row level security;
alter table public.group_leaderboard enable row level security;

-- Users table policies
-- Own row + any user who shares a group with you (so member lists can show usernames).
drop policy if exists "users_select_own" on public.users;
drop policy if exists "users_select_own_or_fellow_members" on public.users;
create policy "users_select_own_or_fellow_members"
  on public.users for select
  to authenticated
  using (
    auth.uid() = id
    or exists (
      select 1 from public.groups g
      where auth.uid()::text = any(g.member_ids)
        and users.id::text = any(g.member_ids)
    )
  );

drop policy if exists "users_insert_own" on public.users;
create policy "users_insert_own"
  on public.users for insert
  with check (auth.uid() = id);

drop policy if exists "users_update_own" on public.users;
create policy "users_update_own"
  on public.users for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Groups policies
drop policy if exists "groups_select_authenticated" on public.groups;
create policy "groups_select_authenticated"
  on public.groups for select
  to authenticated
  using (true);

drop policy if exists "groups_insert_authenticated" on public.groups;
create policy "groups_insert_authenticated"
  on public.groups for insert
  to authenticated
  with check (auth.uid() = created_by);

-- Joining must allow updating member_ids before the user appears in the array;
-- the old policy blocked joiners and updates appeared to work only in local UI.
drop policy if exists "groups_update_members" on public.groups;
create policy "groups_update_authenticated"
  on public.groups for update
  to authenticated
  using (true)
  with check (true);

drop policy if exists "groups_delete_creator" on public.groups;
drop policy if exists "groups_delete_member_or_creator" on public.groups;
create policy "groups_delete_member_or_creator"
  on public.groups for delete
  to authenticated
  using (
    auth.uid() = created_by
    or auth.uid()::text = any(member_ids)
  );

-- Screentime policies
-- SELECT: own row + fellow group members (needed for client-side leaderboard rebuild).
-- WRITE: own row only.
drop policy if exists "screentime_select_own" on public.screentime;
drop policy if exists "screentime_select_own_or_fellow_members" on public.screentime;
create policy "screentime_select_own_or_fellow_members"
  on public.screentime for select
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.groups g
      where auth.uid()::text = any(g.member_ids)
        and screentime.user_id::text = any(g.member_ids)
    )
  );

drop policy if exists "screentime_upsert_own" on public.screentime;
drop policy if exists "screentime_insert_own" on public.screentime;
drop policy if exists "screentime_update_own" on public.screentime;
create policy "screentime_insert_own"
  on public.screentime for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "screentime_update_own"
  on public.screentime for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Screentime history policies
drop policy if exists "screentime_history_select_own" on public.screentime_history;
create policy "screentime_history_select_own"
  on public.screentime_history for select
  using (auth.uid() = user_id);

drop policy if exists "screentime_history_write_own" on public.screentime_history;
create policy "screentime_history_write_own"
  on public.screentime_history for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Group history policies
drop policy if exists "group_history_select_authenticated" on public.group_history;
create policy "group_history_select_authenticated"
  on public.group_history for select
  to authenticated
  using (true);

drop policy if exists "group_history_write_authenticated" on public.group_history;
create policy "group_history_write_authenticated"
  on public.group_history for all
  to authenticated
  using (true)
  with check (true);

-- Leaderboard policies
drop policy if exists "group_leaderboard_select_authenticated" on public.group_leaderboard;
create policy "group_leaderboard_select_authenticated"
  on public.group_leaderboard for select
  to authenticated
  using (true);

drop policy if exists "group_leaderboard_write_authenticated" on public.group_leaderboard;
create policy "group_leaderboard_write_authenticated"
  on public.group_leaderboard for all
  to authenticated
  using (true)
  with check (true);
