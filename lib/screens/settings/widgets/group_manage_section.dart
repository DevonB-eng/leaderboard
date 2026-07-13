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

    final votes = ref.watch(appVotesProvider);
    final votesNotifier = ref.read(appVotesProvider.notifier);

    return SubSectionCard(
      icon: Icons.phone_android,
      title: 'TRACKED BAD APPS',
      subtitle: 'An app is tracked when more than 50% of members vote for it.',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(child: Text('APP', style: AppTextStyles.label())),
              Text('VOTES', style: AppTextStyles.label()),
              const SizedBox(width: 48),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.primaryLight),
        ...badAppDisplayNames.map((appName) {
          final voted = votesNotifier.isVotedByCurrentUser(appName, userId);
          final voteStr = votesNotifier.voteCount(appName, memberCount);
          return Row(
            children: [
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(appName, style: AppTextStyles.body())),
              Text(voteStr, style: AppTextStyles.mono()),
              Checkbox(
                value: voted,
                onChanged: (_) async {
                  try {
                    await votesNotifier.toggleVote(appName, userId, group.id);
                  } catch (_) {
                    if (context.mounted) {
                      await ref.read(authRepositoryProvider).showErrorDialog(
                            context: context,
                            message: 'Failed to update vote. Please try again.',
                          );
                    }
                  }
                },
              ),
            ],
          );
        }),
      ],
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.group, color: AppColors.primaryBright, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(group.name, style: AppTextStyles.heading()),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SubSectionCard(
            icon: Icons.people,
            title: 'MEMBERS',
            subtitle: isLoadingMembers
                ? 'Loading...'
                : '${members.length} member${members.length == 1 ? '' : 's'}',
            children: isLoadingMembers
                ? [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ]
                : members.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text('No members found.', style: AppTextStyles.body()),
                        ),
                      ]
                    : members
                        .map(
                          (member) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(member.username, style: AppTextStyles.body()),
                              ],
                            ),
                          ),
                        )
                        .toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppVoteList(group: group, memberCount: members.length),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _leaveGroup(context, ref),
            icon: const Icon(Icons.exit_to_app, size: 16, color: AppColors.error),
            label: Text('LEAVE GROUP', style: AppTextStyles.label(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryLight, width: 1),
              shape: const RoundedRectangleBorder(borderRadius: AppBorders.radius),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveGroup(BuildContext context, WidgetRef ref) async {
    final scaffoldContext = context;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorders.radius,
          side: AppBorders.thin,
        ),
        title: Text('LEAVE GROUP', style: AppTextStyles.heading()),
        content: Text('Are you sure you want to leave this group?', style: AppTextStyles.label()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('NO', style: AppTextStyles.body()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('YES', style: AppTextStyles.body()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final userId = ref.read(authRepositoryProvider).currentUser?.id;
      if (userId == null) throw Exception('Unable to leave group.');
      await ref.read(groupRepositoryProvider).leaveGroup(
            userId: userId,
            groupId: group.id,
          );
      onGroupLeft();
      if (scaffoldContext.mounted) {
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          const SnackBar(content: Text('Left the group')),
        );
      }
    } catch (e) {
      if (scaffoldContext.mounted) {
        await ref.read(authRepositoryProvider).showErrorDialog(
              context: scaffoldContext,
              message: 'Error leaving group: $e',
            );
      }
    }
  }
}
