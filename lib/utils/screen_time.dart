import 'package:flutter/material.dart';
import 'package:app_usage/app_usage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/*
screen_time.dart - service class for screentime data
- fetches and filters bad app usage from the OS
- groups apps by display name (e.g. merges all browsers)
- uploads results to firestore
*/
// TODO: update the ios folder to pull the same screentime data (do I need a new package?)
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
  Future<List<AppUsageInfo>> fetchBadAppUsage() async {
    final now = DateTime.now();
    final oneDayAgo = now.subtract(const Duration(days: 1));
    final usage24h = await AppUsage().getAppUsage(oneDayAgo, now);
    return usage24h.where((info) => badApps.containsKey(info.packageName)).toList();
  }

  // Groups a raw bad-app list by display name and returns sorted by minutes descending.
  // This ensures e.g. multiple browsers are merged into a single "Browser" entry.
  List<MapEntry<String, int>> groupForDisplay(List<AppUsageInfo> infoList) {
    final map = <String, int>{};
    for (final info in infoList) {
      final name = badApps[info.packageName] ?? info.appName;
      map[name] = (map[name] ?? 0) + info.usage.inMinutes;
    }
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  // Uploads grouped screentime data to Firestore
  Future<void> uploadScreentime(List<AppUsageInfo> infoList) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    double totalBadMinutes = 0;
    for (var info in infoList) {
      totalBadMinutes += info.usage.inMinutes;
    }

    final grouped = groupForDisplay(infoList);
    final badAppsBreakdown = grouped
        .map((e) => {'appName': e.key, 'minutes': e.value.toDouble()})
        .toList();

    await FirebaseFirestore.instance.collection('screentime').doc(user.uid).set({
      'uid': user.uid,
      'totalBadMinutes': totalBadMinutes,
      'badAppsBreakdown': badAppsBreakdown,
      'lastUpdated': FieldValue.serverTimestamp(),
      'username': user.email,
    });
  }
}