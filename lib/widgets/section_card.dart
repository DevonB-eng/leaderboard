import 'package:flutter/material.dart';

import 'package:leaderboard/core/theme/app_theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
            child: Text(title, style: AppTextStyles.heading()),
          ),
          child,
        ],
      ),
    );
  }
}

class SubSectionCard extends StatelessWidget {
  const SubSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: AppBorders.box,
        borderRadius: AppBorders.radius,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: AppColors.primaryLight, size: 18),
          title: Text(title, style: AppTextStyles.body()),
          subtitle: Text(subtitle, style: AppTextStyles.label()),
          iconColor: AppColors.primaryBright,
          collapsedIconColor: AppColors.primaryLight,
          children: children,
        ),
      ),
    );
  }
}
