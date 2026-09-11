import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/data/repositories/screentime_repository.dart';

class PermissionsService {
  Future<void> requestAll(BuildContext context) async {
    await requestUsageStatsPermission(context);
    await requestNotificationPermission(context);
    await requestBatteryOptimizationExemption(context);
  }

  Future<void> requestUsageStatsPermission(BuildContext context) async {
    final hasUsageAccess = await ScreentimeRepository.checkUsageStatsGranted();
    if (!hasUsageAccess && context.mounted) {
      final confirmed = await _showPermissionDialog(
        context: context,
        title: 'SCREEN TIME ACCESS',
        message:
            'This app needs access to your usage stats to track '
            'screen time. Tap "Open Settings", find this app, '
            'and toggle on "Permit usage access".',
        confirmLabel: 'Open Settings',
      );
      if (confirmed) await openAppSettings();
    }
  }

  Future<void> requestNotificationPermission(BuildContext context) async {
    final status = await Permission.notification.status;
    if (status.isDenied && context.mounted) {
      final confirmed = await _showPermissionDialog(
        context: context,
        title: 'NOTIFICATIONS',
        message:
            'Enable notifications to get leaderboard updates '
            'even when the app is closed.',
        confirmLabel: 'Allow',
      );
      if (confirmed) await Permission.notification.request();
    } else if (status.isPermanentlyDenied && context.mounted) {
      final confirmed = await _showPermissionDialog(
        context: context,
        title: 'NOTIFICATIONS BLOCKED',
        message:
            'Notifications are permanently blocked. Enable them '
            'in your device settings to receive leaderboard updates.',
        confirmLabel: 'Open Settings',
      );
      if (confirmed) await openAppSettings();
    }
  }

  Future<void> requestBatteryOptimizationExemption(BuildContext context) async {
    if (await Permission.ignoreBatteryOptimizations.isDenied &&
        context.mounted) {
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
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorders.radius,
          side: AppBorders.thin,
        ),
        title: Text(title, style: AppTextStyles.heading()),
        content: Text(
          message,
          style: AppTextStyles.body(color: AppColors.textSecondary),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: Text(confirmLabel, style: AppTextStyles.body()),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
