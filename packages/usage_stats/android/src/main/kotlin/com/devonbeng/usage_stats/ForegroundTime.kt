package com.devonbeng.usage_stats

import android.app.usage.UsageEvents

/**
 * One foreground/background transition, kept separate from [UsageEvents] so the
 * pairing below can be exercised without the Android framework.
 */
internal data class UsageEventRecord(
    val packageName: String,
    val type: Int,
    val timestamp: Long,
)

/**
 * Totals foreground milliseconds per package by pairing each resume with the
 * event that ends it, clipping every session to `[start, end)`.
 *
 * This is deliberately not UsageStatsManager.queryAndAggregateUsageStats(),
 * which is what the app_usage plugin used and what made daily totals appear to
 * accumulate: that call does not clip to the requested range. It returns each
 * whole interval bucket merely *overlapping* the range and sums them, so any
 * window touching two daily buckets reports both days added together.
 */
internal object ForegroundTime {
    fun totalsByPackage(
        events: List<UsageEventRecord>,
        start: Long,
        end: Long,
    ): Map<String, Long> {
        val totals = HashMap<String, Long>()
        val openSince = HashMap<String, Long>()
        val seen = HashSet<String>()

        fun credit(packageName: String, from: Long, to: Long) {
            val duration = to - from
            if (duration > 0) {
                totals[packageName] = (totals[packageName] ?: 0L) + duration
            }
        }

        for (event in events) {
            val timestamp = event.timestamp.coerceIn(start, end)

            when (event.type) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    openSince[event.packageName] = timestamp
                    seen.add(event.packageName)
                }

                UsageEvents.Event.ACTIVITY_PAUSED -> {
                    // A pause with no resume inside the window means the app was
                    // already in the foreground when the window opened, so credit
                    // from `start`. That clipping is what stops a session running
                    // across midnight from being counted against both days. The
                    // `seen` guard keeps a second pause for the same package from
                    // claiming the whole window over again.
                    val from = openSince.remove(event.packageName)
                        ?: if (seen.contains(event.packageName)) continue else start
                    seen.add(event.packageName)
                    credit(event.packageName, from, timestamp)
                }

                UsageEvents.Event.ACTIVITY_STOPPED -> {
                    // Always preceded by a pause, so this only closes sessions a
                    // pause somehow didn't. Never assume `start` here: a stop can
                    // follow a pause that happened before the window opened, and
                    // crediting from `start` for it would invent usage.
                    val from = openSince.remove(event.packageName) ?: continue
                    credit(event.packageName, from, timestamp)
                }

                // The screen going off or the device shutting down does not
                // reliably emit a pause per app. Without closing open sessions
                // here, an app left in the foreground at lock time keeps accruing
                // until the next event — the largest single source of inflation.
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
