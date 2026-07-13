# Leaderboard

A Flutter app that tracks your friend group's screentime and ranks everyone on a live leaderboard — only counting the "bad" apps you actually want to cut back on.

---

## How It Works

1. Sign up with username, email and password
2. Create or join a group
3. Collectively vote on "bad apps" to track
4. The app syncs your bad app usage to Supabase on open and every 15 minutes in the background
5. The client rebuilds the group leaderboard after each upload

---

## Features

- **Live leaderboard** — screentime updates sync in the background and automatically refresh the group leaderboard via Supabase Realtime
- **Bad apps list** — each group curates its own list of tracked apps (social media, browsers, etc.)
- **Weekly history** — bar chart showing your screentime vs. group average over the past 7 days
- **Unlimited group size** — invite as many friends as you want
- **App breakdown** — tap any leaderboard entry to see each user's app breakdown for the day

---

## Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter (Android, iOS coming) |
| Auth | Supabase Auth (email/password) |
| Database | Supabase Postgres |
| State management | Riverpod |
| Background sync | WorkManager |

---

## Project Structure

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── config/
│   ├── constants/
│   ├── theme/
│   └── utils/
├── data/
│   ├── models/
│   ├── repositories/
│   └── supabase/
├── services/
├── providers/
├── screens/
│   ├── sign_in/
│   ├── home/
│   └── settings/
└── widgets/
supabase/
├── schema.sql
├── fix_rls_group_members.sql
└── fix_rls_screentime_group_read.sql
```
