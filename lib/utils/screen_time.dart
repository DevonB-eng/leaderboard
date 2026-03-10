import 'package:app_usage/app_usage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/*
screen_time.dart - service class for screentime data
- fetches and filters bad app usage from the OS
- groups apps by display name (e.g. merges all browsers)
- uploads results to firestore
*/
// TODO: update all of this for ios (later me problem)
// - pretty sure that this whole file is gonna have to be rewritten for ios but whateva
class ScreenTimeService {
  static const Map<String, String> badApps = {
    // social media
    'com.instagram.android':             'Instagram',
    'com.facebook.katana':               'Facebook',
    'com.snapchat.android':              'Snapchat',
    'com.zhiliaoapp.musically':          'TikTok',
    'com.twitter.android':               'Twitter',
    'com.x.android':                     'X',
    'com.google.android.youtube':        'YouTube',
    'com.strava':                        'Strava',
    'com.reddit.frontpage':              'Reddit',
    'com.linkedin.android':              'LinkedIn',
    'com.facebook.orca':                 'Messenger',
    'com.discord':                       'Discord',
    // browsers — all display as "Browser"
    'com.android.chrome':                'Browser',
    'org.mozilla.firefox':               'Browser',
    'com.microsoft.emmx':                'Browser',
    'com.opera.browser':                 'Browser',
    'com.brave.browser':                 'Browser',
    'com.duckduckgo.mobile.android':     'Browser',
    'com.google.android.googlequicksearchbox': 'Browser',
    // dating apps
    'com.tinder':                        'Tinder',
    'com.bumble.app':                    'Bumble',
    'co.hinge.app':                      'Hinge',
  };

  // Static method so home_screen.dart can call it without instantiating the service
  static Future<bool> checkUsageStatsGranted() async {
    try {
      final now = DateTime.now();
      await AppUsage().getAppUsage(now.subtract(const Duration(minutes: 1)), now);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Fetches the last 24h of usage and returns only bad apps (raw, ungrouped)
// Reverted — just fetch the raw 24h rolling window from the OS
Future<Map<String, int>> fetchBadAppUsage() async {
  final now = DateTime.now();
  final oneDayAgo = now.subtract(const Duration(days: 1));
  final usage = await AppUsage().getAppUsage(oneDayAgo, now);
  final map = <String, int>{};
  for (final info in usage) {
    if (badApps.containsKey(info.packageName)) {
      map[info.packageName] = info.usage.inMinutes;
    }
  }
  return map;
}

List<MapEntry<String, int>> groupForDisplay(Map<String, int> packageMap) {
  final map = <String, int>{};
  for (final entry in packageMap.entries) {
    final name = badApps[entry.key] ?? entry.key;
    map[name] = (map[name] ?? 0) + entry.value;
  }
  return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

Future<void> uploadScreentime(Map<String, int> packageMap) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // Group raw OS values by display name
  final grouped = groupForDisplay(packageMap);

  // Read yesterday's stored breakdown from Firestore history
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));
  final dateKey = '${yesterday.year}-'
      '${yesterday.month.toString().padLeft(2, '0')}-'
      '${yesterday.day.toString().padLeft(2, '0')}';

  final yesterdayMap = <String, int>{};
  try {
    final histDoc = await FirebaseFirestore.instance
        .collection('screentime')
        .doc(user.uid)
        .collection('history')
        .doc(dateKey)
        .get();
    if (histDoc.exists) {
      final breakdown = histDoc.data()?['badAppsBreakdown'] as List<dynamic>?;
      if (breakdown != null) {
        for (final item in breakdown) {
          yesterdayMap[item['appName'] as String] =
              (item['minutes'] as num).toInt();
        }
      }
    }
  } catch (_) {
    // If history read fails, proceed with raw values — self-heals next run
  }

  // Net today = 24h rolling OS value minus yesterday's stored daily total
  final netGrouped = <MapEntry<String, int>>[];
  for (final entry in grouped) {
    final net = entry.value - (yesterdayMap[entry.key] ?? 0);
    if (net > 0) netGrouped.add(MapEntry(entry.key, net));
  }

  final totalBadMinutes =
      netGrouped.fold<double>(0, (sum, e) => sum + e.value);
  final badAppsBreakdown = netGrouped
      .map((e) => {'appName': e.key, 'minutes': e.value.toDouble()})
      .toList();

  await FirebaseFirestore.instance.collection('screentime').doc(user.uid).set({
    'uid': user.uid,
    'totalBadMinutes': totalBadMinutes,
    'badAppsBreakdown': badAppsBreakdown,
    'lastUpdated': FieldValue.serverTimestamp(),
  });
}
}