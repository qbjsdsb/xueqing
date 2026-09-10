import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/composer_draft_store.dart';
import 'package:xueqing/features/design_v2/v2_composers.dart';
import 'package:xueqing/features/design_v2/v2_fixture.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_data.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';
import 'package:xueqing/features/teacher_workspace/presentation/evidence_attachment_picker.dart';

void main() {
  const scope = 'quick-capture:user-a:org-a';
  const student = V2Student(
    id: 'student-a',
    name: '林同学',
    grade: '初三',
    subjects: ['语文'],
    openCaseCount: 1,
    updatedLabel: '已有更新',
    teacherSummary: '当前工作区 · 语文',
  );
  const focus = V2FocusItem(
    id: 'case-a',
    studentId: 'student-a',
    title: '作文分点意识不足',
    summary: '分点作答意识不足',
    nextStep: '继续跟进',
    dueLabel: '待安排',
    subject: '语文',
  );
  const data = V2WorkspaceData(
    students: [student],
    focusItems: [focus],
    timeline: [],
  );

  ComposerDraftSnapshot progressDraft({String caseId = 'case-a'}) =>
      ComposerDraftSnapshot(
        kind: 'progress',
        studentId: 'student-a',
        subject: '语文',
        caseId: caseId,
        state: const <String, dynamic>{
          'operation_id': 'operation-progress-stable',
          'photo_evidence_operation_id': 'operation-photo-stable',
          'body': '拍照前写好的教学处理不能丢。',
          'kind': 'intervention',
          'assessment_result': null,
          'next_step': 'continueTracking',
          'reminder_title': '',
          'reminder_date': null,
          'close_reason': 'resolved',
          'complete_current_action': false,
        },
        attachments: const [],
        savedAt: DateTime(2026, 9, 10, 19, 30),
      );

  testWidgets(
    'progress composer restores protected text and lost camera photo',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = InMemoryComposerDraftStore();
      final draft = progressDraft();
      final recovered = PickedEvidenceAttachment(
        attachmentId: '00000000-0000-4000-8000-000000000010',
        bytes: Uint8List.fromList(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
            'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          ),
        ),
        fileName: '恢复.png',
        contentType: 'image/png',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light(),
          home: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showV2ProgressComposer(
                  context,
                  studentName: '林同学',
                  subject: '语文',
                  caseTitle: '作文分点意识不足',
                  persistence: V2ProgressPersistence(
                    store: store,
                    scopeKey: scope,
                    studentId: 'student-a',
                    subject: '语文',
                    caseId: 'case-a',
                    operationId: 'operation-progress-stable',
                    photoEvidenceOperationId: 'operation-photo-stable',
                    initialDraft: draft,
                    lostAttachmentLoader: () async => recovered,
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(find.text('记录进展'), findsOneWidget);
      expect(find.text('拍照前写好的教学处理不能丢。'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      final saved = await store.load(scope);
      expect(saved?.state['operation_id'], 'operation-progress-stable');
      expect(
        saved?.state['photo_evidence_operation_id'],
        'operation-photo-stable',
      );
      expect(saved?.attachments, hasLength(1));
    },
  );

  testWidgets(
    'authorized progress draft automatically reopens exact active case',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = InMemoryComposerDraftStore();
      await store.save(scope, progressDraft());

      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light(),
          home: V2WorkspacePreview(
            data: data,
            composerDraftStore: store,
            composerDraftScopeKey: scope,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('记录进展'), findsOneWidget);
      expect(find.text('林同学 · 语文\n作文分点意识不足'), findsOneWidget);
      expect(find.text('拍照前写好的教学处理不能丢。'), findsOneWidget);
    },
  );

  testWidgets('progress draft for missing or unauthorized case is cleared', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = InMemoryComposerDraftStore();
    await store.save(scope, progressDraft(caseId: 'case-no-longer-authorized'));

    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: V2WorkspacePreview(
          data: data,
          composerDraftStore: store,
          composerDraftScopeKey: scope,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('拍照前写好的教学处理不能丢。'), findsNothing);
    expect(find.text('记录进展'), findsNothing);
    expect(await store.load(scope), isNull);
  });
}
