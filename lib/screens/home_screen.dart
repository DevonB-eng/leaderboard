import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:leaderboard/screens/settings_screen.dart';
// import 'package:leaderboard/screens/user_stats_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:leaderboard/utils/screen_time.dart';
import 'package:leaderboard/utils/authentication.dart';
import 'package:leaderboard/assets/design.dart';

/*
home_screen.dart - the main homepage
- displays leaderboard if user is in a group, otherwise prompts user to join or create a group
- has buttons to navigate to settings page, my screentime page, and to sign out
*/
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

  Map<String, double> _personalHistory = {};
  Map<String, double> _groupHistory = {};
  bool _historyLoaded = false;

  late final List<String> _historyDates = List.generate(7, (i) {
    final day = DateTime.now().subtract(Duration(days: 6 - i));
    return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  });

  late final List<String> _dayLabels = _historyDates.map((date) {
    final d = DateTime.parse(date);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }).toList();

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
        _fetchHistory(groupId); // fetch history alongside leaderboard
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
  // history fetches for stats
  Future<void> _fetchHistory(String groupId) async {
    if (_historyLoaded) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final results = await Future.wait([
        Future.wait(_historyDates.map((date) => FirebaseFirestore.instance
            .collection('screentime')
            .doc(uid)
            .collection('history')
            .doc(date)
            .get())),
        Future.wait(_historyDates.map((date) => FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('history')
            .doc(date)
            .get())),
      ]);

      final personal = <String, double>{};
      final group = <String, double>{};

      for (int i = 0; i < _historyDates.length; i++) {
        personal[_historyDates[i]] = results[0][i].exists
            ? ((results[0][i].data()?['totalBadMinutes'] ?? 0) as num).toDouble()
            : 0;
        group[_historyDates[i]] = results[1][i].exists
            ? ((results[1][i].data()?['averageBadMinutes'] ?? 0) as num).toDouble()
            : 0;
      }

      if (mounted) {
        setState(() {
          _personalHistory = personal;
          _groupHistory = group;
          _historyLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('History fetch error: $e');
    }
  }
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
      backgroundColor: AppColors.background,
      // No AppBar — replaced by custom header below
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ===== header banner =====
            _buildHeader(),

            // ===== body =====
            Expanded(
              child: FutureBuilder<String?>(
                future: _groupFuture,
                builder: (context, groupSnapshot) {
                  if (groupSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final groupId = groupSnapshot.data;

                  if (groupId == null) {
                    return _buildNoGroupPrompt();
                  }

                  return FutureBuilder<DocumentSnapshot>(
                    future: _leaderboardFuture,
                    builder: (context, lbSnapshot) {
                      if (lbSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      if (lbSnapshot.hasError) {
                        return Center(
                            child: Text('Error: ${lbSnapshot.error}',
                                style: AppTextStyles.body(
                                    color: AppColors.error)));
                      }

                      final data =
                          lbSnapshot.data?.data() as Map<String, dynamic>?;
                      final entries =
                          (data?['entries'] as List<dynamic>?) ?? [];

                      if (entries.isEmpty) {
                        return Center(
                          child: Text(
                            'No data yet — tap refresh to upload your screentime!',
                            style: AppTextStyles.body(
                                color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      return _buildLeaderboard(entries, user);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== header =====

  Widget _buildHeader() {
  return Container(
    color: AppColors.background,
    child: Column(
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
              Text('LEADERBOARD', style: AppTextStyles.display(size: 36)),
              IconButton(
                icon: const Icon(Icons.refresh,
                    color: AppColors.textPrimary, size: 22),
                tooltip: 'Refresh',
                onPressed: _uploadAndRefresh,
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
                  onPressed: () => _navigateAndRefresh(const SettingsScreen()),
                  icon: const Icon(Icons.settings,
                      size: 16, color: AppColors.textPrimary),
                  label: Text('SETTINGS & INFO',
                      style: AppTextStyles.label(color: AppColors.textPrimary)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    side: const BorderSide(color: AppColors.primaryLight, width: 1),
                    shape: const RoundedRectangleBorder(borderRadius: AppBorders.radius),
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
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    side: const BorderSide(color: AppColors.primaryLight, width: 1),
                    shape: const RoundedRectangleBorder(borderRadius: AppBorders.radius),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  // ===== no group prompt =====

  Widget _buildNoGroupPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.group_off,
                size: 80, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Join a group to see the leaderboard!',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: () => _navigateAndRefresh(const SettingsScreen()),
              icon: const Icon(Icons.group_add),
              label: const Text('JOIN OR CREATE GROUP'),
            ),
          ],
        ),
      ),
    );
  }

  // ===== leaderboard table =====

  Widget _buildLeaderboard(List<dynamic> entries, User? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ===== 1. leaderboard table =====
          Container(
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
                  child: Text('GROUP LEADERBOARD',
                      style: AppTextStyles.heading(size: 14)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 48,
                          child: Text('RANK', style: AppTextStyles.label())),
                      Expanded(
                          child: Text('USER', style: AppTextStyles.label())),
                      Text('TIME TODAY', style: AppTextStyles.label()),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.primaryLight),
                ...entries.asMap().entries.map((e) {
                  final index = e.key;
                  final entry = e.value as Map<String, dynamic>;
                  final uid = entry['uid'];
                  final username = entry['username'] ?? 'Anonymous';
                  final totalMinutes =
                      (entry['totalBadMinutes'] as num?)?.toDouble() ?? 0;
                  final isCurrentUser = uid == user?.uid;
                  final badAppsData =
                      entry['badAppsBreakdown'] as List<dynamic>?;
                  return _buildLeaderboardRow(
                    index: index,
                    uid: uid,
                    username: username,
                    totalMinutes: totalMinutes,
                    isCurrentUser: isCurrentUser,
                    badAppsData: badAppsData,
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ===== 2. today's stats summary =====
          _buildStatsTable(entries, user),

          const SizedBox(height: AppSpacing.md),

          // ===== 3. weekly bar chart =====
          _buildBarChart(),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final allValues = [
      ..._personalHistory.values,
      ..._groupHistory.values,
    ];
    final maxY = allValues.isEmpty
        ? 100.0
        : (allValues.reduce((a, b) => a > b ? a : b) * 1.2)
            .clamp(10.0, double.infinity);

    return Container(
      decoration: BoxDecoration(
        border: AppBorders.box,
        borderRadius: AppBorders.radius,
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // Title bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Text('WEEKLY SCREENTIME',
                style: AppTextStyles.heading(size: 14)),
          ),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Legend
                Row(
                  children: [
                    Container(
                        width: 12, height: 12, color: AppColors.primaryBright),
                    const SizedBox(width: AppSpacing.xs),
                    Text('You', style: AppTextStyles.label()),
                    const SizedBox(width: AppSpacing.md),
                    Container(
                        width: 12, height: 12, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.xs),
                    Text('Group Avg', style: AppTextStyles.label()),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Chart
                SizedBox(
                  height: 240,
                  child: _historyLoaded
                      ? BarChart(
                          BarChartData(
                            maxY: maxY,
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) {
                                  final label =
                                      rodIndex == 0 ? 'You' : 'Group Avg';
                                  final hrs = (rod.toY / 60).floor();
                                  final mins = (rod.toY % 60).round();
                                  final timeStr = hrs > 0
                                      ? '${hrs}h ${mins}m'
                                      : '${mins}m';
                                  return BarTooltipItem(
                                    '$label\n$timeStr',
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
                                    if (i < 0 || i >= _dayLabels.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(_dayLabels[i],
                                          style: AppTextStyles.label()),
                                    );
                                  },
                                  reservedSize: 28,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 44,
                                  getTitlesWidget: (value, meta) {
                                    final hrs = (value / 60).floor();
                                    final mins = (value % 60).round();
                                    final label = hrs > 0
                                        ? '${hrs}h${mins > 0 ? ' ${mins}m' : ''}'
                                        : '${mins}m';
                                    return Text(label,
                                        style: AppTextStyles.label(
                                            color: AppColors.textMuted));
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              drawVerticalLine: false,
                              horizontalInterval: maxY / 4,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color:
                                    AppColors.primaryLight.withOpacity(0.3),
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups:
                                List.generate(_historyDates.length, (i) {
                              final date = _historyDates[i];
                              final personal = _personalHistory[date] ?? 0;
                              final group = _groupHistory[date] ?? 0;
                              return BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: personal,
                                    color: AppColors.primaryBright,
                                    width: 12,
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(3)),
                                  ),
                                  BarChartRodData(
                                    toY: group,
                                    color: AppColors.textMuted,
                                    width: 12,
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(3)),
                                  ),
                                ],
                              );
                            }),
                          ),
                        )
                      // Show placeholder bars while history loads
                      // so the chart space doesn't collapse
                      : const Center(child: CircularProgressIndicator()),
                ),

                if (_historyLoaded && allValues.every((v) => v == 0))
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      'No history yet — check back after your first full day.',
                      style: AppTextStyles.label(color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTable(List<dynamic> entries, User? user) {
    // Compute personal and group average from the already-fetched entries
    final myEntry = entries.firstWhere(
      (e) => (e as Map<String, dynamic>)['uid'] == user?.uid,
      orElse: () => null,
    );

    final myMinutes = myEntry != null
        ? (myEntry['totalBadMinutes'] as num?)?.toDouble() ?? 0
        : 0.0;

    final totalMinutes = entries.fold<double>(
      0,
      (sum, e) => sum + ((e['totalBadMinutes'] as num?)?.toDouble() ?? 0),
    );
    final groupAvg =
        entries.isNotEmpty ? totalMinutes / entries.length : 0.0;
    final delta = myMinutes - groupAvg;

    // Format minutes as Xhr Ym
    String fmt(double minutes) {
      final hrs = (minutes / 60).floor();
      final mins = (minutes % 60).round();
      return hrs > 0 ? '${hrs}h ${mins}m' : '${mins}m';
    }

    final deltaStr = delta >= 0
        ? '+${fmt(delta)} above avg'
        : '-${fmt(delta.abs())} below avg';
    final deltaColor =
        delta > 0 ? AppColors.error : AppColors.success;

    return Container(
      decoration: BoxDecoration(
        border: AppBorders.box,
        borderRadius: AppBorders.radius,
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Text('TODAY\'S STATS',
                style: AppTextStyles.heading(size: 14)),
          ),

          // You row
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('You', style: AppTextStyles.body()),
                Text(fmt(myMinutes),
                    style: AppTextStyles.mono(
                        color: AppColors.primaryBright)),
              ],
            ),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Divider(height: 1, color: AppColors.primaryLight),
          ),

          // Group avg row
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Group Avg', style: AppTextStyles.body()),
                Text(fmt(groupAvg),
                    style: AppTextStyles.mono(
                        color: AppColors.textSecondary)),
              ],
            ),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Divider(height: 1, color: AppColors.primaryLight),
          ),

          // Delta row
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('vs Average',
                    style: AppTextStyles.label(
                        color: AppColors.textSecondary)),
                Text(deltaStr,
                    style: AppTextStyles.mono(color: deltaColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardRow({
    required int index,
    required String uid,
    required String username,
    required double totalMinutes,
    required bool isCurrentUser,
    required List<dynamic>? badAppsData,
  }) {
    // Format minutes into Xhr Ym or just Ym
    final hrs = (totalMinutes / 60).floor();
    final mins = (totalMinutes % 60).round();
    final timeStr =
        hrs > 0 ? '${hrs}h ${mins}m' : '${mins}m';

    return Column(
      children: [
        Theme(
          // Remove the default ExpansionTile dividers
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            leading: SizedBox(
              width: 32,
              child: Text(
                '${index + 1}.',
                style: AppTextStyles.display(
                  size: 22,
                  color: isCurrentUser
                      ? AppColors.primaryBright
                      : AppColors.textSecondary,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    username,
                    style: AppTextStyles.body(
                      color: isCurrentUser
                          ? AppColors.primaryBright
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  timeStr,
                  style: AppTextStyles.mono(
                    color: isCurrentUser
                        ? AppColors.primaryBright
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            // Breakdown chevron only shown if there's data
            trailing: (badAppsData != null && badAppsData.isNotEmpty)
                ? const Icon(Icons.expand_more,
                    color: AppColors.primaryLight, size: 18)
                : const SizedBox(width: 18),
            children: [
              if (badAppsData != null && badAppsData.isNotEmpty)
                Container(
                  color: AppColors.surfaceRaised,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('APP BREAKDOWN',
                          style: AppTextStyles.label()),
                      const SizedBox(height: AppSpacing.xs),
                      ...badAppsData.map((app) {
                        final appMap = app as Map<String, dynamic>;
                        final appName = appMap['appName'] ?? 'Unknown';
                        final minutes =
                            (appMap['minutes'] as num?)?.toDouble() ?? 0;
                        final appHrs = (minutes / 60).floor();
                        final appMins = (minutes % 60).round();
                        final appTimeStr = appHrs > 0
                            ? '${appHrs}h ${appMins}m'
                            : '${appMins}m';
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs),
                          child: Row(
                            children: [
                              const Icon(Icons.phone_android,
                                  size: 14,
                                  color: AppColors.textSecondary),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(appName,
                                    style: AppTextStyles.body(
                                        size: 13,
                                        color: AppColors.textSecondary)),
                              ),
                              Text(appTimeStr,
                                  style: AppTextStyles.mono(
                                      size: 13,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Divider between rows but not after the last one
        const Divider(height: 1, color: AppColors.primaryLight),
      ],
    );
  }
}