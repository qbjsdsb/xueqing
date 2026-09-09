import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_composers.dart';
import 'package:xueqing/features/teacher_workspace/presentation/evidence_attachment_picker.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
    theme: V2Theme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets(
    'Quick Capture requires subject when student has multiple subjects',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => showV2QuickCapture(
                context,
                studentName: '林同学',
                subjects: const ['语文', '数学'],
                attachmentPicker: (_) async => null,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(find.text('记录新问题'), findsOneWidget);
      expect(find.text('选择学科'), findsOneWidget);
      expect(find.text('语文'), findsOneWidget);
      expect(find.text('数学'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('v2-quick-capture-body')),
        '概括题遗漏结果。',
      );
      await tester.pump();

      var save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '记录问题'),
      );
      expect(save.onPressed, isNull);

      await tester.tap(find.text('数学'));
      await tester.pump();

      save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '记录问题'),
      );
      expect(save.onPressed, isNotNull);
    },
  );

  testWidgets(
    'Progress Composer progressively reveals assessment and reminder',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => showV2ProgressComposer(
                context,
                studentName: '林同学',
                subject: '语文',
                caseTitle: '阅读概括不完整',
                attachmentPicker: (_) async => null,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(find.text('记录进展'), findsOneWidget);
      expect(find.text('通过'), findsNothing);
      expect(find.byKey(const Key('v2-reminder-title')), findsNothing);

      await tester.tap(find.text('检查结果'));
      await tester.pumpAndSettle();

      expect(find.text('通过'), findsOneWidget);
      expect(find.text('部分通过'), findsOneWidget);
      expect(find.text('未通过'), findsOneWidget);

      await tester.tap(find.text('提醒我再检查'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('v2-reminder-title')), findsOneWidget);
      expect(find.byKey(const Key('v2-reminder-date')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('v2-progress-body')),
        '今天检查后仍有一个要点不稳定。',
      );
      await tester.pump();

      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '保存进展'),
      );
      expect(save.onPressed, isNull);
    },
  );

  testWidgets(
    'writable Quick Capture keeps text and photo when save fails, then retries',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var attempts = 0;
      final drafts = <V2QuickCaptureDraft>[];
      final attachment = PickedEvidenceAttachment(
        attachmentId: '00000000-0000-4000-8000-000000000001',
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
        fileName: 'work.jpg',
        contentType: 'image/jpeg',
      );

      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => showV2QuickCapture(
                context,
                studentName: '林同学',
                subjects: const ['语文'],
                problemTypes: const [
                  V2ProblemTypeOption(key: 'unclassified', label: '暂不分类'),
                  V2ProblemTypeOption(key: 'custom-reading', label: '阅读理解'),
                ],
                attachmentPicker: (_) async => attachment,
                onSave: (draft) async {
                  attempts += 1;
                  drafts.add(draft);
                  if (attempts == 1) {
                    throw Exception('network timeout');
                  }
                },
              ),
              child: const Text('打开写入'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开写入'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('v2-quick-capture-body')),
        '概括题遗漏结果。',
      );
      await tester.tap(find.byKey(const Key('v2-media-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('v2-media-remove-0')), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '记录问题'));
      await tester.pumpAndSettle();

      expect(attempts, 1);
      expect(find.text('记录新问题'), findsOneWidget);
      expect(find.text('概括题遗漏结果。'), findsOneWidget);
      expect(find.byKey(const ValueKey('v2-media-remove-0')), findsOneWidget);
      expect(find.text('网络暂时不可用，当前文字和图片仍然保留，可以直接重试。'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '记录问题'));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(drafts, hasLength(2));
      expect(drafts[0].body, drafts[1].body);
      expect(
        drafts[0].attachments.single.attachmentId,
        drafts[1].attachments.single.attachmentId,
      );
      expect(find.text('记录新问题'), findsNothing);
    },
  );

  testWidgets('writable composer cannot be dismissed while save is in flight', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final saveCompleter = Completer<void>();
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showV2QuickCapture(
              context,
              studentName: '林同学',
              subjects: const ['语文'],
              attachmentPicker: (_) async => null,
              onSave: (_) => saveCompleter.future,
            ),
            child: const Text('打开保存测试'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开保存测试'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('v2-quick-capture-body')),
      '保存期间不能误关。',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '记录问题'));
    await tester.pump();

    expect(find.text('保存中…'), findsOneWidget);
    expect(find.text('记录新问题'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('记录新问题'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(find.text('记录新问题'), findsOneWidget);

    await tester.drag(find.text('记录新问题'), const Offset(0, 360));
    await tester.pump();
    expect(find.text('记录新问题'), findsOneWidget);

    saveCompleter.complete();
    await tester.pumpAndSettle();
    expect(find.text('记录新问题'), findsNothing);
  });
}
