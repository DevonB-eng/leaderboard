package com.devonbeng.usage_stats

import android.app.usage.UsageEvents
import kotlin.test.Test
import kotlin.test.assertEquals

internal class ForegroundTimeTest {
    private val midnight = 1_700_000_000_000L
    private val windowEnd = midnight + minutes(600)

    private fun minutes(n: Long) = n * 60_000L

    private fun seconds(n: Long) = n * 1_000L

    private fun resumed(packageName: String, at: Long, activity: String? = null) =
        UsageEventRecord(packageName, UsageEvents.Event.ACTIVITY_RESUMED, at, activity)

    private fun paused(packageName: String, at: Long, activity: String? = null) =
        UsageEventRecord(packageName, UsageEvents.Event.ACTIVITY_PAUSED, at, activity)

    private fun stopped(packageName: String, at: Long, activity: String? = null) =
        UsageEventRecord(packageName, UsageEvents.Event.ACTIVITY_STOPPED, at, activity)

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

    /**
     * The regression per-activity tracking exists for. The splash screen's stop
     * lands after the feed has resumed; pairing by package let it end the feed's
     * session, so the 20 minutes that followed were never counted.
     */
    @Test
    fun lateStopOfThePreviousScreenDoesNotEndTheNextOne() {
        val t = midnight + minutes(60)
        val result = totals(
            listOf(
                resumed("tiktok", t, "SplashActivity"),
                paused("tiktok", t + 500, "SplashActivity"),
                resumed("tiktok", t + 600, "MainActivity"),
                stopped("tiktok", t + 900, "SplashActivity"),
                paused("tiktok", t + minutes(20), "MainActivity"),
                stopped("tiktok", t + minutes(20) + 300, "MainActivity"),
            ),
        )

        assertEquals(mapOf("tiktok" to minutes(20) - 100), result)
    }

    /** Opening, then backing out of, another screen hosted by the same class. */
    @Test
    fun handoffToAnotherInstanceOfTheSameClassKeepsCounting() {
        val t = midnight + minutes(60)
        val result = totals(
            listOf(
                resumed("insta", t, "ModalActivity"),
                paused("insta", t + minutes(1), "ModalActivity"),
                resumed("insta", t + minutes(1) + 50, "ModalActivity"),
                stopped("insta", t + minutes(1) + 400, "ModalActivity"),
                paused("insta", t + minutes(2), "ModalActivity"),
                resumed("insta", t + minutes(2) + 50, "ModalActivity"),
                stopped("insta", t + minutes(2) + 400, "ModalActivity"),
                paused("insta", t + minutes(3), "ModalActivity"),
                stopped("insta", t + minutes(3) + 300, "ModalActivity"),
            ),
        )

        assertEquals(mapOf("insta" to minutes(3) - 100), result)
    }

    @Test
    fun anotherAppsDialogExcludesOnlyTheDialogTime() {
        val t = midnight + minutes(60)
        val result = totals(
            listOf(
                resumed("insta", t, "MainActivity"),
                paused("insta", t + minutes(1), "MainActivity"),
                resumed("chooser", t + minutes(1), "ChooserActivity"),
                paused("chooser", t + minutes(1) + seconds(5), "ChooserActivity"),
                resumed("insta", t + minutes(1) + seconds(5), "MainActivity"),
                stopped("chooser", t + minutes(1) + seconds(6), "ChooserActivity"),
                paused("insta", t + minutes(2), "MainActivity"),
                stopped("insta", t + minutes(2) + seconds(1), "MainActivity"),
            ),
        )

        assertEquals(
            mapOf("insta" to minutes(2) - seconds(5), "chooser" to seconds(5)),
            result,
        )
    }

    /**
     * An app killed or crashed while in front logs a stop with no pause. Ignoring
     * that stop would credit the whole gap until the app's next pause.
     */
    @Test
    fun stopWithoutAPauseEndsTheSession() {
        val t = midnight + minutes(60)
        val result = totals(
            listOf(
                resumed("insta", t, "MainActivity"),
                stopped("insta", t + seconds(13), "MainActivity"),
                resumed("launcher", t + seconds(13), "Launcher"),
                paused("launcher", t + minutes(25), "Launcher"),
                resumed("insta", t + minutes(25), "MainActivity"),
                paused("insta", t + minutes(25) + seconds(26), "MainActivity"),
            ),
        )

        assertEquals(seconds(39), result["insta"])
    }

    @Test
    fun stopLongAfterASameClassHandoffIsTreatedAsAKill() {
        val t = midnight + minutes(60)
        val result = totals(
            listOf(
                resumed("insta", t, "MainActivity"),
                paused("insta", t + minutes(1), "MainActivity"),
                resumed("insta", t + minutes(1), "MainActivity"),
                stopped("insta", t + minutes(1) + seconds(100), "MainActivity"),
                resumed("launcher", t + minutes(1) + seconds(100), "Launcher"),
            ),
        )

        assertEquals(minutes(1) + seconds(100), result["insta"])
    }

    /** Only one app can have been in front at the window start. */
    @Test
    fun pauseAfterAnotherAppResumedIsNotCreditedFromWindowStart() {
        val launcherStart = midnight + minutes(1)
        val result = totals(
            listOf(
                resumed("launcher", launcherStart, "Launcher"),
                paused("insta", midnight + minutes(5), "MainActivity"),
            ),
        )

        assertEquals(mapOf("launcher" to windowEnd - launcherStart), result)
    }

    @Test
    fun pauseArrivingAfterScreenOffIsNotCountedAgain() {
        val t = midnight + minutes(60)
        val result = totals(
            listOf(
                resumed("insta", t, "MainActivity"),
                screenOff(t + seconds(40)),
                paused("insta", t + seconds(40) + 200, "MainActivity"),
                stopped("insta", t + seconds(41), "MainActivity"),
                resumed("insta", t + minutes(10), "MainActivity"),
                paused("insta", t + minutes(10) + seconds(30), "MainActivity"),
            ),
        )

        assertEquals(mapOf("insta" to seconds(70)), result)
    }

    @Test
    fun appsResumedSideBySideAreEachCreditedInFull() {
        val t = midnight + minutes(60)
        val result = totals(
            listOf(
                resumed("insta", t, "MainActivity"),
                resumed("tiktok", t + seconds(10), "MainActivity"),
                paused("insta", t + seconds(70), "MainActivity"),
                paused("tiktok", t + seconds(70), "MainActivity"),
            ),
        )

        assertEquals(mapOf("insta" to seconds(70), "tiktok" to seconds(60)), result)
    }

    @Test
    fun overlappingActivitiesOfOnePackageAreCountedOnce() {
        val t = midnight + minutes(60)
        val result = totals(
            listOf(
                resumed("insta", t, "MainActivity"),
                resumed("insta", t + seconds(10), "SplitActivity"),
                paused("insta", t + seconds(50), "MainActivity"),
                paused("insta", t + seconds(80), "SplitActivity"),
            ),
        )

        assertEquals(mapOf("insta" to seconds(80)), result)
    }

    /**
     * Recorded with `dumpsys usagestats` on an emulator: Settings home, into
     * Display, and back. The framework's own accounting gives 42 s for this
     * session; pairing by package reported 8 s.
     */
    @Test
    fun matchesTheFrameworkOnARecordedSettingsTrace() {
        val home = "com.android.settings.homepage.SettingsHomepageActivity"
        val display = "com.android.settings.Settings\$DisplaySettingsActivity"
        val t = midnight + minutes(60)
        val result = totals(
            listOf(
                resumed("settings", t, home),
                paused("settings", t + seconds(6), home),
                resumed("settings", t + seconds(6), display),
                stopped("settings", t + seconds(7), home),
                paused("settings", t + seconds(27), display),
                resumed("settings", t + seconds(27), home),
                stopped("settings", t + seconds(28), display),
                paused("settings", t + seconds(42), home),
                resumed("launcher", t + seconds(42), "Launcher"),
                stopped("settings", t + seconds(42), home),
            ),
        )

        assertEquals(seconds(42), result["settings"])
    }
}
