import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:leaderboard/screens/user_stats_screen.dart';

import 'package:leaderboard/utils/authentication.dart';
import 'package:leaderboard/utils/screen_time.dart';
import 'package:leaderboard/screens/home_screen.dart';

/*
settings_screen.dart - the settings page for the app
- group settings (join/create/leave group, view members, vote on bad apps)
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

  List<String> _memberUsernames = [];
  List<String> _memberIds = [];
  bool _loadingMembers = false;

  // appVotes mirrors the group doc's appVotes map.
  // Key = display name (e.g. "Instagram"), value = list of uids who voted to keep it.
  Map<String, List<String>> _appVotes = {};

  // Deduplicated, sorted display names from the hardcoded bad apps map
  final List<String> _badAppDisplayNames = ScreenTimeService.badApps.values
      .toSet()
      .toList()
    ..sort();

  @override
  void initState() {
    super.initState();
    checkUserGroupStatus();
  }

  Future<void> checkUserGroupStatus() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
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

        final groupData = groupDoc.data()!;

        // Parse appVotes from the group doc.
        // Cast carefully — Firestore returns List<dynamic> not List<String>.
        final rawVotes = groupData['appVotes'] as Map<String, dynamic>? ?? {};
        final parsedVotes = rawVotes.map((app, voters) =>
            MapEntry(app, List<String>.from(voters as List)));

        setState(() {
          isInGroup = true;
          currentGroupId = groupId;
          currentGroupName = groupData['name'] ?? 'Unknown Group';
          _appVotes = parsedVotes;
        });

        await _fetchMemberUsernames(
          List<String>.from(groupData['memberIds'] ?? []),
        );
      }
    } catch (e) {
      debugPrint('Error checking group status: $e');
    }
  }

  Future<void> _fetchMemberUsernames(List<String> memberIds) async {
    if (memberIds.isEmpty) return;
      setState(() {
        _loadingMembers = true;
        _memberIds = memberIds; // store ids here
      });
    try {
      final userDocs = await Future.wait(
        memberIds.map((uid) =>
            FirebaseFirestore.instance.collection('users').doc(uid).get()),
      );
      setState(() {
        _memberUsernames = userDocs.map((doc) {
          return doc.exists
              ? (doc.data()?['username'] ?? 'Unknown') as String
              : 'Unknown';
        }).toList();
      });
    } catch (e) {
      debugPrint('Error fetching member usernames: $e');
    } finally {
      setState(() => _loadingMembers = false);
    }
  }

  // Returns true if the current user has voted to keep this app.
  // Defaults to true if the app has no votes yet (default on behavior).
  bool _isVotedByCurrentUser(String appName) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    if (!_appVotes.containsKey(appName)) return true; // default on
    return _appVotes[appName]!.contains(uid);
  }

  // Returns X/Y string for an app — X = current vote count, Y = total members
  String _voteCount(String appName) {
    final totalMembers = _memberUsernames.length;
    if (!_appVotes.containsKey(appName)) {
      // No votes recorded yet — treat as if all members voted for it
      return '$totalMembers/$totalMembers';
    }
    final voteCount = _appVotes[appName]!.length;
    return '$voteCount/$totalMembers';
  }

  // Toggles the current user's vote for an app and writes to Firestore
 Future<void> _toggleVote(String appName) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || currentGroupId == null) return;

  final hasEntry = _appVotes.containsKey(appName);
  final currentlyVoted = _isVotedByCurrentUser(appName);

  // If no Firestore entry exists yet, the "real" starting state is
  // all members voted. Initialize locally with all member ids first.
  final initialList = hasEntry
      ? List<String>.from(_appVotes[appName]!)
      : List<String>.from(_memberIds);

  // Optimistic local update
  setState(() {
    final updated = List<String>.from(initialList);
    if (currentlyVoted) {
      updated.remove(uid);
    } else {
      if (!updated.contains(uid)) updated.add(uid);
    }
    _appVotes[appName] = updated;
  });

  try {
    if (!hasEntry) {
      // First time this app is being touched — write the full initialized
      // list minus/plus the current user rather than using arrayUnion/Remove
      // on a non-existent field, which would give us an incomplete list.
      final initialized = List<String>.from(_memberIds);
      if (currentlyVoted) {
        initialized.remove(uid);
      } else {
        if (!initialized.contains(uid)) initialized.add(uid);
      }
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(currentGroupId)
          .update({'appVotes.$appName': initialized});
    } else {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(currentGroupId)
          .update({
        'appVotes.$appName': currentlyVoted
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
      });
    }
  } catch (e) {
    // Roll back optimistic update on failure
    debugPrint('Error updating vote: $e');
    setState(() {
      _appVotes[appName] = List<String>.from(initialList);
    });
    if (mounted) {
      await Authentication.showErrorDialog(
        context: context,
        message: 'Failed to update vote. Please try again.',
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color.fromARGB(255, 225, 78, 16),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer),
            tooltip: 'My Screentime',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserStatsPage()),
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
          const Divider(), 
          aboutPage(), 
        ],
      ),
    );
  }

  /* ===== group settings ===== */
  Widget groupSettingsPage() {
    return ExpansionTile(
      title: const Text(
        'Group Settings',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
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

  Widget inGroupOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        // ===== group name =====
        Row(
          children: [
            const Icon(Icons.group, color: Color.fromARGB(255, 225, 78, 16)),
            const SizedBox(width: 10),
            Text(
              currentGroupName ?? 'Unknown Group',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ===== members dropdown =====
        ExpansionTile(
          leading: const Icon(Icons.people),
          title: const Text('Members'),
          subtitle: Text(
            _loadingMembers
                ? 'Loading...'
                : '${_memberUsernames.length} member${_memberUsernames.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 12),
          ),
          children: _loadingMembers
              ? [const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                )]
              : _memberUsernames.isEmpty
                  ? [const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No members found.'),
                    )]
                  : _memberUsernames.map((username) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.person, color: Colors.grey),
                        title: Text(username),
                      );
                    }).toList(),
        ),

        const SizedBox(height: 8),

        // ===== bad apps voting dropdown =====
        ExpansionTile(
          leading: const Icon(Icons.phone_android, color: Colors.red),
          title: const Text('Tracked Bad Apps'),
          subtitle: const Text(
            'Check to vote for an app to be tracked',
            style: TextStyle(fontSize: 12),
          ),
          children: [
            // Header row explaining the X/Y column
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'App',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey),
                    ),
                  ),
                  Text(
                    'Votes',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey.shade500),
                  ),
                  const SizedBox(width: 48), // aligns with checkbox width
                ],
              ),
            ),
            ..._badAppDisplayNames.map((appName) {
              final voted = _isVotedByCurrentUser(appName);
              final voteStr = _voteCount(appName);

              return ListTile(
                dense: true,
                leading: const Icon(Icons.block, size: 18, color: Colors.red),
                title: Text(appName, style: const TextStyle(fontSize: 14)),
                // X/Y vote count sits between the title and checkbox
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      voteStr,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Checkbox(
                      value: voted,
                      activeColor: const Color.fromARGB(255, 225, 78, 16),
                      onChanged: (_) => _toggleVote(appName),
                    ),
                  ],
                ),
              );
            }),
            // Small note explaining the 50% threshold
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'An app is tracked when more than 50% of members vote for it.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ===== leave group button =====
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

  /* ===== join / create / leave (unchanged) ===== */

  void joinGroup() {
    final searchController = TextEditingController();
    List<QueryDocumentSnapshot> searchResults = [];
    final scaffoldContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
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
                    if (value.isNotEmpty) {
                      try {
                        final results = await FirebaseFirestore.instance
                            .collection('groups')
                            .where('name', isGreaterThanOrEqualTo: value)
                            .where('name',
                                isLessThanOrEqualTo: '$value\uf8ff')
                            .get();
                        setDialogState(() => searchResults = results.docs);
                      } catch (e) {
                        await Authentication.showErrorDialog(
                          context: dialogContext,
                          message: 'Error searching for groups: $e',
                        );
                      }
                    } else {
                      setDialogState(() => searchResults = []);
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
                              subtitle: Text(
                                  '${group['memberIds'].length} members'),
                              onTap: () {
                                Navigator.pop(dialogContext);
                                showPasswordDialog(
                                    scaffoldContext, group.id, group['name']);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  void showPasswordDialog(
      BuildContext scaffoldContext, String groupId, String groupName) {
    final passwordController = TextEditingController();

    showDialog(
      context: scaffoldContext,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final groupDoc = await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(groupId)
                    .get();

                if (groupDoc.data()?['password'] == passwordController.text) {
                  final userId = FirebaseAuth.instance.currentUser!.uid;

                  await FirebaseFirestore.instance
                      .collection('groups')
                      .doc(groupId)
                      .update({
                    'memberIds': FieldValue.arrayUnion([userId]),
                  });

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .set({'groupId': groupId}, SetOptions(merge: true));

                  Navigator.pop(dialogContext);
                  setState(() {
                    isInGroup = true;
                    currentGroupId = groupId;
                    currentGroupName = groupName;
                  });
                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                    SnackBar(content: Text('Joined $groupName')),
                  );
                } else {
                  await Authentication.showErrorDialog(
                    context: dialogContext,
                    message: 'Incorrect password.',
                  );
                }
              } catch (e) {
                Navigator.pop(dialogContext);
                await Authentication.showErrorDialog(
                  context: scaffoldContext,
                  message: 'Error joining group: $e',
                );
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void createGroup() {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    final scaffoldContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  passwordController.text.isEmpty) {
                await Authentication.showErrorDialog(
                  context: dialogContext,
                  message: 'Please fill in all fields.',
                );
                return;
              }

              try {
                final userId = FirebaseAuth.instance.currentUser!.uid;
                final groupRef =
                    FirebaseFirestore.instance.collection('groups').doc();

                await groupRef.set({
                  'name': nameController.text,
                  'password': passwordController.text,
                  'memberIds': [userId],
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdBy': userId,
                });

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .set({'groupId': groupRef.id}, SetOptions(merge: true));

                Navigator.pop(dialogContext);
                setState(() {
                  isInGroup = true;
                  currentGroupId = groupRef.id;
                  currentGroupName = nameController.text;
                });
                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  SnackBar(
                      content:
                          Text('Created group: ${nameController.text}')),
                );
              } catch (e) {
                Navigator.pop(dialogContext);
                await Authentication.showErrorDialog(
                  context: scaffoldContext,
                  message: 'Error creating group: $e',
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void leaveGroup() {
    final scaffoldContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final userId = FirebaseAuth.instance.currentUser!.uid;

                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(currentGroupId)
                    .update({
                  'memberIds': FieldValue.arrayRemove([userId]),
                });

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .update({'groupId': FieldValue.delete()});

                Navigator.pop(dialogContext);
                setState(() {
                  isInGroup = false;
                  currentGroupId = null;
                  currentGroupName = null;
                  _memberUsernames = [];
                  _memberIds = [];
                  _appVotes = {};
                });
                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  const SnackBar(content: Text('Left the group')),
                );
              } catch (e) {
                Navigator.pop(dialogContext);
                await Authentication.showErrorDialog(
                  context: scaffoldContext,
                  message: 'Error leaving group: $e',
                );
              }
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
    final user = FirebaseAuth.instance.currentUser;

    return ExpansionTile(
      title: const Text(
        'Personal Settings',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: const Text('Username',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                subtitle: Text(
                  user?.displayName ?? 'No username set',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                subtitle: Text(
                  user?.email ?? 'No email found',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /* ===== about ===== */
  Widget aboutPage() {
    return ExpansionTile(
      title: const Text(
        'About this app',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      initiallyExpanded: false,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TODO: fill in about text
              const Text(
                'I built this app soely for the purpose of bullying my friends. If you find it fun as well thats pretty awesome! Also if you are a hiring manager looking to hire interns hit me up',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}