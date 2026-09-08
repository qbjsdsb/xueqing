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

  testWidgets('Today derives work only from explicit Action date buckets', (
    tester,
  ) async {
    addTearDown(() => _resetView(tester));
    await _pumpPreview(tester, const Size(390, 844));

    final today = find.byKey(const Key('today-work-section'));
    final future = find.byKey(const Key('future-actions-section'));
    const pendingReminder = '再做两道迁移题并核对过程';
    const futureReminder = '下次课检查两道依据题';

    expect(today, findsOneWidget);
    expect(find.text('已逾期'), findsOneWidget);
    expect(find.text('今天到期'), findsOneWidget);
    expect(find.text('之后要处理'), findsOneWidget);
    expect(
      find.byKey(const Key('pending-verification-section')),
      findsNothing,
    );
    expect(find.byKey(const Key('undated-actions-section')), findsNothing);
    expect(
      find.descendant(of: future, matching: find.text(pendingReminder)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: today, matching: find.text(pendingReminder)),
      findsNothing,
    );
    expect(
      find.descendant(of: future, matching: find.text(futureReminder)),
      findsOneWidget,
    );

    final pendingCase = DesignFixture.cases.firstWhere(
      (learningCase) => learningCase.id == 'demo-case-a1',
    );
    expect(pendingCase.status, PrototypeCaseStatus.pendingVerification);
    expect(pendingCase.statusLabel, '继续关注');
    expect(pendingCase.primaryAction, isNotNull);
    expect(
      pendingCase.primaryAction!.dueBucket,
      PrototypeActionDueBucket.future,
    );

    final newCase = DesignFixture.cases.firstWhere(
      (learningCase) => learningCase.id == 'demo-case-b1',
    );
    expect(newCase.status, PrototypeCaseStatus.newCase);
    expect(newCase.statusLabel, '新记录');
    expect(newCase.primaryAction, isNull);
  });

  testWidgets('navigates Student to problem detail without legacy state commands', (
    tester,
  ) async {
    addTearDown(() => _resetView(tester));
    final semanticsHandle = tester.ensureSemantics();
    await _pumpPreview(tester, const Size(390, 844));
    const caseTitle = '异分母比较时把分子分母直接相加';

    expect(find.bySemanticsLabel('打开 $caseTitle 的 Case 详情'), findsNothing);
    expect(
      find.bySemanticsLabel('问题信息：示例学生甲 · $caseTitle'),
      findsOneWidget,
    );

    final studentRow = find.bySemanticsLabel('打开 示例学生甲 的学生详情');
    await tester.ensureVisible(studentRow);
    await tester.tap(studentRow);
    await tester.pumpAndSettle();
    expect(find.text('现在最重要的事'), findsOneWidget);
    expect(find.text('全部问题'), findsOneWidget);

    final viewProblemButton = find.widgetWithText(OutlinedButton, '查看问题').first;
    expect(
      tester
          .getSemantics(viewProblemButton)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    await tester.ensureVisible(viewProblemButton);
    await tester.tap(viewProblemButton);
    await tester.pumpAndSettle();

    expect(find.text('检查结果'), findsOneWidget);
    expect(find.text('继续关注'), findsOneWidget);
    expect(find.text('确认稳定'), findsNothing);
    expect(find.text('安排下一次检查'), findsNothing);
    expect(find.widgetWithText(FilledButton, '处理'), findsOneWidget);

    final handleButton = find.widgetWithText(FilledButton, '处理');
    await tester.ensureVisible(handleButton);
    await tester.tap(handleButton);
    await tester.pumpAndSettle();
    expect(find.text('处理 入口已定义；当前预览不会写入业务数据。'), findsOneWidget);

    final backButton = find.byTooltip('返回学生详情');
    await tester.ensureVisible(backButton);
    await tester.tap(backButton);
    await tester.pumpAndSettle();
    expect(find.text('全部问题'), findsOneWidget);
    semanticsHandle.dispose();
  });

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

  testWidgets('Quick Capture records one fact without manufacturing a task', (
    tester,
  ) async {
    addTearDown(() => _resetView(tester));
    await _pumpPreview(tester, const Size(390, 844));

    expect(find.text('今日'), findsWidgets);
    expect(find.text('已逾期'), findsOneWidget);
    expect(find.text('之后要处理'), findsOneWidget);
    expect(find.byKey(const Key('undated-actions-section')), findsNothing);

    await tester.tap(
      find.byKey(const Key('design-preview-today-record-question')),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天发现什么？ *'), findsOneWidget);
    expect(find.text('问题标题 *'), findsNothing);
    expect(find.text('补充说明（可选）'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<PrototypeStudent>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('示例学生甲 · 数学').last);
    await tester.enterText(
      find.byKey(const Key('design-preview-quick-capture-note')),
      '记录一个新的课堂问题',
    );
    await tester.tap(
      find.byKey(const Key('design-preview-quick-capture-save')),
    );
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pumpAndSettle();

    expect(find.text('已记录到学生成长记录，并已显示在当前预览。'), findsOneWidget);
    expect(find.byKey(const Key('undated-actions-section')), findsNothing);

    await tester.tap(find.text('学生').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '记录一个新的课堂问题');
    await tester.pump();
    final filteredStudent = find.bySemanticsLabel('打开 示例学生甲 的学生详情');
    expect(filteredStudent, findsOneWidget);
    await tester.tap(filteredStudent);
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('问题信息：示例学生甲 · 记录一个新的课堂问题'),
      findsWidgets,
    );
    expect(find.text('新记录'), findsWidgets);
    expect(find.text('当前没有设置提醒'), findsWidgets);
    expect(find.textContaining('补充一条题目或课堂证据后再整理'), findsNothing);

    await _pumpPreview(tester, const Size(390, 844), pageKey: UniqueKey());
    expect(find.text('记录一个新的课堂问题'), findsNothing);
  });

  testWidgets('student-context Quick Capture does not ask for the student again', (
    tester,
  ) async {
    addTearDown(() => _resetView(tester));
    await _pumpPreview(tester, const Size(390, 844));

    final studentRow = find.bySemanticsLabel('打开 示例学生甲 的学生详情');
    await tester.ensureVisible(studentRow);
    await tester.tap(studentRow);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '记录问题').first);
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<PrototypeStudent>), findsNothing);
    expect(find.text('示例学生甲 · 数学'), findsOneWidget);
    expect(find.text('今天发现什么？ *'), findsOneWidget);
  });

  testWidgets('keeps a draft visible for the current preview session', (
    tester,
  ) async {
    addTearDown(() => _resetView(tester));
    await _pumpPreview(tester, const Size(390, 844));

    await tester.tap(
      find.byKey(const Key('design-preview-today-record-question')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<PrototypeStudent>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('示例学生乙 · 英语').last);
    await tester.enterText(
      find.byKey(const Key('design-preview-quick-capture-note')),
      '暂存一条课堂观察',
    );
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
