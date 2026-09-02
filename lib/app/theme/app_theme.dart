import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

abstract final class AppTheme {
  static const fontFallback = <String>['Microsoft YaHei', 'Noto Sans CJK SC'];

  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.light,
        ).copyWith(
          surface: AppColors.surface,
          surfaceContainer: AppColors.canvas,
          surfaceContainerLow: AppColors.canvas,
          surfaceContainerHigh: AppColors.surfaceMuted,
          surfaceContainerHighest: AppColors.surfaceMuted,
          onSurface: AppColors.textPrimary,
          onSurfaceVariant: AppColors.textSecondary,
          outline: AppColors.border,
          outlineVariant: AppColors.border,
          primary: AppColors.accent,
          onPrimaryContainer: AppColors.accentStrong,
          primaryContainer: AppColors.surfaceAccent,
          onPrimary: Colors.white,
          error: AppColors.danger,
          onError: Colors.white,
          secondary: AppColors.textSecondary,
          onSecondary: Colors.white,
        );

    const bodyLarge = TextStyle(
      fontSize: 16,
      height: 1.6,
      color: AppColors.textPrimary,
      fontFamilyFallback: fontFallback,
    );
    const bodyMedium = TextStyle(
      fontSize: 15,
      height: 1.6,
      color: AppColors.textPrimary,
      fontFamilyFallback: fontFallback,
    );
    const bodySmall = TextStyle(
      fontSize: 13,
      height: 1.55,
      color: AppColors.textSecondary,
      fontFamilyFallback: fontFallback,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamilyFallback: fontFallback,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 26,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontFamilyFallback: fontFallback,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontFamilyFallback: fontFallback,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontFamilyFallback: fontFallback,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontFamilyFallback: fontFallback,
        ),
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: TextStyle(
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontFamilyFallback: fontFallback,
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          side: AppBorders.subtle,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          foregroundColor: Colors.white,
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.surfaceMuted,
          disabledForegroundColor: AppColors.textDisabled,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.touchTarget),
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.surfaceAccent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontFamilyFallback: fontFallback,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.touchTarget),
          foregroundColor: AppColors.accent,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.touchTarget,
            AppSpacing.touchTarget,
          ),
        ),
      ),
    );
  }
}
