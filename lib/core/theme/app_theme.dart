import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Ground / surfaces
  static const Color background = Color(0xFFFDF8F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color divider = Color(0x1A121212);

  // Text
  static const Color ink = Color(0xFF121212);
  static const Color textPrimary = Color(0xFF121212);
  static const Color textSecondary = Color(0xFF474238); // kickers / labels
  static const Color textMuted = Color(0xFF645C50); // copy / secondary body

  // Sky — "you"
  static const Color sky = Color(0xFF89C2D9);
  static const Color skyDark = Color(0xFF0D3D4E);
  static const Color skyText = Color(0xFF2B7F99);
  static const Color skyBg = Color(0xFFDCEDF4);
  static const Color skyBgLight = Color(0xFFEAF5F9);

  // Sage — under average / good
  static const Color sage = Color(0xFF4CAF82);
  static const Color sageText = Color(0xFF1F6B4D);
  static const Color sageBg = Color(0xFFE4F4EC);

  // Coral — over average / destructive
  static const Color coral = Color(0xFFCF6679);
  static const Color coralStrong = Color(0xFFC1461E);
  static const Color coralText = Color(0xFF9B2F42);
  static const Color coralBg = Color(0xFFFAE7EA);
  static const Color coralBgLight = Color(0xFFFDF1F3);

  // Neutral tan
  static const Color tan = Color(0xFFF7F1E8);
  static const Color tanMuted = Color(0xFFEEE7DB);
  static const Color tanBorder = Color(0xFFDCD3C4);
  static const Color chartAvg = Color(0xFFC0B6A5);

  // Aliases used for semantic status
  static const Color error = coral;
  static const Color success = sage;
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.14),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> hero = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.13),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];
}

class AppRadii {
  AppRadii._();

  static const double card = 28;
  static const double row = 22;
  static const double small = 16;
  static const double pill = 999;
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle _mono({
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
    double? height,
  }) {
    return GoogleFonts.dmMono(
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Small uppercase section label ("YOUR SCREENTIME", "STANDINGS").
  static TextStyle kicker({double size = 10, Color color = AppColors.textSecondary}) {
    return _mono(size: size, color: color, letterSpacing: size * 0.2);
  }

  /// Screen title ("Leaderboard", "Settings & Info").
  static TextStyle title({double size = 23, Color color = AppColors.ink}) {
    return _mono(size: size, color: color, weight: FontWeight.w500, letterSpacing: -0.2);
  }

  /// The large hero number (e.g. "1h 58m").
  static TextStyle bigNumber({double size = 42, Color color = AppColors.ink}) {
    return _mono(size: size, color: color, weight: FontWeight.w400, letterSpacing: -1.2);
  }

  /// Standard body / row text.
  static TextStyle body({double size = 14, Color color = AppColors.ink, FontWeight weight = FontWeight.w400}) {
    return _mono(size: size, color: color, weight: weight);
  }

  /// Muted supporting copy / helper text.
  static TextStyle copy({double size = 13, Color color = AppColors.textMuted, double height = 1.6}) {
    return _mono(size: size, color: color, height: height);
  }

  /// Small field label ("USERNAME", "EMAIL").
  static TextStyle fieldLabel({double size = 10, Color color = AppColors.textSecondary}) {
    return _mono(size: size, color: color, letterSpacing: size * 0.16);
  }

  /// Pill / badge text.
  static TextStyle pill({double size = 12, Color color = AppColors.ink}) {
    return _mono(size: size, color: color, weight: FontWeight.w500);
  }
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.sky,
      colorScheme: const ColorScheme.light(
        primary: AppColors.sky,
        secondary: AppColors.skyText,
        surface: AppColors.surface,
        error: AppColors.coral,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        titleTextStyle: AppTextStyles.title(),
        iconTheme: const IconThemeData(color: AppColors.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sky,
          foregroundColor: AppColors.skyDark,
          textStyle: AppTextStyles.pill(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.tanBorder),
          textStyle: AppTextStyles.pill(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.skyText,
          textStyle: AppTextStyles.body(),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1.0,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.tan,
        labelStyle: AppTextStyles.fieldLabel(size: 12),
        hintStyle: AppTextStyles.copy(size: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          borderSide: const BorderSide(color: AppColors.sky, width: 1.5),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.sky;
          return AppColors.surface;
        }),
        checkColor: WidgetStateProperty.all(AppColors.skyDark),
        side: const BorderSide(color: AppColors.tanBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        backgroundColor: AppColors.surface,
        collapsedBackgroundColor: AppColors.surface,
        iconColor: AppColors.textSecondary,
        collapsedIconColor: AppColors.textSecondary,
        textColor: AppColors.ink,
        collapsedTextColor: AppColors.ink,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppTextStyles.body(color: AppColors.background),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: AppColors.surface,
        textColor: AppColors.ink,
        iconColor: AppColors.textSecondary,
        subtitleTextStyle: AppTextStyles.copy(size: 12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.sky,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        titleTextStyle: AppTextStyles.title(size: 18),
        contentTextStyle: AppTextStyles.body(),
      ),
    );
  }
}
