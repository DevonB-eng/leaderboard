import 'package:flutter/material.dart';
import 'package:app_usage/app_usage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/*
screen_time.dart - pulls screentime data from "bad apps" and uploades to firestone
- get screentime data for the past 24 hours (maybe add weekly later for reports and whatnot)
*/ 
// TODO: update the ios folder to pull the same screentime data (do I need a new package?)
// - pretty sure that this whole file is gonna have to be rewritten for ios but whateva
class AppUsageHomePage extends StatefulWidget {
  const AppUsageHomePage({super.key});

  @override
  AppUsageHomePageState createState() => AppUsageHomePageState();
}

class AppUsageHomePageState extends State<AppUsageHomePage> {
  List<AppUsageInfo> _infos = [];
  bool _isLoading = false;

  // List of "bad" apps to track - users should be able to modify this in settings but for now I'm hardcoding it
  final Set<String> _badApps = {
    'instagram',
    'facebook',
    'snapchat',
    'tiktok',
    'twitter',
    'x',
    'youtube',
    'strava',
    'reddit',
    'yik yak',
    'chess',
    'messenger',
    'browser',
    'discord'
  };

  bool _isBadApp(String appName) {
    final lowerName = appName.toLowerCase();
    return _badApps.any((badApp) => lowerName.contains(badApp));
  }

  void getUsageStats() async {
    setState(() => _isLoading = true);

    try {
      DateTime now = DateTime.now();
      DateTime oneDayAgo = now.subtract(const Duration(days: 1));
      List<AppUsageInfo> usage24h = await AppUsage().getAppUsage(oneDayAgo, now);

      // Filter to only bad apps
      List<AppUsageInfo> badAppUsage = usage24h
          .where((info) => _isBadApp(info.appName))
          .toList();

      badAppUsage.sort((a, b) => b.usage.compareTo(a.usage)); // Most used first

      setState(() => _infos = badAppUsage);
      await uploadScreentime(badAppUsage);
    } catch (exception) {
      print('Error getting usage stats: $exception');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $exception')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> uploadScreentime(List<AppUsageInfo> infoList) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Calculate total bad minutes
    double totalBadMinutes = 0;
    for (var info in infoList) {
      totalBadMinutes += info.usage.inMinutes;
    }

    // Create list of bad apps with their usage time
    List<Map<String, dynamic>> badAppsBreakdown = [];
    for (var info in infoList) {
      final minutes = info.usage.inMinutes.toDouble();
      if (minutes > 0) {
        badAppsBreakdown.add({
          'appName': info.appName,
          'minutes': minutes,
        });
        print("${info.appName}: ${minutes.toStringAsFixed(0)} minutes");
      }
    }

    // Write to Firestore
    await FirebaseFirestore.instance
        .collection('leaderboard')
        .doc(user.uid)
        .set({
      'uid': user.uid,
      'totalBadMinutes': totalBadMinutes,
      'badAppsBreakdown': badAppsBreakdown,
      'lastUpdated': FieldValue.serverTimestamp(),
      'username': user.email, 
    });

    print("Data synced to Firebase! Total bad minutes: $totalBadMinutes");
  }
  
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text('My Screentime'),
        backgroundColor: Colors.green,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _infos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_android, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No data yet. Tap refresh to load screentime.'),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildSummaryCard(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _infos.length,
                        itemBuilder: (context, index) {
                          final info = _infos[index];
                          return ListTile(
                            leading: Icon(Icons.phone_android, color: Colors.red),
                            title: Text(info.appName),
                            subtitle: Text(
                              "Usage: ${_formatDuration(info.usage)}",
                            ),
                            trailing: Text(
                              "${info.usage.inMinutes} min",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : getUsageStats,
        backgroundColor: _isLoading ? Colors.grey : Colors.green,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalMinutes = _infos.fold<int>(
      0,
      (sum, info) => sum + info.usage.inMinutes,
    );

    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total "Bad" Screentime',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
                SizedBox(height: 4),
                Text(
                  _formatDuration(Duration(minutes: totalMinutes)),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            Icon(Icons.warning, size: 48, color: Colors.red.shade300),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}