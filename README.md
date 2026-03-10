# Leaderboard

A Flutter app that tracks your friend group's screentime and ranks everyone on a live leaderboard — only counting the "bad" apps you actually want to cut back on.

---

## How It Works

1. Sign up with username, email and password
2. Create or join a group
3. Collectively vote on "bad apps" to track
4. The app syncs your bad app usage to Firestore on open and every 30 minutes in the background
5. A Cloud Function triggers on each upload and rebuilds the group leaderboard instantly

---

## Features

- **Live leaderboard** — screentime updates sync in the background and automatically refresh the group leaderboard
- **Bad apps list** — each group curates its own list of tracked apps (social media, browsers, etc.)
- **Weekly history** — bar chart showing your screentime vs. group average over the past 7 days
- **Unlimited group size** — invite as many friends as you want
- **App breakdown** — tap any leaderboard entry to see each user's app breakdown for the day

---

## Screenshots

| Home | Leaderboard | Settings |
|------|-------------|----------|
| ![Home](lib\assets\Home.png) | ![Leaderboard](lib\assets\Leaderboard.png) | ![Settings](lib\assets\Settings.png) |

---

## Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter (Android, iOS coming) |
| Auth | Firebase Auth (email/password) |
| Database | Cloud Firestore |
| Backend | Firebase Cloud Functions |
| Background sync | WorkManager |

---

## Project Structure

```
lib/
├── main.dart
├── background_sync.dart
├── screens/
│   ├── home_screen.dart
│   ├── sign_in_screen.dart
│   └── settings_screen.dart
├── widgets/
│   └── email_sign_in_button.dart
└── utils/
    ├── authentication.dart
    └── screen_time.dart
functions/
└── index.js
```
