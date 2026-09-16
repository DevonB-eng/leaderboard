import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/core/utils/duration_format.dart';
import 'package:leaderboard/providers/group_provider.dart';
import 'package:leaderboard/providers/history_provider.dart';
import 'package:leaderboard/providers/leaderboard_provider.dart';
import 'package:leaderboard/providers/repository_providers.dart';
import 'package:leaderboard/providers/screentime_provider.dart';
import 'package:leaderboard/screens/home/widgets/leaderboard_table.dart';
import 'package:leaderboard/screens/home/widgets/no_group_prompt.dart';
import 'package:leaderboard/screens/home/widgets/stats_summary.dart';
import 'package:leaderboard/screens/home/widgets/weekly_chart.dart';
import 'package:leaderboard/screens/settings/settings_screen.dart';
import 'package:leaderboard/services/permissions_service.dart';
import 'package:leaderboard/widgets/app_header.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _permissionsService = PermissionsService();

  // Set once the app actually leaves the screen. `resumed` also follows a bare
  // `inactive` (a system dialog, the notification shade), and the battery
  // prompt should come back when the app is reopened, not the instant the user
  // answers the system's own battery dialog.
  bool _leftApp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _permissionsService.requestAll(context);
      if (mounted) _initializeHome();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _leftApp = true;
    } else if (state == AppLifecycleState.resumed) {
      ref.read(screentimeSyncProvider.notifier).sync();
      if (_leftApp) {
        _leftApp = false;
        _permissionsService.requestBatteryOptimizationExemption(context);
      }
    }
  }

  Future<void> _initializeHome() async {
    final groupId = await ref.read(groupIdProvider.future);
    if (groupId != null && mounted) {
      ref.read(leaderboardRealtimeProvider.notifier).subscribe(groupId);
      await ref.read(screentimeSyncProvider.notifier).sync();
    }
  }

  void _refreshAfterSettings() {
    ref.invalidate(groupIdProvider);
    ref.invalidate(groupProvider);
    ref.invalidate(leaderboardProvider);
    ref.invalidate(historyProvider);
    _initializeHome();
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    ).then((_) {
      if (mounted) _refreshAfterSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(groupIdProvider, (previous, next) {
      next.whenData((groupId) {
        if (groupId != null) {
          ref.read(leaderboardRealtimeProvider.notifier).subscribe(groupId);
          ref.read(screentimeSyncProvider.notifier).sync();
        } else {
          ref.read(leaderboardRealtimeProvider.notifier).unsubscribe();
        }
      });
    });

    final groupIdAsync = ref.watch(groupIdProvider);
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final weeklyAsync = ref.watch(weeklyStandingsProvider);
    final historyAsync = ref.watch(historyProvider);
    final currentUser = ref.watch(currentUserProvider);
    ref.watch(leaderboardRealtimeProvider);

    final dateKeys = ref.watch(historyDateKeysProvider);
    final dayLabels = dayLabelsForDates(dateKeys);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppHeader(
              title: 'Leaderboard',
              actions: [
                // Manual refresh, kept for debugging syncs — the app syncs on
                // launch, on resume, and in the background.
                // HeaderIconButton(
                //   icon: Icons.refresh,
                //   tooltip: 'Refresh',
                //   onPressed: () =>
                //       ref.read(screentimeSyncProvider.notifier).sync(),
                // ),
                HeaderIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Settings',
                  onPressed: _navigateToSettings,
                ),
              ],
            ),
            Expanded(
              child: groupIdAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: AppTextStyles.body(color: AppColors.error),
                  ),
                ),
                data: (groupId) {
                  if (groupId == null) {
                    return NoGroupPrompt(onJoinPressed: _navigateToSettings);
                  }

                  return leaderboardAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Text(
                        'Error: $e',
                        style: AppTextStyles.body(color: AppColors.error),
                      ),
                    ),
                    data: (leaderboard) {
                      final entries = leaderboard?.entries ?? [];
                      if (entries.isEmpty) {
                        return Center(
                          child: Text(
                            'No data yet!',
                            style: AppTextStyles.body(
                              color: AppColors.textMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            StatsSummary(
                              entries: entries,
                              currentUserId: currentUser?.id,
                            ),
                            const SizedBox(height: 20),
                            LeaderboardTable(
                              // Until the week's totals land, the day's
                              // standings stand in rather than an empty card.
                              entries: weeklyAsync.valueOrNull ?? entries,
                              currentUserId: currentUser?.id,
                            ),
                            const SizedBox(height: 20),
                            WeeklyChart(
                              history: historyAsync.valueOrNull,
                              dateKeys: dateKeys,
                              dayLabels: dayLabels,
                              isLoading: historyAsync.isLoading,
                              currentUserId: currentUser?.id,
                            ),
                          ],
                        ),
                      );
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
}
