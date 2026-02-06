import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:test_proj/screens/settings_screen.dart';

import 'package:test_proj/utils/screen_time.dart';
import 'package:test_proj/utils/authentication.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Check if user is in a group
  //TODO: the page does not refresh to show if user is in group or not, app needs to be restarted to update group status
  Future<bool> _isUserInGroup() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    return userDoc.exists && userDoc.data()?['groupId'] != null;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Screentime Leaderboard'),
        backgroundColor: const Color.fromARGB(255, 225, 78, 16),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer),
            tooltip: 'My Screentime',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AppUsageHomePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Authentication.signOut(context: context),
          ),
        ],
      ),
      body: FutureBuilder<bool>(
        future: _isUserInGroup(),
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
                      onPressed: () {
                        // Navigate to settings screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SettingsScreen()),
                        );
                      },
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

                  // Fetch username from users collection
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