package com.devonbeng.usage_stats

import android.app.Activity
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Usage-stats access for Dart.
 *
 * This lives in a plugin package rather than in MainActivity so the Flutter
 * tool registers it through GeneratedPluginRegistrant, which every engine runs
 * — including the bare `FlutterEngine(applicationContext)` that workmanager
 * builds for background work. A channel registered in
 * MainActivity.configureFlutterEngine only ever exists for the Activity's
 * engine, so background syncs could never read usage and silently no-opped.
 *
 * It also replaces the app_usage plugin, whose getAppUsage() launches the OS
 * usage-access settings screen as an unconditional side effect when permission
 * is missing, making it unusable for a passive permission check.
 */
class UsageStatsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isGranted" -> result.success(isUsageAccessGranted())

            "openSettings" -> {
                openUsageAccessSettings()
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
                    val events = readEvents(start, end)
                    result.success(ForegroundTime.totalsByPackage(events, start, end))
                }
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Checked through AppOpsManager rather than by attempting a read, so asking
     * has no side effects and cannot send the user to Settings on its own.
     */
    private fun isUsageAccessGranted(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        val host = activity
        if (host != null) {
            host.startActivity(intent)
        } else {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    private fun readEvents(start: Long, end: Long): List<UsageEventRecord> {
        val manager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val records = ArrayList<UsageEventRecord>()
        val events = manager.queryEvents(start, end)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageName = event.packageName ?: continue
            records.add(
                UsageEventRecord(packageName, event.eventType, event.timeStamp, event.className),
            )
        }
        return records
    }

    private companion object {
        const val CHANNEL = "leaderboard/usage_access"
    }
}
