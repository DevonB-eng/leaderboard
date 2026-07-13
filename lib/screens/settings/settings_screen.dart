import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/providers/group_provider.dart';
import 'package:leaderboard/providers/history_provider.dart';
import 'package:leaderboard/providers/leaderboard_provider.dart';
import 'package:leaderboard/screens/settings/widgets/about_section.dart';
import 'package:leaderboard/screens/settings/widgets/group_join_section.dart';
import 'package:leaderboard/screens/settings/widgets/group_manage_section.dart';
import 'package:leaderboard/screens/settings/widgets/personal_info_section.dart';
import 'package:leaderboard/widgets/app_header.dart';
import 'package:leaderboard/widgets/section_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  void _onGroupChanged() {
    ref.invalidate(groupIdProvider);
    ref.invalidate(groupProvider);
    ref.invalidate(groupMembersProvider);
    ref.invalidate(leaderboardProvider);
    ref.invalidate(historyProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(groupProvider, (previous, next) {
      next.whenData((group) {
        ref.read(appVotesProvider.notifier).setVotes(group?.appVotes ?? {});
      });
    });

    final groupAsync = ref.watch(groupProvider);
    final membersAsync = ref.watch(groupMembersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppHeader(
              title: 'SETTINGS & INFO',
              navButton: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.home, size: 16, color: AppColors.textPrimary),
                      label: Text('HOME SCREEN', style: AppTextStyles.body()),
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  SectionCard(
                    title: 'GROUP SETTINGS',
                    child: groupAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text('Error: $e', style: AppTextStyles.body(color: AppColors.error)),
                      ),
                      data: (group) {
                        if (group == null) {
                          return GroupJoinSection(onGroupChanged: _onGroupChanged);
                        }
                        return membersAsync.when(
                          loading: () => GroupManageSection(
                            group: group,
                            members: const [],
                            isLoadingMembers: true,
                            onGroupLeft: _onGroupChanged,
                          ),
                          error: (_, __) => GroupManageSection(
                            group: group,
                            members: const [],
                            isLoadingMembers: false,
                            onGroupLeft: _onGroupChanged,
                          ),
                          data: (members) => GroupManageSection(
                            group: group,
                            members: members,
                            isLoadingMembers: false,
                            onGroupLeft: _onGroupChanged,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const SectionCard(
                    title: 'PERSONAL',
                    child: PersonalInfoSection(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const SectionCard(
                    title: 'ABOUT THIS APP',
                    child: AboutSection(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
