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

    await FirebaseFirestore.instance.collection('leaderboard').doc(user.uid).set({
      'uid': user.uid,
      'totalBadMinutes': totalBadMinutes,
      'badAppsBreakdown': badAppsBreakdown,
      'lastUpdated': FieldValue.serverTimestamp(),
      'username': user.email,
    });
  }
}

// class AppUsageHomePage extends StatefulWidget {
//   const AppUsageHomePage({super.key});

//   @override
//   AppUsageHomePageState createState() => AppUsageHomePageState();
// }

// class AppUsageHomePageState extends State<AppUsageHomePage> {
//   List<AppUsageInfo> _badAppInfos = [];
//   bool _isLoading = false;

//   // Maps package name -> display name for all tracked "bad" apps.
//   // Users should be able to modify this in settings but for now it's hardcoded.
//   // TODO: browsers are not grouped on the screentime page, make sure they are grouped on the leaderboard. 
//   final Map<String, String> _badApps = {
//     // social media
//     'com.instagram.android':             'Instagram',
//     'com.facebook.katana':               'Facebook',
//     'com.snapchat.android':              'Snapchat',
//     'com.zhiliaoapp.musically':          'TikTok',
//     'com.twitter.android':               'Twitter',
//     'com.x.android':                     'X',
//     'com.google.android.youtube':        'YouTube',
//     'com.strava':                        'Strava',
//     'com.reddit.frontpage':              'Reddit',
//     'com.linkedin.android':              'LinkedIn',
//     'com.facebook.orca':                 'Messenger',
//     'com.discord':                       'Discord',
//     // browsers — all display as "Browser"
//     'com.android.chrome':                'Browser',
//     'org.mozilla.firefox':               'Browser',
//     'com.microsoft.emmx':                'Browser',
//     'com.opera.browser':                 'Browser',
//     'com.brave.browser':                 'Browser',
//     'com.duckduckgo.mobile.android':     'Browser',
//     'com.google.android.googlequicksearchbox': 'Browser',
//     // dating apps
//     'com.tinder':                        'Tinder',
//     'com.bumble.app':                    'Bumble',
//     'co.hinge.app':                      'Hinge',
//   };

//   // grouping browsers into one "Browser" entry
//   List<MapEntry<String, int>> get _groupedForDisplay {
//     final map = <String, int>{};
//     for (final info in _badAppInfos) {
//       final name = _badApps[info.packageName] ?? info.appName;
//       map[name] = (map[name] ?? 0) + info.usage.inMinutes;
//     }
//     return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
//   }

//   // Static method so home_screen.dart can call it without importing app_usage directly
//   static Future<bool> checkUsageStatsGranted() async {
//     try {
//       final now = DateTime.now();
//       await AppUsage().getAppUsage(
//         now.subtract(const Duration(minutes: 1)),
//         now,
//       );
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   void getUsageStats() async {
//     setState(() => _isLoading = true);

//     try {
//       DateTime now = DateTime.now();
//       DateTime oneDayAgo = now.subtract(const Duration(days: 1));
//       List<AppUsageInfo> usage24h = await AppUsage().getAppUsage(oneDayAgo, now);

//       // Filter bad apps and store raw list (grouping happens at display time)
//       List<AppUsageInfo> badAppUsage = usage24h
//           .where((info) => _badApps.containsKey(info.packageName))
//           .toList();

//       setState(() {
//         _badAppInfos = badAppUsage;
//       });

//       await uploadScreentime(badAppUsage);
//     } catch (exception) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error getting usage stats: $exception')),
//         );
//       }
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> uploadScreentime(List<AppUsageInfo> infoList) async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;

//     double totalBadMinutes = 0;
//     for (var info in infoList) {
//       totalBadMinutes += info.usage.inMinutes;
//     }

//     // Group by display name so all browsers are merged into one "Browser" entry
//     Map<String, double> groupedMinutes = {};
//     for (var info in infoList) {
//       final minutes = info.usage.inMinutes.toDouble();
//       if (minutes > 0) {
//         final displayName = _badApps[info.packageName] ?? info.appName;
//         groupedMinutes[displayName] = (groupedMinutes[displayName] ?? 0) + minutes;
//       }
//     }

//     List<Map<String, dynamic>> badAppsBreakdown = groupedMinutes.entries
//         .map((e) => {'appName': e.key, 'minutes': e.value})
//         .toList();
//     badAppsBreakdown.sort((a, b) => (b['minutes'] as double).compareTo(a['minutes'] as double));

//     await FirebaseFirestore.instance
//         .collection('leaderboard')
//         .doc(user.uid)
//         .set({
//       'uid': user.uid,
//       'totalBadMinutes': totalBadMinutes,
//       'badAppsBreakdown': badAppsBreakdown,
//       'lastUpdated': FieldValue.serverTimestamp(),
//       'username': user.email,
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final grouped = _groupedForDisplay;
//     final totalMinutes = grouped.fold<int>(0, (sum, e) => sum + e.value);
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('My Screentime'),
//         backgroundColor: Colors.green,
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : _badAppInfos.isEmpty
//               ? Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: const [
//                       Icon(Icons.phone_android, size: 64, color: Colors.grey),
//                       SizedBox(height: 16),
//                       Text('No data yet. Tap refresh to load screentime.'),
//                     ],
//                   ),
//                 )
//               : ListView(
//                   children: [
//                     ExpansionTile(
//                       leading: const Icon(Icons.warning, color: Colors.red, size: 20),
//                       title: Text(
//                         'Total "Bad" Screentime: $totalMinutes minutes',
//                         style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                       ),
//                       initiallyExpanded: false,
//                       children: grouped.map((e) => _buildAppTile(e.key, e.value)).toList(),
//                     ),
//                     const SizedBox(height: 80),
//                   ],
//                 ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _isLoading ? null : getUsageStats,
//         backgroundColor: _isLoading ? Colors.grey : Colors.green,
//         child: _isLoading
//             ? const SizedBox(
//                 width: 24,
//                 height: 24,
//                 child: CircularProgressIndicator(
//                   color: Colors.white,
//                   strokeWidth: 2,
//                 ),
//               )
//             : const Icon(Icons.refresh),
//       ),
//     );
//   }

//   String _formatDuration(Duration duration) {
//     final hours = duration.inHours;
//     final minutes = duration.inMinutes % 60;
//     if (hours > 0) {
//       return '${hours}h ${minutes}m';
//     }
//     return '${minutes}m';
//   }

//   Widget _buildAppTile(String name, int minutes) {
//     return ListTile(
//       dense: true,
//       visualDensity: VisualDensity.compact,
//       leading: const Icon(Icons.phone_android, color: Colors.red),
//       title: Text(name),
//       subtitle: Text(_formatDuration(Duration(minutes: minutes))),
//       trailing: Text(
//         '$minutes min',
//         style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
//       ),
//     );
//   }
// }
