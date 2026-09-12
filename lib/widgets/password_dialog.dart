import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/data/models/group.dart';
import 'package:leaderboard/providers/repository_providers.dart';

Future<void> showJoinPasswordDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String groupId,
  required String groupName,
  required VoidCallback onJoined,
}) async {
  final passwordController = TextEditingController();
  final scaffoldContext = context;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Join $groupName', style: AppTextStyles.title(size: 18)),
      content: TextField(
        controller: passwordController,
        style: AppTextStyles.body(),
        decoration: const InputDecoration(
          labelText: 'Enter group password',
          prefixIcon: Icon(Icons.lock, size: 18),
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
              final userId = ref.read(authRepositoryProvider).currentUser?.id;
              if (userId == null) throw Exception('Not signed in.');
              await ref
                  .read(groupRepositoryProvider)
                  .joinGroup(
                    userId: userId,
                    groupId: groupId,
                    password: passwordController.text,
                  );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              onJoined();
              if (scaffoldContext.mounted) {
                ScaffoldMessenger.of(
                  scaffoldContext,
                ).showSnackBar(SnackBar(content: Text('Joined $groupName')));
              }
            } catch (e) {
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (scaffoldContext.mounted) {
                await ref
                    .read(authRepositoryProvider)
                    .showErrorDialog(
                      context: scaffoldContext,
                      message: 'Error joining group: $e',
                    );
              }
            }
          },
          child: const Text('Join'),
        ),
      ],
    ),
  );
}

Future<void> showCreateGroupDialog({
  required BuildContext context,
  required WidgetRef ref,
  required VoidCallback onCreated,
}) async {
  final nameController = TextEditingController();
  final passwordController = TextEditingController();
  final scaffoldContext = context;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Create group', style: AppTextStyles.title(size: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            style: AppTextStyles.body(),
            decoration: const InputDecoration(
              labelText: 'Group Name',
              prefixIcon: Icon(Icons.group, size: 18),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: passwordController,
            style: AppTextStyles.body(),
            decoration: const InputDecoration(
              labelText: 'Group Password',
              prefixIcon: Icon(Icons.lock, size: 18),
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
              await ref
                  .read(authRepositoryProvider)
                  .showErrorDialog(
                    context: dialogContext,
                    message: 'Please fill in all fields.',
                  );
              return;
            }

            try {
              final userId = ref.read(authRepositoryProvider).currentUser?.id;
              if (userId == null) throw Exception('Not signed in.');
              await ref
                  .read(groupRepositoryProvider)
                  .createGroup(
                    userId: userId,
                    name: nameController.text.trim(),
                    password: passwordController.text,
                  );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              onCreated();
              if (scaffoldContext.mounted) {
                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Created group: ${nameController.text.trim()}',
                    ),
                  ),
                );
              }
            } catch (e) {
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (scaffoldContext.mounted) {
                await ref
                    .read(authRepositoryProvider)
                    .showErrorDialog(
                      context: scaffoldContext,
                      message: 'Error creating group: $e',
                    );
              }
            }
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

Future<void> showJoinGroupDialog({
  required BuildContext context,
  required WidgetRef ref,
  required VoidCallback onJoined,
}) async {
  final searchController = TextEditingController();
  List<GroupSummary> searchResults = [];
  final scaffoldContext = context;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text('Join group', style: AppTextStyles.title(size: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: searchController,
                style: AppTextStyles.body(),
                decoration: const InputDecoration(
                  labelText: 'Search for groups',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
                onChanged: (value) async {
                  if (value.isNotEmpty) {
                    try {
                      final results = await ref
                          .read(groupRepositoryProvider)
                          .searchGroups(value);
                      setDialogState(() => searchResults = results);
                    } catch (e) {
                      await ref
                          .read(authRepositoryProvider)
                          .showErrorDialog(
                            context: dialogContext,
                            message: 'Error searching for groups: $e',
                          );
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
                        child: Text(
                          'Search for a group',
                          style: AppTextStyles.copy(),
                        ),
                      )
                    : ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final group = searchResults[index];
                          return ListTile(
                            leading: const Icon(Icons.group),
                            title: Text(
                              group.name,
                              style: AppTextStyles.body(),
                            ),
                            subtitle: Text(
                              '${group.memberCount} members',
                              style: AppTextStyles.copy(size: 11),
                            ),
                            onTap: () {
                              Navigator.pop(dialogContext);
                              showJoinPasswordDialog(
                                context: scaffoldContext,
                                ref: ref,
                                groupId: group.id,
                                groupName: group.name,
                                onJoined: onJoined,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
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
