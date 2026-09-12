import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/widgets/password_dialog.dart';

class GroupJoinSection extends ConsumerWidget {
  const GroupJoinSection({super.key, required this.onGroupChanged});

  final VoidCallback onGroupChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => showJoinGroupDialog(
            context: context,
            ref: ref,
            onJoined: onGroupChanged,
          ),
          icon: const Icon(Icons.group_add, size: 16),
          label: const Text('Join group'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 0),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => showCreateGroupDialog(
            context: context,
            ref: ref,
            onCreated: onGroupChanged,
          ),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Create group'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 0),
            backgroundColor: AppColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ],
    );
  }
}
