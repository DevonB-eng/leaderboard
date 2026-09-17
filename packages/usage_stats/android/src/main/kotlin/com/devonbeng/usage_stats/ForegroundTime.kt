package com.devonbeng.usage_stats

import android.app.usage.UsageEvents

/**
 * One foreground/background transition, kept separate from [UsageEvents] so the
 * pairing below can be exercised without the Android framework.
 *
 * [className] is the activity the event belongs to. It is null for device-wide
 * events such as the screen turning off.
 */
internal data class UsageEventRecord(
    val packageName: String,
    val type: Int,
    val timestamp: Long,
    val className: String? = null,
)

/**
 * Totals foreground milliseconds per package from resume/pause transitions,
 * clipping every session to `[start, end)`.
 *
 * This is deliberately not UsageStatsManager.queryAndAggregateUsageStats(),
 * which is what the app_usage plugin used and what made daily totals appear to
 * accumulate: that call does not clip to the requested range. It returns each
 * whole interval bucket merely *overlapping* the range and sums them, so any
 * window touching two daily buckets reports both days added together.
 *
 * Sessions are tracked per activity, not per package. Android reports
 * resume/pause/stop for each activity, and a screen change inside one app is
 * logged as
 *
 *     PAUSED(old)  RESUMED(new)  STOPPED(old)
 *
 * so the old screen's stop arrives while the new screen is already in front.
 * Pairing by package let that late stop end the new screen's session, dropping
 * everything after the first in-app navigation — nearly all of TikTok (splash
 * -> feed) and much of Instagram and Facebook. It only showed on real phones:
 * the tracked apps used on the emulator never leave their first activity.
 *
 * This mirrors the framework's own accounting (UsageStats.updateActivity): a
 * package is foreground while any of its activities is resumed. The framework
 * keys activities by instance id, which is @SystemApi, so this keys by class
 * name. The two only differ when one instance hands off to another of the same
 * class, which [LATE_STOP_WINDOW_MILLIS] covers.
 */
internal object ForegroundTime {
    /**
     * How long after a same-class handoff a stop for that class is still taken
     * to be the previous instance's late stop. The framework stops the outgoing
     * activity once the incoming one goes idle, or after a 10 s idle timeout, so
     * genuine late stops land well inside this.
     */
    const val LATE_STOP_WINDOW_MILLIS = 15_000L

    fun totalsByPackage(
        events: List<UsageEventRecord>,
        start: Long,
        end: Long,
    ): Map<String, Long> {
        val totals = HashMap<String, Long>()
        // Resumed activity classes per package; foreground while non-empty.
        val resumed = HashMap<String, MutableSet<String?>>()
        val foregroundSince = HashMap<String, Long>()
        // Activities that resumed directly after pausing an instance of the same
        // class, mapped to when — the next stop may belong to that old instance.
        val handoffAt = HashMap<Pair<String, String?>, Long>()
        val seen = HashSet<String>()
        var anyResumed = false
        var lastTransition: UsageEventRecord? = null

        fun credit(packageName: String, from: Long, to: Long) {
            val duration = to - from
            if (duration > 0) {
                totals[packageName] = (totals[packageName] ?: 0L) + duration
            }
        }

        fun endActivity(packageName: String, className: String?, timestamp: Long) {
            val classes = resumed[packageName] ?: return
            if (!classes.remove(className) || classes.isNotEmpty()) return
            resumed.remove(packageName)
            foregroundSince.remove(packageName)?.let { credit(packageName, it, timestamp) }
        }

        for (event in events) {
            val packageName = event.packageName
            val className = event.className
            val timestamp = event.timestamp.coerceIn(start, end)

            when (event.type) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    val classes = resumed.getOrPut(packageName) { HashSet() }
                    if (classes.isEmpty()) foregroundSince[packageName] = timestamp
                    classes.add(className)

                    val previous = lastTransition
                    if (previous?.type == UsageEvents.Event.ACTIVITY_PAUSED &&
                        previous.packageName == packageName &&
                        previous.className == className
                    ) {
                        handoffAt[packageName to className] = timestamp
                    }
                    seen.add(packageName)
                    anyResumed = true
                }

                UsageEvents.Event.ACTIVITY_PAUSED -> {
                    handoffAt.remove(packageName to className)
                    if (resumed[packageName]?.contains(className) == true) {
                        endActivity(packageName, className, timestamp)
                    } else if (!anyResumed && packageName !in seen) {
                        // A pause before anything has resumed in the window means
                        // this app was already in the foreground when the window
                        // opened, so credit from `start`. That clipping is what
                        // stops a session running across midnight from being
                        // counted against both days. The `seen` guard keeps a
                        // second pause from claiming the whole window over again.
                        credit(packageName, start, timestamp)
                    }
                    seen.add(packageName)
                }

                UsageEvents.Event.ACTIVITY_STOPPED -> {
                    // Normally the late stop of an activity that already paused,
                    // so a no-op; never assume `start` here. But an app killed or
                    // crashed while in front logs a stop with no pause, and that
                    // must end its session — unless it may be the previous
                    // same-class instance stopping late.
                    val handoff = handoffAt.remove(packageName to className)
                    if (handoff == null || timestamp - handoff > LATE_STOP_WINDOW_MILLIS) {
                        endActivity(packageName, className, timestamp)
                    }
                    seen.add(packageName)
                }

                // The screen going off or the device shutting down does not
                // reliably emit a pause per app. Without closing open sessions
                // here, an app left in the foreground at lock time keeps accruing
                // until the next event — the largest single source of inflation.
                UsageEvents.Event.SCREEN_NON_INTERACTIVE,
                UsageEvents.Event.KEYGUARD_SHOWN,
                UsageEvents.Event.DEVICE_SHUTDOWN -> {
                    for ((openPackage, since) in foregroundSince) {
                        credit(openPackage, since, timestamp)
                    }
                    foregroundSince.clear()
                    resumed.clear()
                    handoffAt.clear()
                }
            }

            if (event.type == UsageEvents.Event.ACTIVITY_RESUMED ||
                event.type == UsageEvents.Event.ACTIVITY_PAUSED
            ) {
                lastTransition = event
            }
        }

        for ((openPackage, since) in foregroundSince) {
            credit(openPackage, since, end)
        }

        return totals
    }
}
