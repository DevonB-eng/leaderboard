package com.devonbeng.usage_stats

import android.app.usage.UsageEvents
import kotlin.test.Test
import kotlin.test.assertEquals

internal class ForegroundTimeTest {
    private val midnight = 1_700_000_000_000L
    private val windowEnd = midnight + minutes(600)

    private fun minutes(n: Long) = n * 60_000L

    private fun resumed(packageName: String, at: Long) =
        UsageEventRecord(packageName, UsageEvents.Event.ACTIVITY_RESUMED, at)

    private fun paused(packageName: String, at: Long) =
        UsageEventRecord(packageName, UsageEvents.Event.ACTIVITY_PAUSED, at)

    private fun stopped(packageName: String, at: Long) =
        UsageEventRecord(packageName, UsageEvents.Event.ACTIVITY_STOPPED, at)

    private fun screenOff(at: Long) =
        UsageEventRecord("android", UsageEvents.Event.SCREEN_NON_INTERACTIVE, at)

    private fun totals(events: List<UsageEventRecord>) =
        ForegroundTime.totalsByPackage(events, midnight, windowEnd)

    @Test
    fun pairsResumeWithPause() {
        val result = totals(
            listOf(
                resumed("insta", midnight + minutes(60)),
                paused("insta", midnight + minutes(70)),
            ),
        )

        assertEquals(mapOf("insta" to minutes(10)), result)
    }

    @Test
    fun sumsRepeatedSessions() {
        val result = totals(
            listOf(
                resumed("insta", midnight + minutes(60)),
                paused("insta", midnight + minutes(70)),
                resumed("insta", midnight + minutes(200)),
                paused("insta", midnight + minutes(205)),
            ),
        )

        assertEquals(mapOf("insta" to minutes(15)), result)
    }

    /**
     * The regression the whole rewrite exists for: a session that began before
     * the window must be credited only from the window start, never for the
     * time it accrued the previous day.
     */
    @Test
    fun creditsFromWindowStartWhenAppWasAlreadyForegrounded() {
        val result = totals(listOf(paused("insta", midnight + minutes(5))))

        assertEquals(mapOf("insta" to minutes(5)), result)
    }

    @Test
    fun doesNotRecreditWindowStartOnASecondPause() {
        val result = totals(
            listOf(
                paused("insta", midnight + minutes(5)),
                paused("insta", midnight + minutes(300)),
            ),
        )

        assertEquals(mapOf("insta" to minutes(5)), result)
    }

    @Test
    fun stopAfterPauseDoesNotDoubleCount() {
        val result = totals(
            listOf(
                resumed("insta", midnight + minutes(60)),
                paused("insta", midnight + minutes(70)),
                stopped("insta", midnight + minutes(70)),
            ),
        )

        assertEquals(mapOf("insta" to minutes(10)), result)
    }

    /** A stop can follow a pause from before the window; it must invent nothing. */
    @Test
    fun stopWithNoOpenSessionIsIgnored() {
        val result = totals(listOf(stopped("insta", midnight + minutes(300))))

        assertEquals(emptyMap(), result)
    }

    @Test
    fun screenOffClosesAnOpenSession() {
        val result = totals(
            listOf(
                resumed("insta", midnight + minutes(60)),
                screenOff(midnight + minutes(75)),
                resumed("tiktok", midnight + minutes(400)),
                paused("tiktok", midnight + minutes(410)),
            ),
        )

        assertEquals(mapOf("insta" to minutes(15), "tiktok" to minutes(10)), result)
    }

    @Test
    fun sessionStillOpenAtWindowEndIsClosedThere() {
        val result = totals(listOf(resumed("insta", windowEnd - minutes(20))))

        assertEquals(mapOf("insta" to minutes(20)), result)
    }

    @Test
    fun clampsEventsFallingOutsideTheWindow() {
        val result = totals(
            listOf(
                resumed("insta", midnight - minutes(120)),
                paused("insta", midnight + minutes(30)),
            ),
        )

        assertEquals(mapOf("insta" to minutes(30)), result)
    }

    @Test
    fun tracksPackagesIndependently() {
        val result = totals(
            listOf(
                resumed("insta", midnight + minutes(10)),
                paused("insta", midnight + minutes(25)),
                resumed("tiktok", midnight + minutes(25)),
                paused("tiktok", midnight + minutes(60)),
            ),
        )

        assertEquals(mapOf("insta" to minutes(15), "tiktok" to minutes(35)), result)
    }
}
