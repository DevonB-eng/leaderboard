import 'package:flutter/material.dart';

import 'package:leaderboard/core/theme/app_theme.dart';

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Text(
        'I built this app soely for the purpose of bullying my friends. If you find it fun as well thats pretty awesome! Also if you are an engineering hiring manager looking to hire interns hit me up.',
        style: AppTextStyles.body(),
      ),
    );
  }
}
