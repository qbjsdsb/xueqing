import 'dart:io';

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

  test('V2 desktop scrollbar exposes hover and drag affordance', () {
    final theme = V2Theme.light();
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

  test('V2 core workflow keeps teacher attention on next actions', () {
    final source = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();

    expect(source, contains("'v2-case-next-step-\${item.id}'"));
    expect(source, contains("'v2-case-more-\${item.id}'"));
    expect(source, contains('item.actionTiming != null'));
    expect(source, contains("_SectionTitle(title: '现在要做'"));
    expect(source, contains("_SectionTitle(title: '待安排'"));
    expect(source, contains("title: const Text('之后')"));
    expect(source, contains("const _SectionTitle(title: '最近学生')"));
    expect(source, contains('· 待复检'));
    expect(source, contains("label: const Text('处理')"));
    expect(source, isNot(contains("title: '待安排下一步'")));
    expect(source, isNot(contains("return '待验证';")));
    expect(source, contains('!widget.compact &&'));
    expect(source, contains('final expandedRail = width >= 1280;'));
    expect(
      source,
      contains('final studentPaneWidth = width < 900 ? 288.0 : 320.0;'),
    );
    expect(source, contains("student.updatedLabel != '暂无记录'"));
    expect(source, isNot(contains("label: const Text('删除问题')")));
  });

  test('V2 composers keep release-safe motion and touch targets', () {
    final source = File('lib/features/design_v2/v2_composers.dart')
        .readAsStringSync();

    expect(
      source,
      isNot(contains('duration: const Duration(milliseconds: 180),')),
    );
    expect(
      RegExp(r'AppMotion\.effectiveDuration\(context\)')
          .allMatches(source)
          .length,
      4,
    );
    expect(
      RegExp(r'BoxConstraints\(minHeight: 44\)').allMatches(source).length,
      greaterThanOrEqualTo(2),
    );
    expect(source, contains("key: ValueKey('v2-media-remove-\$index')"));
    expect(source, contains('width: 44'));
    expect(source, contains('height: 44'));
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
