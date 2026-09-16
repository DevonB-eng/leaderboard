import 'package:flutter/services.dart';

/// Android usage-stats access.
///
/// Registered via GeneratedPluginRegistrant, so — unlike a channel wired up in
/// MainActivity — this is reachable from background isolates (workmanager) as
/// well as the foreground engine.
///
/// Every method throws [MissingPluginException] on platforms without an
/// implementation, iOS included. Callers are expected to treat that as "usage
/// is unknown" rather than as zero usage.
class UsageStats {
  const UsageStats._();

  static const _channel = MethodChannel('leaderboard/usage_access');

  /// Whether the user has granted "Permit usage access".
  ///
  /// Reads the app-ops entry directly, so asking has no side effects — notably
  /// it will not send the user to Settings on its own.
  static Future<bool> isGranted() async {
    return await _channel.invokeMethod<bool>('isGranted') ?? false;
  }

  /// Opens the OS "Usage access" settings list.
  static Future<void> openSettings() {
    return _channel.invokeMethod<void>('openSettings');
  }

  /// Foreground milliseconds per package between [from] and [to], with every
  /// session clipped to that range so a window never reports time from outside
  /// it.
  static Future<Map<String, int>?> foregroundMillis(
    DateTime from,
    DateTime to,
  ) {
    return _channel.invokeMapMethod<String, int>('getUsage', {
      'start': from.millisecondsSinceEpoch,
      'end': to.millisecondsSinceEpoch,
    });
  }
}
