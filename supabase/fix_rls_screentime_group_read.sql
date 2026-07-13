-- Run in Supabase SQL Editor to fix leaderboard zeroing out other members.
-- Problem: client-side rebuild could only read the syncing user's screentime row,
-- so group_leaderboard.entries overwrote fellow members with 0 minutes.
--
-- After running this, open the app and tap refresh on any group member's device
-- to rebuild group_leaderboard from all members' screentime rows.

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
