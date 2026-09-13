import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/app.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/config/app_config.dart';

void main() {
  test('builds coherent light and dark Material 3 themes', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();

    expect(light.useMaterial3, isTrue);
    expect(dark.useMaterial3, isTrue);
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.colorScheme.surface, isNot(dark.colorScheme.surface));
    expect(light.colorScheme.onSurface, isNot(dark.colorScheme.onSurface));
    expect(light.bottomSheetTheme.shape, isNotNull);
    expect(dark.bottomSheetTheme.shape, isNotNull);
    expect(
      light.navigationBarTheme.indicatorColor,
      light.colorScheme.primary.withValues(alpha: 0.09),
    );
    expect(
      dark.navigationBarTheme.indicatorColor,
      dark.colorScheme.primary.withValues(alpha: 0.12),
    );
    expect(
      light.navigationRailTheme.indicatorColor,
      light.colorScheme.primary.withValues(alpha: 0.08),
    );
    expect(
      dark.navigationRailTheme.indicatorColor,
      dark.colorScheme.primary.withValues(alpha: 0.11),
    );
  });

  test('desktop scrollbars become easier to target on hover and drag', () {
    final theme = AppTheme.light();
    final thickness = theme.scrollbarTheme.thickness!;
    final thumbColor = theme.scrollbarTheme.thumbColor!;

    expect(thickness.resolve(<WidgetState>{}), 4);
    expect(thickness.resolve(<WidgetState>{WidgetState.hovered}), 6);
    expect(thickness.resolve(<WidgetState>{WidgetState.dragged}), 6);
    expect(
      thumbColor.resolve(<WidgetState>{WidgetState.hovered}),
      isNot(thumbColor.resolve(<WidgetState>{})),
    );
    expect(
      thumbColor.resolve(<WidgetState>{WidgetState.dragged}),
      isNot(thumbColor.resolve(<WidgetState>{WidgetState.hovered})),
    );
  });

  testWidgets('follows the system theme at the app root', (tester) async {
    final config = AppConfig.fromValues(
      environmentValue: 'development',
      appVersion: '0.1.0+1',
    );
    await tester.pumpWidget(XueqingApp(config: config));

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.system);
    expect(materialApp.darkTheme, isNotNull);
  });

  testWidgets('keeps Android system bars aligned with the active app theme', (
    tester,
  ) async {
    final config = AppConfig.fromValues(
      environmentValue: 'development',
      appVersion: '0.1.0+1',
    );
    await tester.pumpWidget(XueqingApp(config: config));

    final lightSurface = AppTheme.light().colorScheme.surface;
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnnotatedRegion<SystemUiOverlayStyle> &&
            widget.value.statusBarColor == Colors.transparent &&
            widget.value.systemStatusBarContrastEnforced == false &&
            widget.value.systemNavigationBarColor == lightSurface &&
            widget.value.systemNavigationBarIconBrightness == Brightness.dark &&
            widget.value.systemNavigationBarContrastEnforced == false,
      ),
      findsAtLeastNWidgets(1),
    );
  });
}
