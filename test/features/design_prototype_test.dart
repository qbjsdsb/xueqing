import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/features/design_prototype/design_fixture.dart';
import 'package:xueqing/features/design_prototype/presentation/'
    'design_prototype_page.dart';

Future<void> _pumpPreview(
  WidgetTester tester,
  Size size, {
  Key? pageKey,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: DesignPrototypePage(key: pageKey),
    ),
  );
  await tester.pumpAndSettle();
}

void _resetView(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void main() {
  test('prototype Case status keeps the Foundation lifecycle', () {
    expect(
      PrototypeCaseStatus.values.map((status) => status.name).toList(),
      <String>[
        'newCase',
        'confirmed',
        'intervening',
        'pendingVerification',
        'stable',
        'closed',
      ],
    );
  });

  testWidgets('Today keeps pending verification and date buckets exclusive', (
    tester,
  ) async {
    addTearDown(() => _resetView(tester));
    await _pumpPreview(tester, const Size(390, 844));

    final today = find.byKey(const Key('today-work-section'));
    final pending = find.byKey(const Key('pending-verification-section'));
    final future = find.byKey(const Key('future-actions-section'));
    final undated = find.byKey(const Key('undated-actions-section'));
    const pendingTitle = '异分母比较时把分子分母直接相加';
    const futureTitle = '下次课检查两道依据题';

    expect(find.text('已逾期'), findsOneWidget);
    expect(find.text('今天到期'), findsWidgets);
    expect(find.text('未来'), findsOneWidget);
    expect(find.text('待验证'), findsWidgets);
    expect(find.text('待安排'), findsWidgets);
    expect(
      find.descendant(of: pending, matching: find.text(pendingTitle)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: today, matching: find.text(pendingTitle)),
      findsNothing,
    );
    expect(
      find.descendant(of: future, matching: find.text(futureTitle)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: today, matching: find.text(futureTitle)),
      findsNothing,
    );
    expect(
      find.descendant(of: undated, matching: find.text(futureTitle)),
      findsNothing,
    );

    final futureAction = DesignFixture.cases
        .firstWhere((learningCase) => learningCase.id == 'demo-case-b3')
        .primaryAction!;
    expect(futureAction.dueBucket, PrototypeActionDueBucket.future);
    expect(futureAction.dueDate!.isAfter(DesignFixture.previewDate), isTrue);
  });

  testWidgets(
    'navigates Student to Case and back with separate Case controls',
    (tester) async {
      addTearDown(() => _resetView(tester));
      final semanticsHandle = tester.ensureSemantics();
      await _pumpPreview(tester, const Size(390, 844));
      const caseTitle = '异分母比较时把分子分母直接相加';

      expect(find.bySemanticsLabel('打开 $caseTitle 的 Case 详情'), findsNothing);
      expect(
        find.bySemanticsLabel('Case 信息：示例学生甲 · $caseTitle'),
        findsOneWidget,
      );

      final studentRow = find.bySemanticsLabel('打开 示例学生甲 的学生详情');
      await tester.ensureVisible(studentRow);
      await tester.tap(studentRow);
      await tester.pumpAndSettle();
      expect(find.text('现在最重要的事'), findsOneWidget);

      final caseButtons = find.widgetWithText(OutlinedButton, '查看 Case');
      final viewCaseButton = caseButtons.first;
      expect(
        tester
            .getSemantics(viewCaseButton)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      await tester.ensureVisible(viewCaseButton);
      await tester.tap(viewCaseButton);
      await tester.pumpAndSettle();
      expect(find.text('Assessment / Verification'), findsWidgets);
      expect(find.widgetWithText(FilledButton, '确认稳定'), findsOneWidget);

      final confirmStableButton = find.widgetWithText(FilledButton, '确认稳定');
      await tester.ensureVisible(confirmStableButton);
      await tester.tap(confirmStableButton);
      await tester.pumpAndSettle();
      expect(find.text('设计预览：确认稳定只展示命令入口，不改变领域状态。'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '确认稳定'), findsOneWidget);

      final backButton = find.byTooltip('返回学生详情');
      await tester.ensureVisible(backButton);
      await tester.tap(backButton);
      await tester.pumpAndSettle();
      expect(find.text('当前 Learning Cases'), findsOneWidget);
      semanticsHandle.dispose();
    },
  );

  testWidgets('uses compact navigation and expanded navigation rail', (
    tester,
  ) async {
    addTearDown(() => _resetView(tester));

    await _pumpPreview(tester, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await _pumpPreview(tester, const Size(1280, 900));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('shows Today work queue and opens quick capture', (tester) async {
    addTearDown(() => _resetView(tester));
    await _pumpPreview(tester, const Size(390, 844));

    expect(find.text('今日'), findsWidgets);
    expect(find.text('已逾期'), findsOneWidget);
    expect(find.text('待验证'), findsWidgets);
    expect(find.text('待安排'), findsWidgets);

    await tester.tap(
      find.byKey(const Key('design-preview-today-record-question')),
    );
    await tester.pumpAndSettle();

    expect(find.text('问题标题 *'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<PrototypeStudent>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('示例学生甲 · 数学').last);
    await tester.enterText(find.byType(TextField).first, '记录一个新的课堂问题');
    await tester.tap(find.widgetWithText(FilledButton, '记录问题'));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pumpAndSettle();

    expect(find.text('已记录为待整理问题，并已显示在当前预览。'), findsOneWidget);

    await tester.tap(find.text('学生').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '记录一个新的课堂问题');
    await tester.pump();
    final filteredStudent = find.bySemanticsLabel('打开 示例学生甲 的学生详情');
    expect(filteredStudent, findsOneWidget);
    await tester.tap(filteredStudent);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Case 信息：示例学生甲 · 记录一个新的课堂问题'), findsWidgets);
    expect(find.textContaining('补充一条题目或课堂证据后再整理'), findsWidgets);

    await _pumpPreview(tester, const Size(390, 844), pageKey: UniqueKey());
    expect(find.text('记录一个新的课堂问题'), findsNothing);
  });

  testWidgets('keeps a draft visible for the current preview session', (
    tester,
  ) async {
    addTearDown(() => _resetView(tester));
    await _pumpPreview(tester, const Size(390, 844));

    await tester.tap(find.widgetWithText(FilledButton, '记录问题'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<PrototypeStudent>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('示例学生乙 · 英语').last);
    await tester.enterText(find.byType(TextField).first, '暂存一条课堂观察');
    await tester.tap(find.widgetWithText(OutlinedButton, '取消'));
    await tester.pumpAndSettle();

    expect(find.text('暂存这段记录？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '暂存草稿'));
    await tester.pumpAndSettle();

    expect(find.text('草稿已保留在本次预览会话中。'), findsOneWidget);
    expect(find.text('本次预览会话草稿'), findsOneWidget);
    expect(find.text('暂存一条课堂观察'), findsOneWidget);
  });

  testWidgets('keeps the fictional-data boundary explicit', (tester) async {
    addTearDown(() => _resetView(tester));
    final semanticsHandle = tester.ensureSemantics();
    await _pumpPreview(tester, const Size(390, 844));

    expect(find.bySemanticsLabel('设计预览，使用虚构数据，不写入云端'), findsOneWidget);
    expect(find.text('不写入云端'), findsOneWidget);

    await tester.tap(find.text('学生').last);
    await tester.pumpAndSettle();
    expect(find.byType(FocusableActionDetector), findsNWidgets(2));
    semanticsHandle.dispose();
  });

  testWidgets('focuses student search with the Windows keyboard shortcut', (
    tester,
  ) async {
    addTearDown(() => _resetView(tester));
    await _pumpPreview(tester, const Size(390, 844));

    await tester.tap(find.text('学生').last);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    final searchField = tester.widget<TextField>(find.byType(TextField));
    expect(searchField.focusNode?.hasFocus, isTrue);
  });
}
