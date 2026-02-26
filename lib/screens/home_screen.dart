import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:leaderboard/screens/settings_screen.dart';
import 'package:leaderboard/screens/user_stats_screen.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:leaderboard/utils/screen_time.dart';
import 'package:leaderboard/utils/authentication.dart';

/*
home_screen.dart - the main homepage
- displays leaderboard if user is in a group, otherwise prompts user to join or create a group
- has buttons to navigate to settings page, my screentime page, and to sign out
*/
// TODO: I bet this whole page could be more modular and readable. I should fix that
// TODO: add permissions requests for screen time, notifications, etc.

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  // Group state
  String? _groupId;
  late Future<String?> _groupFuture;

  // Leaderboard state
  Future<DocumentSnapshot>? _leaderboardFuture;

  // 30-min upload + refresh timer
  Timer? _syncTimer;

  final _service = ScreenTimeService();

  @override
  void initState() {
    super.initState();
    _groupFuture = _fetchGroupId();
    _groupFuture.then((groupId) {
      if (groupId != null && mounted) {
        setState(() {
          _groupId = groupId;
          _leaderboardFuture = _fetchLeaderboard(groupId);
        });
        _startSyncTimer();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestPermissions();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  // ===== sync timer =====

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _uploadAndRefresh();
    });
  }

  Future<void> _uploadAndRefresh() async {
    if (_groupId == null) return;
    try {
      final badAppUsage = await _service.fetchBadAppUsage();
      await _service.uploadScreentime(badAppUsage);
    } catch (e) {
      debugPrint('Screentime upload error: $e');
    }
    if (mounted) {
      setState(() {
        _leaderboardFuture = _fetchLeaderboard(_groupId!);
      });
    }
  }

  // ===== firebase fetches =====

  // Returns groupId string if user is in a group, null otherwise
  Future<String?> _fetchGroupId() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final groupId = userDoc.data()?['groupId'] as String?;
    return groupId;
  }

  // Reads the single pre-aggregated leaderboard doc for this group
  Future<DocumentSnapshot> _fetchLeaderboard(String groupId) {
    return FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('leaderboard')
        .doc('current')
        .get();
  }

  // ===== navigation =====

  void _refreshGroupStatus() {
    setState(() {
      _groupFuture = _fetchGroupId();
    });
    _groupFuture.then((groupId) {
      if (!mounted) return;
      setState(() {
        _groupId = groupId;
        _leaderboardFuture =
            groupId != null ? _fetchLeaderboard(groupId) : null;
      });
      if (groupId != null) _startSyncTimer();
    });
  }

  void _navigateAndRefresh(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    ).then((_) => _refreshGroupStatus());
  }

  // ===== permissions (unchanged) =====

  Future<void> requestPermissions() async {
    await requestNotificationPermission();
    await requestUsageStatsPermission();
  }

  Future<void> requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      final result = await Permission.notification.request();
      if (result.isPermanentlyDenied && mounted) {
        showPermissionDialog(
          title: 'Notifications Blocked',
          message:
              'Notifications are permanently blocked. Please enable them in your device settings to receive leaderboard updates.',
          onConfirm: () => openAppSettings(),
        );
      }
    }
  }

  Future<void> requestUsageStatsPermission() async {
    final hasUsageAccess = await ScreenTimeService.checkUsageStatsGranted();
    if (!hasUsageAccess && mounted) {
      showPermissionDialog(
        title: 'Screen Time Access Required',
        message:
            'This app needs access to your usage stats to track screen time. '
            'Tap "Open Settings", then find this app and toggle on "Permit usage access".',
        onConfirm: () async {
          await Permission.manageExternalStorage.request();
          openAppSettings();
        },
        confirmLabel: 'Open Settings',
      );
    }
  }

  void showPermissionDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
    String confirmLabel = 'Allow',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 225, 78, 16),
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  // ===== build =====

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screentime Leaderboard'),
        backgroundColor: const Color.fromARGB(255, 225, 78, 16),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _uploadAndRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.timer),
            tooltip: 'My Screentime',
            onPressed: () => _navigateAndRefresh(const UserStatsPage()),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _navigateAndRefresh(const SettingsScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Authentication.signOut(context: context),
          ),
        ],
      ),
      body: FutureBuilder<String?>(
        future: _groupFuture,
        builder: (context, groupSnapshot) {
          if (groupSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final groupId = groupSnapshot.data;

          // Not in a group — show join/create prompt (unchanged)
          if (groupId == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.group_off, size: 80, color: Colors.grey),
                    const SizedBox(height: 24),
                    const Text(
                      'Join a group to see the leaderboard!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _navigateAndRefresh(const SettingsScreen()),
                      icon: const Icon(Icons.group_add),
                      label: const Text('Join or Create Group'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: const Color.fromARGB(255, 225, 78, 16),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // In a group — show leaderboard
          return FutureBuilder<DocumentSnapshot>(
            future: _leaderboardFuture,
            builder: (context, lbSnapshot) {
              if (lbSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (lbSnapshot.hasError) {
                return Center(child: Text('Error: ${lbSnapshot.error}'));
              }

              final data =
                  lbSnapshot.data?.data() as Map<String, dynamic>?;
              final entries =
                  (data?['entries'] as List<dynamic>?) ?? [];

              if (entries.isEmpty) {
                return const Center(
                  child: Text(
                      'No data yet — tap refresh to upload your screentime!'),
                );
              }

              return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index] as Map<String, dynamic>;
                  final uid = entry['uid'];
                  final username = entry['username'] ?? 'Anonymous';
                  final totalMinutes = entry['totalBadMinutes'] ?? 0;
                  final isCurrentUser = uid == user?.uid;
                  final badAppsData =
                      entry['badAppsBreakdown'] as List<dynamic>?;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: isCurrentUser
                            ? const Color.fromARGB(255, 225, 78, 16)
                            : Colors.grey,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(
                        username,
                        style: TextStyle(
                          fontWeight: isCurrentUser
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                          '${(totalMinutes as num).toStringAsFixed(0)} minutes'),
                      trailing: isCurrentUser
                          ? const Icon(Icons.person,
                              color: Color.fromARGB(255, 225, 78, 16))
                          : null,
                      children: [
                        if (badAppsData != null && badAppsData.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Text(
                                    'App Breakdown:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                ...badAppsData.map((app) {
                                  final appMap =
                                      app as Map<String, dynamic>;
                                  final appName =
                                      appMap['appName'] ?? 'Unknown';
                                  final minutes = appMap['minutes'] ?? 0;
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(Icons.phone_android,
                                        size: 20,
                                        color: Colors.red.shade400),
                                    title: Text(appName,
                                        style:
                                            const TextStyle(fontSize: 14)),
                                    trailing: Text(
                                      '${(minutes as num).toStringAsFixed(0)} min',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No app breakdown available',
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}