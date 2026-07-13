import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0C0A1A);
  static const Color surface = Color(0xFF1A1530);
  static const Color surfaceRaised = Color(0xFF251E42);
  static const Color primary = Color(0xFF3D1875);
  static const Color primaryLight = Color(0xFF6B35C2);
  static const Color primaryBright = Color(0xFFA855F7);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9B7EC8);
  static const Color textMuted = Color(0xFF5C4A7A);
  static const Color error = Color(0xFFCF6679);
  static const Color success = Color(0xFF4CAF82);
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle display({double size = 36, Color color = AppColors.textPrimary}) {
    return GoogleFonts.vt323(
      fontSize: size,
      color: color,
      letterSpacing: 2.0,
    );
  }

  static TextStyle heading({double size = 18, Color color = AppColors.textPrimary}) {
    return GoogleFonts.shareTechMono(
      fontSize: size,
      color: color,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.0,
    );
  }

  static TextStyle body({double size = 14, Color color = AppColors.textPrimary}) {
    return GoogleFonts.shareTechMono(
      fontSize: size,
      color: color,
      letterSpacing: 0.5,
    );
  }

  static TextStyle label({double size = 12, Color color = AppColors.textSecondary}) {
    return GoogleFonts.shareTechMono(
      fontSize: size,
      color: color,
      letterSpacing: 0.8,
    );
  }

  static TextStyle mono({double size = 13, Color color = AppColors.textSecondary}) {
    return GoogleFonts.shareTechMono(
      fontSize: size,
      color: color,
    );
  }
}

class AppBorders {
  AppBorders._();

  static const BorderSide thin = BorderSide(
    color: AppColors.primaryLight,
    width: 1.0,
  );

  static Border box = Border.all(
    color: AppColors.primaryLight,
    width: 1.0,
  );

  static Border boxThick = Border.all(
    color: AppColors.primaryBright,
    width: 2.0,
  );

  static const BorderRadius radius = BorderRadius.all(Radius.circular(4));
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

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        titleTextStyle: AppTextStyles.display(size: 28),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorders.radius,
          side: AppBorders.thin,
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textPrimary,
          textStyle: AppTextStyles.heading(size: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppBorders.radius,
            side: AppBorders.thin,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: AppBorders.thin,
          textStyle: AppTextStyles.heading(size: 14),
          shape: const RoundedRectangleBorder(borderRadius: AppBorders.radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBright,
          textStyle: AppTextStyles.body(),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.primaryLight,
        thickness: 1.0,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.primaryLight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceRaised,
        labelStyle: AppTextStyles.label(),
        hintStyle: AppTextStyles.label(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: AppBorders.radius,
          borderSide: AppBorders.thin,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppBorders.radius,
          borderSide: AppBorders.thin,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppBorders.radius,
          borderSide: const BorderSide(color: AppColors.primaryBright, width: 1.5),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryBright;
          return AppColors.surfaceRaised;
        }),
        checkColor: WidgetStateProperty.all(AppColors.textPrimary),
        side: AppBorders.thin,
        shape: const RoundedRectangleBorder(borderRadius: AppBorders.radius),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        backgroundColor: AppColors.surface,
        collapsedBackgroundColor: AppColors.surface,
        iconColor: AppColors.primaryBright,
        collapsedIconColor: AppColors.primaryLight,
        textColor: AppColors.textPrimary,
        collapsedTextColor: AppColors.textPrimary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: AppTextStyles.body(),
        shape: RoundedRectangleBorder(
          borderRadius: AppBorders.radius,
          side: AppBorders.thin,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: AppColors.surface,
        textColor: AppColors.textPrimary,
        iconColor: AppColors.primaryLight,
        subtitleTextStyle: AppTextStyles.label(),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryBright,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorders.radius,
          side: AppBorders.thin,
        ),
        titleTextStyle: AppTextStyles.heading(),
        contentTextStyle: AppTextStyles.body(),
      ),
    );
  }
}
