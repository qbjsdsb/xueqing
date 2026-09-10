import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/composer_draft_store.dart';
import 'package:xueqing/features/design_v2/v2_fixture.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_data.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  const scope = 'quick-capture:user-a:org-a';
  const student = V2Student(
    id: 'student-a',
    name: '林同学',
    grade: '初三',
    subjects: ['语文'],
    openCaseCount: 0,
    updatedLabel: '已有更新',
    teacherSummary: '当前工作区 · 语文',
  );
  const data = V2WorkspaceData(
    students: [student],
    focusItems: [],
    timeline: [],
  );

  Widget app({
    required ComposerDraftStore store,
    V2WorkspaceData workspaceData = data,
  }) => MaterialApp(
    theme: V2Theme.light(),
    home: V2WorkspacePreview(
      data: workspaceData,
      composerDraftStore: store,
      composerDraftScopeKey: scope,
    ),
  );

  testWidgets(
    'authorized unfinished camera draft automatically reopens in V2',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = InMemoryComposerDraftStore();
      await store.save(
        scope,
        ComposerDraftSnapshot(
          kind: 'quick_capture',
          studentId: 'student-a',
          subject: '语文',
          state: const <String, dynamic>{
            'operation_id': 'operation-recovery',
            'case_type_key': 'unclassified',
            'body': '拍照前尚未保存的文言文问题。',
            'show_more': false,
          },
          attachments: const [],
          savedAt: DateTime(2026, 9, 10, 17),
        ),
      );

      await tester.pumpWidget(app(store: store));
      await tester.pumpAndSettle();

      expect(find.text('记录新问题'), findsOneWidget);
      expect(find.text('林同学 · 语文'), findsOneWidget);
      expect(find.text('拍照前尚未保存的文言文问题。'), findsOneWidget);
    },
  );

  testWidgets('draft for a no-longer-authorized student is never exposed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = InMemoryComposerDraftStore();
    await store.save(
      scope,
      ComposerDraftSnapshot(
        kind: 'quick_capture',
        studentId: 'student-no-longer-assigned',
        subject: '语文',
        state: const <String, dynamic>{
          'operation_id': 'operation-stale',
          'case_type_key': 'unclassified',
          'body': '这段旧草稿不应该被展示。',
          'show_more': false,
        },
        attachments: const [],
        savedAt: DateTime(2026, 9, 10, 17),
      ),
    );

    await tester.pumpWidget(app(store: store));
    await tester.pumpAndSettle();

    expect(find.text('这段旧草稿不应该被展示。'), findsNothing);
    expect(find.text('记录新问题'), findsNothing);
    expect(await store.load(scope), isNull);
  });
}
