import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/theme/app_motion.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';

void main() {
  test('V2 visual system stays restrained and interaction-led', () {
    final theme = V2Theme.light();
    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(theme.tooltipTheme.waitDuration, const Duration(milliseconds: 350));
    expect(theme.cardTheme.elevation, 0);
    expect(AppMotion.standard, const Duration(milliseconds: 180));
    expect(AppMotion.settle, const Duration(milliseconds: 240));
  });

  testWidgets('motion respects the platform reduced-motion preference', (
    tester,
  ) async {
    Duration? duration;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              duration = AppMotion.effectiveDuration(context, AppMotion.settle);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(duration, Duration.zero);
  });
}
