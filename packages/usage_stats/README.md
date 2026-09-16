# usage_stats

Android usage-stats access for the leaderboard app. Not published; consumed as a
path dependency from the root `pubspec.yaml`.

## Why this is a package and not a channel in `MainActivity`

`workmanager` runs background tasks in a bare `FlutterEngine(applicationContext)`
with no Activity, so `MainActivity.configureFlutterEngine` never runs for it. The
only native code that engine gets is what `GeneratedPluginRegistrant` registers,
and the Flutter tool builds that file from the plugin packages in `pubspec.yaml`.
Being a package is therefore what makes usage reading work in background syncs —
as a channel in `MainActivity` it threw `MissingPluginException` there, and
screentime only ever updated when the user opened the app.

## Why not the `app_usage` plugin

Two blockers:

- `getAppUsage()` launches the OS usage-access settings screen as an
  unconditional side effect when permission is missing, so it cannot be used for
  a passive permission check.
- It reads via `UsageStatsManager.queryAndAggregateUsageStats()`, which does not
  clip to the requested range. It returns every whole interval bucket that merely
  *overlaps* the range and sums them, so any window spanning two daily buckets
  reports both days added together — daily totals appear to accumulate instead of
  resetting.

`ForegroundTime` instead pairs the raw `queryEvents()` transitions and clips each
session to the requested window. Its tests live in
`android/src/test/kotlin/`; run them with `./gradlew :usage_stats:testDebugUnitTest`
from the app's `android/` directory.
