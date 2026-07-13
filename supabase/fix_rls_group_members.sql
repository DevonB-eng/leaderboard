-- Run in Supabase SQL Editor if you already applied an older schema.sql.
-- Fixes: (1) joiners could not UPDATE groups.member_ids, (2) could not read fellow members' usernames.

-- Users: allow reading profiles of anyone in the same group as you.
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

-- Groups: allow authenticated clients to update rows (join/leave/votes).
drop policy if exists "groups_update_members" on public.groups;
drop policy if exists "groups_update_authenticated" on public.groups;
create policy "groups_update_authenticated"
  on public.groups for update
  to authenticated
  using (true)
  with check (true);

-- Groups: last member may delete the group even if not creator.
drop policy if exists "groups_delete_creator" on public.groups;
drop policy if exists "groups_delete_member_or_creator" on public.groups;
create policy "groups_delete_member_or_creator"
  on public.groups for delete
  to authenticated
  using (
    auth.uid() = created_by
    or auth.uid()::text = any(member_ids)
  );

-- Optional one-time repair if member_ids stayed empty while users.group_id was set:
-- update public.groups g
-- set member_ids = coalesce(
--   (select array_agg(u.id::text) from public.users u where u.group_id = g.id),
--   '{}'
-- );

-- Screentime: allow reading fellow group members' rows (leaderboard rebuild).
-- See also: fix_rls_screentime_group_read.sql
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
