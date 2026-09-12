import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_spacing.dart';

abstract final class AppTheme {
  static const fontFallback = <String>['Microsoft YaHei', 'Noto Sans CJK SC'];

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = _colorScheme(brightness);
    final textTheme = _textTheme(colorScheme);
    final isDark = brightness == Brightness.dark;
    final fieldFill = isDark
        ? colorScheme.surfaceContainerLow
        : colorScheme.surfaceContainerLowest;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamilyFallback: fontFallback,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      hoverColor: colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.045),
      focusColor: colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          animationDuration: AppMotion.quick,
          minimumSize: const Size(0, AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          foregroundColor: colorScheme.onPrimary,
          backgroundColor: colorScheme.primary,
          disabledBackgroundColor: colorScheme.surfaceContainerHighest,
          disabledForegroundColor: colorScheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          animationDuration: AppMotion.quick,
          minimumSize: const Size(0, AppSpacing.touchTarget),
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: colorScheme.primary),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.09),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
            fontFamilyFallback: fontFallback,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary.withValues(alpha: isDark ? 0.11 : 0.08),
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontFamilyFallback: fontFallback,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontFamilyFallback: fontFallback,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          animationDuration: AppMotion.quick,
          minimumSize: const Size(0, AppSpacing.touchTarget),
          foregroundColor: colorScheme.primary,
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
          foregroundColor: colorScheme.onSurfaceVariant,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 350),
        showDuration: const Duration(seconds: 2),
        preferBelow: false,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.onInverseSurface,
          fontSize: 12,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(AppRadii.pill),
        thickness: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged) ||
              states.contains(WidgetState.hovered)) {
            return 6;
          }
          return 4;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          final alpha = states.contains(WidgetState.dragged)
              ? 0.56
              : states.contains(WidgetState.hovered)
              ? 0.42
              : 0.30;
          return colorScheme.onSurfaceVariant.withValues(alpha: alpha);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: colorScheme.onInverseSurface,
          fontFamilyFallback: fontFallback,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        circularTrackColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }

  static ColorScheme _colorScheme(Brightness brightness) {
    final generated = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
    );
    if (brightness == Brightness.light) {
      return generated.copyWith(
        surface: AppColors.canvas,
        surfaceContainerLowest: AppColors.surface,
        surfaceContainerLow: AppColors.surface,
        surfaceContainer: AppColors.canvas,
        surfaceContainerHigh: AppColors.surfaceMuted,
        surfaceContainerHighest: AppColors.surfaceMuted,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.borderStrong,
        outlineVariant: AppColors.border,
        primary: AppColors.accent,
        onPrimary: Colors.white,
        primaryContainer: AppColors.surfaceAccent,
        onPrimaryContainer: AppColors.accentStrong,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.surfaceAccent,
        onSecondaryContainer: AppColors.accentStrong,
        tertiary: AppColors.info,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.infoSurface,
        onTertiaryContainer: AppColors.info,
        error: AppColors.danger,
        onError: Colors.white,
        errorContainer: AppColors.dangerSurface,
        onErrorContainer: AppColors.danger,
        surfaceTint: Colors.transparent,
      );
    }
    return generated.copyWith(
      surface: const Color(0xFF121412),
      surfaceDim: const Color(0xFF0E100F),
      surfaceBright: const Color(0xFF2C302D),
      surfaceContainerLowest: const Color(0xFF121412),
      surfaceContainerLow: const Color(0xFF171A18),
      surfaceContainer: const Color(0xFF1B1E1C),
      surfaceContainerHigh: const Color(0xFF222623),
      surfaceContainerHighest: const Color(0xFF2A2F2B),
      onSurface: const Color(0xFFE5E9E6),
      onSurfaceVariant: const Color(0xFFB9C1BC),
      outline: const Color(0xFF737C76),
      outlineVariant: const Color(0xFF363C38),
      primary: const Color(0xFF84CDB7),
      onPrimary: const Color(0xFF07372D),
      primaryContainer: const Color(0xFF183D33),
      onPrimaryContainer: const Color(0xFFC5EBDD),
      secondary: const Color(0xFF84CDB7),
      onSecondary: const Color(0xFF07372D),
      secondaryContainer: const Color(0xFF22322D),
      onSecondaryContainer: const Color(0xFFD7E7E0),
      tertiary: const Color(0xFFA9C7EF),
      onTertiary: const Color(0xFF103352),
      tertiaryContainer: const Color(0xFF294A6B),
      onTertiaryContainer: const Color(0xFFD3E5FF),
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
      surfaceTint: Colors.transparent,
    );
  }

  static TextTheme _textTheme(ColorScheme colorScheme) {
    return TextTheme(
      headlineSmall: TextStyle(
        fontSize: 26,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        fontFamilyFallback: fontFallback,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        fontFamilyFallback: fontFallback,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        fontFamilyFallback: fontFallback,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        fontFamilyFallback: fontFallback,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.6,
        color: colorScheme.onSurface,
        fontFamilyFallback: fontFallback,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        height: 1.6,
        color: colorScheme.onSurface,
        fontFamilyFallback: fontFallback,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.55,
        color: colorScheme.onSurfaceVariant,
        fontFamilyFallback: fontFallback,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        fontFamilyFallback: fontFallback,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurfaceVariant,
        fontFamilyFallback: fontFallback,
      ),
    );
  }
}
