import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/data/repositories/screentime_repository.dart';

class PermissionsService {
  // Guards against the launch flow (usage access -> battery optimization, each
  // potentially a trip to the OS Settings app) firing more than once per app
  // run. Without this, anything that causes HomeScreen to mount a second time
  // re-triggers the whole chain, stacking extra Settings screens the user has
  // to back out of.
  static bool _hasRequestedThisSession = false;

  // Stops a check that starts while another still has its dialog open (the
  // app reopened mid-prompt, say) from stacking a second dialog on top.
  static bool _isPrompting = false;

  /// The launch flow: usage access, then the battery exemption.
  Future<void> requestAll(BuildContext context) async {
    if (_hasRequestedThisSession) return;
    _hasRequestedThisSession = true;

    await _unlessPrompting(() async {
      final sentToSettings = await _requestUsageStatsPermission(context);
      // Settings opens without waiting for the user to come back, so asking
      // now would queue the battery dialog behind it, where the back press that
      // returns to the app dismisses it. HomeScreen asks once they're back.
      if (sentToSettings || !context.mounted) return;
      await _requestBatteryOptimizationExemption(context);
    });
  }

  /// Asks for the battery exemption if it's still missing. HomeScreen calls
  /// this every time the app is reopened: without the exemption Android defers
  /// background syncs, so members who don't open the app stop updating.
  Future<void> requestBatteryOptimizationExemption(BuildContext context) {
    return _unlessPrompting(
      () => _requestBatteryOptimizationExemption(context),
    );
  }

  Future<void> _unlessPrompting(Future<void> Function() prompt) async {
    if (_isPrompting) return;
    _isPrompting = true;
    try {
      await prompt();
    } finally {
      _isPrompting = false;
    }
  }

  /// Returns whether the user was sent to the Settings app.
  Future<bool> _requestUsageStatsPermission(BuildContext context) async {
    final hasUsageAccess = await ScreentimeRepository.checkUsageStatsGranted();
    if (hasUsageAccess || !context.mounted) return false;

    final confirmed = await _showPermissionDialog(
      context: context,
      title: 'SCREEN TIME ACCESS',
      message:
          'This app needs access to your usage stats to track '
          'screen time. Tap "Open Settings", find this app, '
          'and toggle on "Permit usage access".',
      confirmLabel: 'Open Settings',
    );
    if (!confirmed) return false;

    await ScreentimeRepository.openUsageAccessSettings();
    return true;
  }

  Future<void> _requestBatteryOptimizationExemption(
    BuildContext context,
  ) async {
    if (await Permission.ignoreBatteryOptimizations.isGranted) return;
    if (!context.mounted) return;

    final confirmed = await _showPermissionDialog(
      context: context,
      title: 'BACKGROUND SYNC',
      message:
          'To keep the leaderboard updated while the app is '
          'closed, please allow this app to run in the background.',
      confirmLabel: 'Allow',
    );
    if (confirmed) await Permission.ignoreBatteryOptimizations.request();
  }

  Future<bool> _showPermissionDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Allow',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: AppTextStyles.title(size: 18)),
        content: Text(
          message,
          style: AppTextStyles.copy(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Not Now',
              style: AppTextStyles.body(color: AppColors.error),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
