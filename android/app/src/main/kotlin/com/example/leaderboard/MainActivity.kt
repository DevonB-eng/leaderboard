package com.example.leaderboard

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The app_usage plugin's getUsage() call unconditionally launches
 * Settings.ACTION_USAGE_ACCESS_SETTINGS as a side effect whenever usage-stats
 * permission is missing, with no way to opt out from Dart. That makes it
 * unsafe to call for a passive "is this granted?" check, since the mere act
 * of checking yanks the user into Settings before our own in-app prompt can
 * run. This channel checks the permission via AppOpsManager directly (no
 * side effects) and opens the Usage Access settings screen only when we
 * explicitly ask it to.
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
}
