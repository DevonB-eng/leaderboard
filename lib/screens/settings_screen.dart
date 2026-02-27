import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:leaderboard/screens/user_stats_screen.dart';

import 'package:leaderboard/utils/authentication.dart';
import 'package:leaderboard/utils/screen_time.dart';
import 'package:leaderboard/screens/home_screen.dart';
import 'package:leaderboard/assets/design.dart';

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

  Map<String, List<String>> _appVotes = {};

  final List<String> _badAppDisplayNames = ScreenTimeService.badApps.values
      .toSet()
      .toList()
    ..sort();

  Map<String, double> _personalHistory = {};
  Map<String, double> _groupHistory = {};
  bool _loadingStats = false;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    checkUserGroupStatus();
  }

  // ===== all logic unchanged =====

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
            List<String>.from(groupData['memberIds'] ?? []));
      }
    } catch (e) {
      debugPrint('Error checking group status: $e');
    }
  }

  Future<void> _fetchMemberUsernames(List<String> memberIds) async {
    if (memberIds.isEmpty) return;
    setState(() {
      _loadingMembers = true;
      _memberIds = memberIds;
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

  Future<void> _fetchStatsHistory() async {
    if (_statsLoaded || currentGroupId == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loadingStats = true);
    try {
      final dates = List.generate(7, (i) {
        final day = DateTime.now().subtract(Duration(days: 6 - i));
        return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      });
      final results = await Future.wait([
        Future.wait(dates.map((date) => FirebaseFirestore.instance
            .collection('screentime')
            .doc(uid)
            .collection('history')
            .doc(date)
            .get())),
        Future.wait(dates.map((date) => FirebaseFirestore.instance
            .collection('groups')
            .doc(currentGroupId)
            .collection('history')
            .doc(date)
            .get())),
      ]);
      final personalDocs = results[0];
      final groupDocs = results[1];
      final personal = <String, double>{};
      final group = <String, double>{};
      for (int i = 0; i < dates.length; i++) {
        personal[dates[i]] = personalDocs[i].exists
            ? ((personalDocs[i].data()?['totalBadMinutes'] ?? 0) as num)
                .toDouble()
            : 0;
        group[dates[i]] = groupDocs[i].exists
            ? ((groupDocs[i].data()?['averageBadMinutes'] ?? 0) as num)
                .toDouble()
            : 0;
      }
      setState(() {
        _personalHistory = personal;
        _groupHistory = group;
        _statsLoaded = true;
      });
    } catch (e) {
      debugPrint('Error fetching stats history: $e');
    } finally {
      setState(() => _loadingStats = false);
    }
  }

  bool _isVotedByCurrentUser(String appName) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    if (!_appVotes.containsKey(appName)) return true;
    return _appVotes[appName]!.contains(uid);
  }

  String _voteCount(String appName) {
    final totalMembers = _memberUsernames.length;
    if (!_appVotes.containsKey(appName)) return '$totalMembers/$totalMembers';
    return '${_appVotes[appName]!.length}/$totalMembers';
  }

  Future<void> _toggleVote(String appName) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || currentGroupId == null) return;
    final hasEntry = _appVotes.containsKey(appName);
    final currentlyVoted = _isVotedByCurrentUser(appName);
    final initialList = hasEntry
        ? List<String>.from(_appVotes[appName]!)
        : List<String>.from(_memberIds);
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
      debugPrint('Error updating vote: $e');
      setState(() => _appVotes[appName] = List<String>.from(initialList));
      if (mounted) {
        await Authentication.showErrorDialog(
          context: context,
          message: 'Failed to update vote. Please try again.',
        );
      }
    }
  }

  // ===== build =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ===== header banner =====
            _buildHeader(),

            // ===== scrollable content =====
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  _buildSection('GROUP SETTINGS', isInGroup ? _inGroupOptions() : _notInGroupOptions()),
                  const SizedBox(height: AppSpacing.md),
                  _buildSection('STATS', _statsContent()),
                  const SizedBox(height: AppSpacing.md),
                  _buildSection('PERSONAL', _personalContent()),
                  const SizedBox(height: AppSpacing.md),
                  _buildSection('ABOUT', _aboutContent()),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== header =====

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SETTINGS & INFO', style: AppTextStyles.display(size: 30)),
              IconButton(
                icon: const Icon(Icons.home,
                    color: AppColors.textPrimary, size: 22),
                tooltip: 'Home',
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const UserStatsPage())),
                  icon: const Icon(Icons.timer,
                      size: 16, color: AppColors.textPrimary),
                  label: Text('MY SCREENTIME',
                      style: AppTextStyles.label(color: AppColors.textPrimary)),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    side: const BorderSide(
                        color: AppColors.primaryLight, width: 1),
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppBorders.radius),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Authentication.signOut(context: context),
                  icon: const Icon(Icons.logout,
                      size: 16, color: AppColors.textPrimary),
                  label: Text('SIGN OUT',
                      style: AppTextStyles.label(color: AppColors.textPrimary)),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    side: const BorderSide(
                        color: AppColors.primaryLight, width: 1),
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppBorders.radius),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===== reusable section container =====
  // Wraps any content in a bordered box with a titled header bar,
  // matching the table style from home_screen.dart

  Widget _buildSection(String title, Widget content) {
    return Container(
      decoration: BoxDecoration(
        border: AppBorders.box,
        borderRadius: AppBorders.radius,
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Text(title, style: AppTextStyles.heading(size: 14)),
          ),
          content,
        ],
      ),
    );
  }

  // ===== group settings content =====

  Widget _notInGroupOptions() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: joinGroup,
            icon: const Icon(Icons.group_add, size: 16),
            label: Text('JOIN GROUP', style: AppTextStyles.label(color: AppColors.textPrimary)),
          ),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton.icon(
            onPressed: createGroup,
            icon: const Icon(Icons.add, size: 16),
            label: Text('CREATE GROUP', style: AppTextStyles.label(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _inGroupOptions() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // Group name
          Row(
            children: [
              const Icon(Icons.group, color: AppColors.primaryBright, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                currentGroupName ?? 'Unknown Group',
                style: AppTextStyles.heading(size: 16),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Members expansion
          _buildSubSection(
            icon: Icons.people,
            title: 'MEMBERS',
            subtitle: _loadingMembers
                ? 'Loading...'
                : '${_memberUsernames.length} member${_memberUsernames.length == 1 ? '' : 's'}',
            children: _loadingMembers
                ? [const Center(child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(),
                  ))]
                : _memberUsernames.isEmpty
                    ? [Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text('No members found.',
                            style: AppTextStyles.body(color: AppColors.textSecondary)),
                      )]
                    : _memberUsernames.map((username) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                          child: Row(
                            children: [
                              const Icon(Icons.person,
                                  size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: AppSpacing.sm),
                              Text(username,
                                  style: AppTextStyles.body(
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        )).toList(),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Bad apps voting expansion
          _buildSubSection(
            icon: Icons.phone_android,
            title: 'TRACKED BAD APPS',
            subtitle: 'Check to vote for an app to be tracked',
            children: [
              // Column headers
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('APP',
                          style: AppTextStyles.label()),
                    ),
                    Text('VOTES',
                        style: AppTextStyles.label()),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.primaryLight),
              ..._badAppDisplayNames.map((appName) {
                final voted = _isVotedByCurrentUser(appName);
                final voteStr = _voteCount(appName);
                return Row(
                  children: [
                    const SizedBox(width: AppSpacing.md),
                    const Icon(Icons.block,
                        size: 14, color: AppColors.error),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(appName,
                          style: AppTextStyles.body(size: 13)),
                    ),
                    Text(voteStr,
                        style: AppTextStyles.mono(
                            size: 13, color: AppColors.textSecondary)),
                    Checkbox(
                      value: voted,
                      onChanged: (_) => _toggleVote(appName),
                    ),
                  ],
                );
              }),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
                child: Text(
                  'An app is tracked when more than 50% of members vote for it.',
                  style: AppTextStyles.label(color: AppColors.textMuted),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Leave group
          OutlinedButton.icon(
            onPressed: leaveGroup,
            icon: const Icon(Icons.exit_to_app,
                size: 16, color: AppColors.error),
            label: Text('LEAVE GROUP',
                style: AppTextStyles.label(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error, width: 1),
              shape: const RoundedRectangleBorder(
                  borderRadius: AppBorders.radius),
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            ),
          ),
        ],
      ),
    );
  }

  // Collapsible subsection used inside group settings
  Widget _buildSubSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryLight, width: 1),
        borderRadius: AppBorders.radius,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: AppColors.primaryLight, size: 18),
          title: Text(title, style: AppTextStyles.body()),
          subtitle: Text(subtitle,
              style: AppTextStyles.label(color: AppColors.textSecondary)),
          iconColor: AppColors.primaryBright,
          collapsedIconColor: AppColors.primaryLight,
          children: children,
        ),
      ),
    );
  }

  // ===== stats content =====

  Widget _statsContent() {
    final dates = List.generate(7, (i) {
      final day = DateTime.now().subtract(Duration(days: 6 - i));
      return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    });
    final dayLabels = dates.map((date) {
      final d = DateTime.parse(date);
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[d.weekday - 1];
    }).toList();
    final allValues = [
      ..._personalHistory.values,
      ..._groupHistory.values,
    ];
    final maxY = allValues.isEmpty
        ? 100.0
        : (allValues.reduce((a, b) => a > b ? a : b) * 1.2)
            .clamp(10.0, double.infinity);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: const Icon(Icons.bar_chart,
            color: AppColors.primaryLight, size: 18),
        title: Text('WEEKLY CHART', style: AppTextStyles.body()),
        subtitle: Text('Personal vs group average',
            style: AppTextStyles.label(color: AppColors.textSecondary)),
        iconColor: AppColors.primaryBright,
        collapsedIconColor: AppColors.primaryLight,
        onExpansionChanged: (expanded) {
          if (expanded && !_statsLoaded) _fetchStatsHistory();
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
            child: _loadingStats
                ? const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Legend
                      Row(
                        children: [
                          Container(
                              width: 12,
                              height: 12,
                              color: AppColors.primaryBright),
                          const SizedBox(width: AppSpacing.xs),
                          Text('You', style: AppTextStyles.label()),
                          const SizedBox(width: AppSpacing.md),
                          Container(
                              width: 12,
                              height: 12,
                              color: AppColors.textMuted),
                          const SizedBox(width: AppSpacing.xs),
                          Text('Group Avg', style: AppTextStyles.label()),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Chart
                      SizedBox(
                        height: 220,
                        child: BarChart(
                          BarChartData(
                            maxY: maxY,
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod,
                                    rodIndex) {
                                  final label =
                                      rodIndex == 0 ? 'You' : 'Group Avg';
                                  return BarTooltipItem(
                                    '$label\n${rod.toY.toStringAsFixed(0)} min',
                                    AppTextStyles.label(
                                        color: AppColors.textPrimary),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final i = value.toInt();
                                    if (i < 0 || i >= dayLabels.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(top: 6),
                                      child: Text(dayLabels[i],
                                          style: AppTextStyles.label()),
                                    );
                                  },
                                  reservedSize: 28,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) => Text(
                                    '${value.toInt()}m',
                                    style: AppTextStyles.label(
                                        color: AppColors.textMuted),
                                  ),
                                ),
                              ),
                              topTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              drawVerticalLine: false,
                              horizontalInterval: maxY / 4,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: AppColors.primaryLight
                                    .withOpacity(0.3),
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups:
                                List.generate(dates.length, (i) {
                              final date = dates[i];
                              final personal =
                                  _personalHistory[date] ?? 0;
                              final group = _groupHistory[date] ?? 0;
                              return BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: personal,
                                    color: AppColors.primaryBright,
                                    width: 10,
                                    borderRadius:
                                        const BorderRadius.vertical(
                                            top: Radius.circular(3)),
                                  ),
                                  BarChartRodData(
                                    toY: group,
                                    color: AppColors.textMuted,
                                    width: 10,
                                    borderRadius:
                                        const BorderRadius.vertical(
                                            top: Radius.circular(3)),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                      if (allValues.every((v) => v == 0))
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            'No history yet — check back after your first full day.',
                            style: AppTextStyles.label(
                                color: AppColors.textMuted),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ===== personal settings content =====

  Widget _personalContent() {
    final user = FirebaseAuth.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Username row
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 16, color: AppColors.primaryLight),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('USERNAME', style: AppTextStyles.label()),
                  Text(
                    user?.displayName ?? 'No username set',
                    style: AppTextStyles.body(),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg, color: AppColors.primaryLight),
          // Email row
          Row(
            children: [
              const Icon(Icons.email_outlined,
                  size: 16, color: AppColors.primaryLight),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EMAIL', style: AppTextStyles.label()),
                  Text(
                    user?.email ?? 'No email found',
                    style: AppTextStyles.body(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== about content =====

  Widget _aboutContent() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Text(
        'I built this app soely for the purpose of bullying my friends. If you find it fun as well thats pretty awesome! Also if you are an engineering hiring manager looking to hire interns hit me up.',
        style: AppTextStyles.body(color: AppColors.textSecondary),
      ),
    );
  }

  // ===== join / create / leave dialogs (logic unchanged, styling updated) =====

  void joinGroup() {
    final searchController = TextEditingController();
    List<QueryDocumentSnapshot> searchResults = [];
    final scaffoldContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('JOIN GROUP', style: AppTextStyles.heading()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: searchController,
                style: AppTextStyles.body(),
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
                          .where('name', isLessThanOrEqualTo: '$value\uf8ff')
                          .get();
                      setDialogState(() => searchResults = results.docs);
                    } catch (e) {
                      await Authentication.showErrorDialog(
                          context: dialogContext,
                          message: 'Error searching for groups: $e');
                    }
                  } else {
                    setDialogState(() => searchResults = []);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 200,
                child: searchResults.isEmpty
                    ? Center(
                        child: Text('Search for a group',
                            style: AppTextStyles.body(
                                color: AppColors.textSecondary)))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final group = searchResults[index];
                          return ListTile(
                            leading: const Icon(Icons.group),
                            title: Text(group['name'],
                                style: AppTextStyles.body()),
                            subtitle: Text(
                                '${group['memberIds'].length} members',
                                style: AppTextStyles.label()),
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
        ),
      ),
    );
  }

  void showPasswordDialog(
      BuildContext scaffoldContext, String groupId, String groupName) {
    final passwordController = TextEditingController();
    showDialog(
      context: scaffoldContext,
      builder: (dialogContext) => AlertDialog(
        title: Text('JOIN $groupName', style: AppTextStyles.heading()),
        content: TextField(
          controller: passwordController,
          style: AppTextStyles.body(),
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
                      .update({'memberIds': FieldValue.arrayUnion([userId])});
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
                    SnackBar(content: Text('Joined $groupName')));
                } else {
                  await Authentication.showErrorDialog(
                      context: dialogContext, message: 'Incorrect password.');
                }
              } catch (e) {
                Navigator.pop(dialogContext);
                await Authentication.showErrorDialog(
                    context: scaffoldContext,
                    message: 'Error joining group: $e');
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
        title: Text('CREATE GROUP', style: AppTextStyles.heading()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: AppTextStyles.body(),
              decoration: const InputDecoration(
                labelText: 'Group Name',
                prefixIcon: Icon(Icons.group),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: passwordController,
              style: AppTextStyles.body(),
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
                    message: 'Please fill in all fields.');
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
                      content: Text('Created group: ${nameController.text}')));
              } catch (e) {
                Navigator.pop(dialogContext);
                await Authentication.showErrorDialog(
                    context: scaffoldContext,
                    message: 'Error creating group: $e');
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
        title: Text('LEAVE GROUP', style: AppTextStyles.heading()),
        content: Text('Are you sure you want to leave this group?',
            style: AppTextStyles.body()),
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
                    .update({'memberIds': FieldValue.arrayRemove([userId])});
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
                  const SnackBar(content: Text('Left the group')));
              } catch (e) {
                Navigator.pop(dialogContext);
                await Authentication.showErrorDialog(
                    context: scaffoldContext,
                    message: 'Error leaving group: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}