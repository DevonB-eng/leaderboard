import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:leaderboard/utils/screen_time.dart';
import 'package:leaderboard/utils/authentication.dart';
import 'package:leaderboard/screens/home_screen.dart';

/*
settings_screen.dart - the settings page for the app
- group settings (join/create/leave group & choose bad apps) 
- personal settings (placeholder for now)
*/

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  bool isInGroup = false;
  String? currentGroupId;
  String? currentGroupName;

  @override
  void initState() {
    super.initState();
    checkUserGroupStatus();
  }

  // Check if user is already in a group
  Future<void> checkUserGroupStatus() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (userDoc.exists && userDoc.data()?['groupId'] != null) {
      final groupId = userDoc.data()!['groupId'];
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .get();

      setState(() {
        isInGroup = true;
        currentGroupId = groupId;
        currentGroupName = groupDoc.data()?['name'] ?? 'Unknown Group';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
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
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Authentication.signOut(context: context),
          ),
        ],
      ),
      body: ListView(
        children: [
          groupSettingsPage(),
          const Divider(),
          personalSettingsPage(),
        ],
      ),
    );
  }
  
/* ===== group settings ===== */
  Widget groupSettingsPage() {
    return ExpansionTile(
      title: const Text('Group Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: isInGroup ? inGroupOptions() : notInGroupOptions(),
        ),
      ],
    );
  }

  Widget notInGroupOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: joinGroup,
          icon: const Icon(Icons.group_add),
          label: const Text('Join Group'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: createGroup,
          icon: const Icon(Icons.group_add),
          label: const Text('Create Group'),
        ),
      ],
    );
  }

  void joinGroup() {
    final searchController = TextEditingController();
    List<QueryDocumentSnapshot> searchResults = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Join Group'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search for groups',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) async {
                    // Search groups by name
                    if (value.isNotEmpty) {
                      final results = await FirebaseFirestore.instance
                          .collection('groups')
                          .where('name', isGreaterThanOrEqualTo: value)
                          .where('name', isLessThanOrEqualTo: '$value\uf8ff')
                          .get();
                      setDialogState(() {
                        searchResults = results.docs;
                      });
                    } else {
                      setDialogState(() {
                        searchResults = [];
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: searchResults.isEmpty
                      ? const Center(child: Text('Search for a group'))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final group = searchResults[index];
                            return ListTile(
                              leading: const Icon(Icons.group),
                              title: Text(group['name']),
                              subtitle: Text('${group['memberIds'].length} members'),
                              onTap: () {
                                Navigator.pop(context);
                                showPasswordDialog(group.id, group['name']);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  void showPasswordDialog(String groupId, String groupName) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Join $groupName'),
        content: TextField(
          controller: passwordController,
          decoration: const InputDecoration(
            labelText: 'Enter group password',
            prefixIcon: Icon(Icons.lock),
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Verify password and join group
              final groupDoc = await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(groupId)
                  .get();

              if (groupDoc.data()?['password'] == passwordController.text) {
                final userId = FirebaseAuth.instance.currentUser!.uid;

                // Add user to group's memberIds
                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(groupId)
                    .update({
                  'memberIds': FieldValue.arrayUnion([userId]),
                });

                // Update user's document with groupId
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .set({'groupId': groupId}, SetOptions(merge: true));

                Navigator.pop(context);
                setState(() {
                  isInGroup = true;
                  currentGroupId = groupId;
                  currentGroupName = groupName;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Joined $groupName')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect password')),
                );
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void createGroup() async {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                prefixIcon: Icon(Icons.group),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Group Password',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              final userId = FirebaseAuth.instance.currentUser!.uid;
              final groupRef = FirebaseFirestore.instance.collection('groups').doc();

              // Create the group
              await groupRef.set({
                'name': nameController.text,
                'password': passwordController.text,
                'memberIds': [userId],
                'createdAt': FieldValue.serverTimestamp(),
                'createdBy': userId,
              });

              // Update user's document with groupId
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .set({'groupId': groupRef.id}, SetOptions(merge: true));

              Navigator.pop(context);
              setState(() {
                isInGroup = true;
                currentGroupId = groupRef.id;
                currentGroupName = nameController.text;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Created group: ${nameController.text}')),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget inGroupOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (currentGroupName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              'Current Group: $currentGroupName',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        ElevatedButton.icon(
          onPressed: leaveGroup,
          icon: const Icon(Icons.exit_to_app),
          label: const Text('Leave Group'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
  
  void leaveGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final userId = FirebaseAuth.instance.currentUser!.uid;

              // Remove user from group's memberIds
              await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(currentGroupId)
                  .update({
                'memberIds': FieldValue.arrayRemove([userId]),
              });

              // Remove groupId from user's document
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .update({'groupId': FieldValue.delete()});

              Navigator.pop(context);
              setState(() {
                isInGroup = false;
                currentGroupId = null;
                currentGroupName = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Left the group')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

/* ===== personal settings ===== */
  Widget personalSettingsPage() {
    return ExpansionTile(
      title: const Text(
        'Personal Settings',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Personal settings will be added here',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

}