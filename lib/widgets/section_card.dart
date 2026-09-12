import 'package:flutter/material.dart';

import 'package:leaderboard/core/theme/app_theme.dart';

/// A kicker label followed by a floating white card — the base building
/// block of every section on Home and Settings.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.useHeroShadow = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool useHeroShadow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, subtitle == null ? 10 : 6),
          child: Text(title, style: AppTextStyles.kicker()),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(subtitle!, style: AppTextStyles.copy(size: 11, height: 1.5)),
          ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            boxShadow: useHeroShadow ? AppShadows.hero : AppShadows.card,
          ),
          child: child,
        ),
      ],
    );
  }
}

/// A collapsible white card used for "N members" / "N tracked" style rows
/// that expand into a list.
class CollapsibleCard extends StatefulWidget {
  const CollapsibleCard({
    super.key,
    required this.icon,
    required this.label,
    required this.children,
    this.initiallyExpanded = true,
    this.emptyPlaceholder,
  });

  final IconData icon;
  final String label;
  final List<Widget> children;
  final bool initiallyExpanded;
  final Widget? emptyPlaceholder;

  @override
  State<CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<CollapsibleCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: AppColors.sky,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, size: 15, color: AppColors.skyDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.label, style: AppTextStyles.body(size: 16)),
                ),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Divider(height: 1, color: AppColors.divider),
            ),
            const SizedBox(height: 6),
            if (widget.children.isEmpty && widget.emptyPlaceholder != null)
              widget.emptyPlaceholder!
            else
              ...widget.children,
          ],
        ],
      ),
    );
  }
}
