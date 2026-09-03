import 'package:flutter/material.dart';
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
}
