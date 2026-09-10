import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/composer_draft_store.dart';
import 'package:xueqing/features/design_v2/v2_composers.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/teacher_workspace/presentation/evidence_attachment_picker.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
    theme: V2Theme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  final pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  testWidgets(
    'camera boundary persists current quick-capture text before picker',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = InMemoryComposerDraftStore();
      ComposerDraftSnapshot? snapshotDuringPicker;
      const scope = 'quick-capture:user-1:org-1';

      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => showV2QuickCapture(
                context,
                studentName: '林同学',
                subjects: const ['语文'],
                persistence: V2QuickCapturePersistence(
                  store: store,
                  scopeKey: scope,
                  studentId: 'student-1',
                  operationId: 'operation-1',
                ),
                attachmentPicker: (_) async {
                  snapshotDuringPicker = await store.load(scope);
                  return null;
                },
                onSave: (_) async {},
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('v2-quick-capture-body')),
        '文言文翻译今天还是不稳定。',
      );
      await tester.tap(find.byKey(const Key('v2-media-add')));
      await tester.pumpAndSettle();

      expect(snapshotDuringPicker, isNotNull);
      expect(snapshotDuringPicker!.studentId, 'student-1');
      expect(snapshotDuringPicker!.subject, '语文');
      expect(snapshotDuringPicker!.state['operation_id'], 'operation-1');
      expect(snapshotDuringPicker!.state['body'], '文言文翻译今天还是不稳定。');
    },
  );

  testWidgets(
    'recovered draft merges Android lost photo and clears after save',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = InMemoryComposerDraftStore();
      const scope = 'quick-capture:user-1:org-1';
      final snapshot = ComposerDraftSnapshot(
        kind: 'quick_capture',
        studentId: 'student-1',
        subject: '语文',
        state: const <String, dynamic>{
          'operation_id': 'operation-2',
          'case_type_key': 'builtin:knowledge',
          'body': '相机打开前已经写好的内容。',
          'show_more': true,
        },
        attachments: const [],
        savedAt: DateTime(2026, 9, 10, 16),
      );
      await store.save(scope, snapshot);

      final recoveredPhoto = PickedEvidenceAttachment(
        attachmentId: '00000000-0000-4000-8000-000000000099',
        bytes: pngBytes,
        fileName: 'camera.png',
        contentType: 'image/png',
      );
      V2QuickCaptureDraft? savedDraft;

      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => showV2QuickCapture(
                context,
                studentName: '林同学',
                subjects: const ['语文'],
                persistence: V2QuickCapturePersistence(
                  store: store,
                  scopeKey: scope,
                  studentId: 'student-1',
                  operationId: 'operation-2',
                  initialDraft: snapshot,
                  lostAttachmentLoader: () async => recoveredPhoto,
                ),
                attachmentPicker: (_) async => null,
                onSave: (draft) async => savedDraft = draft,
              ),
              child: const Text('恢复'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('恢复'));
      await tester.pumpAndSettle();

      expect(find.text('相机打开前已经写好的内容。'), findsOneWidget);
      expect(find.byKey(const ValueKey('v2-media-remove-0')), findsOneWidget);
      expect(find.text('知识漏洞'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '记录问题'));
      await tester.pumpAndSettle();

      expect(savedDraft, isNotNull);
      expect(savedDraft!.body, '相机打开前已经写好的内容。');
      expect(savedDraft!.attachments, hasLength(1));
      expect(savedDraft!.attachments.single.fileName, 'camera.png');
      expect(await store.load(scope), isNull);
    },
  );

  test('quick capture draft scope separates users and organizations', () {
    expect(
      quickCaptureComposerScopeKey(
        sessionUserId: 'user-a',
        organizationId: 'org-a',
      ),
      'quick-capture:user-a:org-a',
    );
    expect(
      quickCaptureComposerScopeKey(
        sessionUserId: 'user-a',
        organizationId: 'org-b',
      ),
      isNot('quick-capture:user-a:org-a'),
    );
  });
}
