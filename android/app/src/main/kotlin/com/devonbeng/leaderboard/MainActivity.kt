package com.devonbeng.leaderboard

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Usage-stats access for Dart, without the app_usage plugin.
 *
 * Two reasons this is hand-rolled:
 *
 * 1. app_usage's getAppUsage() unconditionally launches
 *    Settings.ACTION_USAGE_ACCESS_SETTINGS whenever permission is missing,
 *    so it can't be used for a passive "is this granted?" check.
 * 2. app_usage reads usage via UsageStatsManager.queryAndAggregateUsageStats(),
 *    which does NOT clip to the requested range: it returns each whole
 *    interval bucket that *overlaps* the range and sums them. Any range
 *    touching two daily buckets therefore reports both days added together,
 *    which is why per-day totals appeared to accumulate instead of reset.
 *
 * queryEvents() below returns raw foreground/background transitions, so
 * sessions can be clipped exactly to [start, end).
 */
class MainActivity : FlutterActivity() {
    private val usageAccessChannel = "leaderboard/usage_access"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, usageAccessChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isGranted" -> result.success(isUsageAccessGranted())
                    "openSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "getUsage" -> {
                        val start = call.argument<Number>("start")?.toLong()
                        val end = call.argument<Number>("end")?.toLong()
                        if (start == null || end == null || end <= start) {
                            result.error(
                                "bad_range",
                                "getUsage requires start < end (epoch millis)",
                                null,
                            )
                        } else {
                            result.success(foregroundMillisByPackage(start, end))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isUsageAccessGranted(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Total foreground milliseconds per package within [start, end), built by
     * pairing resume events with the pause that ends them.
     *
     * ACTIVITY_RESUMED/ACTIVITY_PAUSED are the API 29 names for the constants
     * formerly called MOVE_TO_FOREGROUND/MOVE_TO_BACKGROUND; the numeric values
     * are unchanged, so this pairing works on every supported API level.
     */
    private fun foregroundMillisByPackage(start: Long, end: Long): Map<String, Long> {
        val manager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val totals = HashMap<String, Long>()
        val openSince = HashMap<String, Long>()
        val seen = HashSet<String>()

        fun credit(packageName: String, from: Long, to: Long) {
            val duration = to - from
            if (duration > 0) {
                totals[packageName] = (totals[packageName] ?: 0L) + duration
            }
        }

        val events = manager.queryEvents(start, end)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageName = event.packageName ?: continue
            val timestamp = event.timeStamp.coerceIn(start, end)

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    openSince[packageName] = timestamp
                    seen.add(packageName)
                }

                UsageEvents.Event.ACTIVITY_PAUSED -> {
                    // A pause with no resume inside the window means the app was
                    // already in the foreground when the window opened, so credit
                    // from `start` — that clipping is what keeps a session running
                    // across midnight from being counted twice. The `seen` guard
                    // stops a second pause for the same package from claiming the
                    // whole window again.
                    val from = openSince.remove(packageName)
                        ?: if (seen.contains(packageName)) continue else start
                    seen.add(packageName)
                    credit(packageName, from, timestamp)
                }

                UsageEvents.Event.ACTIVITY_STOPPED -> {
                    // Always preceded by ACTIVITY_PAUSED, so this only closes
                    // sessions that a pause somehow didn't; never assume `start`.
                    val from = openSince.remove(packageName) ?: continue
                    credit(packageName, from, timestamp)
                }

                // The screen going off or the device shutting down doesn't always
                // emit a pause per app. Without closing open sessions here, an app
                // foregrounded at lock time would keep accruing until the next
                // event — the single largest source of inflated totals.
                UsageEvents.Event.SCREEN_NON_INTERACTIVE,
                UsageEvents.Event.KEYGUARD_SHOWN,
                UsageEvents.Event.DEVICE_SHUTDOWN -> {
                    for ((openPackage, from) in openSince) {
                        credit(openPackage, from, timestamp)
                    }
                    openSince.clear()
                }
            }
        }

        for ((openPackage, from) in openSince) {
            credit(openPackage, from, end)
        }

        return totals
    }
}
