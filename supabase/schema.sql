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

-- Guarded so this whole file can be re-run safely against a database that
-- already has this constraint (plain ALTER TABLE ADD CONSTRAINT has no
-- IF NOT EXISTS form and would abort the rest of the script otherwise).
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'users_group_id_fkey'
  ) then
    alter table public.users
      add constraint users_group_id_fkey
      foreign key (group_id) references public.groups(id) on delete set null;
  end if;
end;
$$;

-- One row per user, overwritten on every sync. date_key is the reporting
-- device's local date for those minutes; readers compare it against their own
-- current date so a member who stopped syncing drops to zero instead of having
-- a stale total replayed as today's figure forever.
create table if not exists public.screentime (
  user_id uuid primary key references auth.users(id) on delete cascade,
  date_key text null,
  total_bad_minutes double precision not null default 0,
  bad_apps_breakdown jsonb not null default '[]'::jsonb,
  last_updated timestamptz null
);

alter table public.screentime add column if not exists date_key text;

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

-- Guarded the same way: re-adding a table already in the publication errors.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'group_leaderboard'
  ) then
    alter publication supabase_realtime add table public.group_leaderboard;
  end if;
end;
$$;

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

-- Column grants: clients may only ever change their own username directly.
-- group_id is only ever moved by the create_group/join_group/leave_group
-- functions below, which run as SECURITY DEFINER and bypass this grant —
-- otherwise any signed-in user could join (or fabricate membership in) any
-- group by writing directly to users.group_id, with no password check.
revoke update on public.users from authenticated;
grant update (username) on public.users to authenticated;

-- Groups policies
-- SELECT stays open (group search needs to find groups by name), but the
-- password_hash column is hidden from every client via column grants below —
-- RLS alone can't hide a single column, and a permissive password_hash read
-- would let anyone crack every group's password offline.
drop policy if exists "groups_select_authenticated" on public.groups;
create policy "groups_select_authenticated"
  on public.groups for select
  to authenticated
  using (true);

revoke select on public.groups from authenticated;
grant select (id, name, name_lower, member_ids, app_votes, created_by, created_at)
  on public.groups to authenticated;

-- No direct INSERT/DELETE policy for authenticated: creating a group (with a
-- freshly hashed password) and deleting an emptied group both happen only
-- inside the SECURITY DEFINER functions below.
drop policy if exists "groups_insert_authenticated" on public.groups;
revoke insert on public.groups from authenticated;

drop policy if exists "groups_delete_creator" on public.groups;
drop policy if exists "groups_delete_member_or_creator" on public.groups;
revoke delete on public.groups from authenticated;

-- The only direct UPDATE clients get is toggling their own app vote, and
-- only while they're already a member of that group. Renaming a group,
-- changing its password, or adding/removing members must go through the
-- functions below — the old "using (true)" policy let ANY authenticated
-- user (member or not) overwrite ANY group's member_ids or password_hash,
-- which is a full takeover of every group in the app.
drop policy if exists "groups_update_members" on public.groups;
drop policy if exists "groups_update_authenticated" on public.groups;
create policy "groups_update_member_votes"
  on public.groups for update
  to authenticated
  using (auth.uid()::text = any(member_ids))
  with check (auth.uid()::text = any(member_ids));

revoke update on public.groups from authenticated;
grant update (app_votes) on public.groups to authenticated;

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
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "screentime_history_write_own" on public.screentime_history;
create policy "screentime_history_write_own"
  on public.screentime_history for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Group history / leaderboard policies
-- Previously "using (true)"/"with check (true)" for ALL of select/insert/
-- update/delete — meaning any signed-in user (not just group members) could
-- read another group's screentime leaderboard, or overwrite it with made-up
-- data. Now scoped to members of the group the row belongs to.
drop policy if exists "group_history_select_authenticated" on public.group_history;
drop policy if exists "group_history_write_authenticated" on public.group_history;
create policy "group_history_select_member"
  on public.group_history for select
  to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_history.group_id
        and auth.uid()::text = any(g.member_ids)
    )
  );

create policy "group_history_write_member"
  on public.group_history for insert
  to authenticated
  with check (
    exists (
      select 1 from public.groups g
      where g.id = group_history.group_id
        and auth.uid()::text = any(g.member_ids)
    )
  );

create policy "group_history_update_member"
  on public.group_history for update
  to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_history.group_id
        and auth.uid()::text = any(g.member_ids)
    )
  )
  with check (
    exists (
      select 1 from public.groups g
      where g.id = group_history.group_id
        and auth.uid()::text = any(g.member_ids)
    )
  );

drop policy if exists "group_leaderboard_select_authenticated" on public.group_leaderboard;
drop policy if exists "group_leaderboard_write_authenticated" on public.group_leaderboard;
create policy "group_leaderboard_select_member"
  on public.group_leaderboard for select
  to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_leaderboard.group_id
        and auth.uid()::text = any(g.member_ids)
    )
  );

create policy "group_leaderboard_write_member"
  on public.group_leaderboard for insert
  to authenticated
  with check (
    exists (
      select 1 from public.groups g
      where g.id = group_leaderboard.group_id
        and auth.uid()::text = any(g.member_ids)
    )
  );

create policy "group_leaderboard_update_member"
  on public.group_leaderboard for update
  to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_leaderboard.group_id
        and auth.uid()::text = any(g.member_ids)
    )
  )
  with check (
    exists (
      select 1 from public.groups g
      where g.id = group_leaderboard.group_id
        and auth.uid()::text = any(g.member_ids)
    )
  );

-- Group membership functions
-- These run as SECURITY DEFINER so they can check/set password_hash and
-- member_ids without those being directly writable by clients (see the
-- revoked grants above). Passwords are hashed with bcrypt (pgcrypto's
-- crypt()/gen_salt('bf')) instead of the app's previous unsalted SHA-256,
-- which was crackable in bulk the moment password_hash was ever readable.
create or replace function public.create_group(p_name text, p_password text)
returns public.groups
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_name text := trim(p_name);
  v_name_lower text := lower(trim(p_name));
  v_group public.groups;
begin
  if v_uid is null then
    raise exception 'Not authenticated.';
  end if;
  if v_name = '' then
    raise exception 'Group name is required.';
  end if;
  if p_password is null or length(p_password) < 4 then
    raise exception 'Password must be at least 4 characters.';
  end if;
  if exists (select 1 from public.groups where name_lower = v_name_lower) then
    raise exception 'A group with that name already exists.';
  end if;

  insert into public.groups (name, name_lower, password_hash, member_ids, created_by)
  values (v_name, v_name_lower, crypt(p_password, gen_salt('bf')), array[v_uid::text], v_uid)
  returning * into v_group;

  update public.users set group_id = v_group.id where id = v_uid;

  return v_group;
end;
$$;

revoke all on function public.create_group(text, text) from public;
grant execute on function public.create_group(text, text) to authenticated;

create or replace function public.join_group(p_group_id uuid, p_password text)
returns public.groups
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_group public.groups;
begin
  if v_uid is null then
    raise exception 'Not authenticated.';
  end if;

  select * into v_group from public.groups where id = p_group_id for update;
  if not found then
    raise exception 'Group not found.';
  end if;

  if v_group.password_hash is null
     or crypt(p_password, v_group.password_hash) <> v_group.password_hash then
    raise exception 'Incorrect password.';
  end if;

  if not (v_uid::text = any(v_group.member_ids)) then
    update public.groups
      set member_ids = array_append(member_ids, v_uid::text)
      where id = p_group_id
      returning * into v_group;
  end if;

  update public.users set group_id = p_group_id where id = v_uid;

  return v_group;
end;
$$;

revoke all on function public.join_group(uuid, text) from public;
grant execute on function public.join_group(uuid, text) to authenticated;

create or replace function public.leave_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_member_ids text[];
begin
  if v_uid is null then
    raise exception 'Not authenticated.';
  end if;

  select member_ids into v_member_ids from public.groups where id = p_group_id for update;
  if not found then
    update public.users set group_id = null where id = v_uid and group_id = p_group_id;
    return;
  end if;

  v_member_ids := array_remove(v_member_ids, v_uid::text);

  if array_length(v_member_ids, 1) is null then
    delete from public.group_leaderboard where group_id = p_group_id;
    delete from public.group_history where group_id = p_group_id;
    delete from public.groups where id = p_group_id;
  else
    update public.groups set member_ids = v_member_ids where id = p_group_id;
  end if;

  update public.users set group_id = null where id = v_uid and group_id = p_group_id;
end;
$$;

revoke all on function public.leave_group(uuid) from public;
grant execute on function public.leave_group(uuid) to authenticated;
