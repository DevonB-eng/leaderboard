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
  // Store the future in state so we can refresh it on demand
  late Future<bool> _isInGroupFuture;

  @override
  void initState() {
    super.initState();
    _isInGroupFuture = _isUserInGroup();
        WidgetsBinding.instance.addPostFrameCallback((_) {
      requestPermissions();
    });
  }

  // ===== permissions =====
  // TODO: verify that the permissions are working properly  
  Future<void> requestPermissions() async {
    await requestNotificationPermission();
    await requestUsageStatsPermission();
  }

    // Notification permission — standard runtime dialog on Android 13+
  Future<void> requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      final result = await Permission.notification.request();
      if (result.isPermanentlyDenied && mounted) {
        // User has permanently blocked notifications — direct them to settings
        showPermissionDialog(
          title: 'Notifications Blocked',
          message:
              'Notifications are permanently blocked. Please enable them in your device settings to receive leaderboard updates.',
          onConfirm: () => openAppSettings(),
        );
      }
    }
  }

    // Usage stats permission — special permission that requires the user to
  // manually grant it in system settings, cannot be requested via dialog
  Future<void> requestUsageStatsPermission() async {
    final status = await Permission.appTrackingTransparency.status;
    // app_usage provides its own usage stats check — use it directly
    final hasUsageAccess = await ScreenTimeService.checkUsageStatsGranted();
    if (!hasUsageAccess && mounted) {
      showPermissionDialog(
        title: 'Screen Time Access Required',
        message:
            'This app needs access to your usage stats to track screen time. '
            'Tap "Open Settings", then find this app and toggle on "Permit usage access".',
        onConfirm: () async {
          // Opens the special usage access settings page directly
          await Permission.manageExternalStorage.request();
          openAppSettings();
        },
        confirmLabel: 'Open Settings',
      );
    }
  }

    // Reusable permission explanation dialog
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

  // ===== group shit =====
  // Check if user is in a group
  Future<bool> _isUserInGroup() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    return userDoc.exists && userDoc.data()?['groupId'] != null;
  }

  // Re-run the group check and rebuild the widget
  void _refreshGroupStatus() {
    setState(() {
      _isInGroupFuture = _isUserInGroup();
    });
  }

  // Navigate to a screen and refresh group status when returning
  void _navigateAndRefresh(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    ).then((_) => _refreshGroupStatus());
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Screentime Leaderboard'), // TODO: this text is displayed as "Screentime Leaderboa...", fix it
        backgroundColor: const Color.fromARGB(255, 225, 78, 16),
        actions: [
          IconButton( // I should copy strava and have these buttons on the bottom with their names underneath.
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

      body: FutureBuilder<bool>(
        future: _isInGroupFuture,
        builder: (context, groupSnapshot) {
          if (groupSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final isInGroup = groupSnapshot.data ?? false;

          // If user is NOT in a group, show join/create options
          if (!isInGroup) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.group_off,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Join a group to see the leaderboard!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => _navigateAndRefresh(const SettingsScreen()),
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

          // User IS in a group, show leaderboard
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('leaderboard')
                .orderBy('totalBadMinutes', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text('No users yet. Be the first to upload screentime!'),
                );
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final userId = data['uid'];
                  final totalMinutes = data['totalBadMinutes'] ?? 0;
                  final isCurrentUser = userId == user?.uid;
                  final badAppsData = data['badAppsBreakdown'] as List<dynamic>?;

                  // Get/display usernames instead of emails
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .get(),
                    builder: (context, userSnapshot) {
                      String username = 'Loading...';
                      if (userSnapshot.hasData && userSnapshot.data!.exists) {
                        username = userSnapshot.data!.get('username') ?? 'Anonymous';
                      } else if (userSnapshot.connectionState ==
                          ConnectionState.done) {
                        username = 'Anonymous';
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: isCurrentUser
                                ? Color.fromARGB(255, 225, 78, 16)
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
                              '${totalMinutes.toStringAsFixed(0)} minutes'),
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
                                      final appName = app['appName'] ?? 'Unknown';
                                      final minutes = app['minutes'] ?? 0;
                                      return ListTile(
                                        dense: true,
                                        leading: Icon(Icons.phone_android,
                                            size: 20,
                                            color: Colors.red.shade400),
                                        title: Text(appName,
                                            style: const TextStyle(fontSize: 14)),
                                        trailing: Text(
                                          '${minutes.toStringAsFixed(0)} min',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'No app breakdown available',
                                  style: TextStyle(
                                      color: Colors.grey.shade600, fontSize: 13),
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
          );
        },
      ),
    );
  }
}