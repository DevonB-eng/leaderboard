import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:leaderboard/core/constants/bad_apps.dart';
import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/data/models/group.dart';
import 'package:leaderboard/data/models/user_profile.dart';
import 'package:leaderboard/providers/group_provider.dart';
import 'package:leaderboard/providers/repository_providers.dart';
import 'package:leaderboard/widgets/section_card.dart';

class AppVoteList extends ConsumerWidget {
  const AppVoteList({
    super.key,
    required this.group,
    required this.memberCount,
  });

  final Group group;
  final int memberCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserProvider)?.id;
    if (userId == null) return const SizedBox.shrink();

    ref.watch(appVotesProvider);
    final votesNotifier = ref.read(appVotesProvider.notifier);

    final trackedCount = badAppDisplayNames.where((appName) {
      final voteStr = votesNotifier.voteCount(appName, memberCount);
      final parts = voteStr.split('/');
      final votes = int.tryParse(parts[0]) ?? 0;
      final total = int.tryParse(parts[1]) ?? memberCount;
      return total > 0 && votes * 2 > total;
    }).length;

    return SectionCard(
      title: 'TRACKED BAD APPS',
      subtitle: 'Tracked once more than 50% of members vote for it.',
      child: CollapsibleCard(
        icon: Icons.smartphone,
        label: '$trackedCount tracked',
        initiallyExpanded: false,
        children: badAppDisplayNames.map((appName) {
          final voted = votesNotifier.isVotedByCurrentUser(appName, userId);
          final voteStr = votesNotifier.voteCount(appName, memberCount);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                try {
                  await votesNotifier.toggleVote(appName, userId, group.id);
                } catch (_) {
                  if (context.mounted) {
                    await ref
                        .read(authRepositoryProvider)
                        .showErrorDialog(
                          context: context,
                          message: 'Failed to update vote. Please try again.',
                        );
                  }
                }
              },
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: voted ? AppColors.sky : AppColors.surface,
                      borderRadius: BorderRadius.circular(7),
                      border: voted
                          ? null
                          : Border.all(color: AppColors.tanBorder),
                    ),
                    child: voted
                        ? const Icon(
                            Icons.check,
                            size: 13,
                            color: AppColors.skyDark,
                          )
                        : null,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(appName, style: AppTextStyles.body()),
                  ),
                  Text(
                    voteStr,
                    style: AppTextStyles.fieldLabel(size: 11),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class GroupManageSection extends ConsumerWidget {
  const GroupManageSection({
    super.key,
    required this.group,
    required this.members,
    required this.isLoadingMembers,
    required this.onGroupLeft,
  });

  final Group group;
  final List<UserProfile> members;
  final bool isLoadingMembers;
  final VoidCallback onGroupLeft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'GROUP MEMBERS',
          child: CollapsibleCard(
            icon: Icons.people,
            label: group.name,
            emptyPlaceholder: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No members found.', style: AppTextStyles.body()),
            ),
            children: isLoadingMembers
                ? [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ]
                : members.map((member) {
                    final isYou = member.id == currentUserId;
                    final initial = member.username.isNotEmpty
                        ? member.username[0].toLowerCase()
                        : '?';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isYou ? AppColors.sky : AppColors.tanMuted,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initial,
                              style: AppTextStyles.body(
                                size: 11,
                                color: isYou
                                    ? AppColors.skyDark
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              member.username,
                              style: AppTextStyles.body(),
                            ),
                          ),
                          if (isYou)
                            Text(
                              'YOU',
                              style: AppTextStyles.fieldLabel(
                                size: 10,
                                color: AppColors.skyText,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        AppVoteList(group: group, memberCount: members.length),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: () => _leaveGroup(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.coralBg,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout, size: 15, color: AppColors.coralText),
                const SizedBox(width: 8),
                Text(
                  'Leave group',
                  style: AppTextStyles.pill(color: AppColors.coralText),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _leaveGroup(BuildContext context, WidgetRef ref) async {
    final scaffoldContext = context;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Leave group', style: AppTextStyles.title(size: 18)),
        content: Text(
          'Are you sure you want to leave this group?',
          style: AppTextStyles.copy(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('No', style: AppTextStyles.body()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Yes',
              style: AppTextStyles.body(color: AppColors.coralText),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final userId = ref.read(authRepositoryProvider).currentUser?.id;
      if (userId == null) throw Exception('Unable to leave group.');
      await ref
          .read(groupRepositoryProvider)
          .leaveGroup(userId: userId, groupId: group.id);
      onGroupLeft();
      if (scaffoldContext.mounted) {
        ScaffoldMessenger.of(
          scaffoldContext,
        ).showSnackBar(const SnackBar(content: Text('Left the group')));
      }
    } catch (e) {
      if (scaffoldContext.mounted) {
        await ref
            .read(authRepositoryProvider)
            .showErrorDialog(
              context: scaffoldContext,
              message: 'Error leaving group: $e',
            );
      }
    }
  }
}
