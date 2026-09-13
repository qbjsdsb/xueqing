from pathlib import Path

path = Path('test/features/organization_management_test.dart')
text = path.read_text()

old = """    final disableFinder = find.widgetWithText(PopupMenuItem, '停用成员');
    expect(disableFinder, findsOneWidget);
    expect(tester.widget<PopupMenuItem>(disableFinder).enabled, isFalse);
    expect(repository.memberStatusUpdateCount, 0);
"""
new = """    final disableFinder = find.text('停用成员');
    expect(disableFinder, findsOneWidget);
    await tester.tap(disableFinder);
    await tester.pumpAndSettle();
    expect(repository.memberStatusUpdateCount, 0);
"""
if old not in text:
    raise SystemExit('member menu behavior test anchor not found')
text = text.replace(old, new, 1)

old = """      expect(repository.studentTeacherAssignments.single.status, 'active');
      expect(find.text('正常教学'), findsOneWidget);
"""
new = """      expect(repository.studentTeacherAssignments.single.status, 'active');
      expect(find.text('暂不教学'), findsNothing);
"""
if old not in text:
    raise SystemExit('normal teaching visual assertion not found')
text = text.replace(old, new, 1)

old = """      expect(find.text('示例老师'), findsOneWidget);
      expect(find.text('数学'), findsOneWidget);
      final stop = find.text('停用');
      await tester.ensureVisible(stop);
      await tester.tap(stop);
      await tester.pumpAndSettle();
"""
new = """      expect(find.text('示例老师'), findsOneWidget);
      expect(find.text('数学'), findsOneWidget);
      final scopeMore = find.byTooltip('学科操作');
      await tester.ensureVisible(scopeMore);
      await tester.tap(scopeMore);
      await tester.pumpAndSettle();
      final stop = find.text('停用该学科');
      await tester.tap(stop);
      await tester.pumpAndSettle();
"""
if old not in text:
    raise SystemExit('teacher scope stop test anchor not found')
text = text.replace(old, new, 1)

path.write_text(text)
