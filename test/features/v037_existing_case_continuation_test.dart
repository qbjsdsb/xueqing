import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_composers.dart';
import 'package:xueqing/features/design_v2/v2_fixture.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_data.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';
import 'package:xueqing/features/teacher_workspace/presentation/evidence_attachment_picker.dart';

void main() {
  Widget shell(Widget child) => MaterialApp(
    theme: V2Theme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('Quick Capture transfers fact and photo into an existing Case', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final attachment = PickedEvidenceAttachment(
      attachmentId: '00000000-0000-4000-8000-000000000099',
      bytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
      fileName: 'classroom.jpg',
      contentType: 'image/jpeg',
    );
    V2ExistingCaseOption? continuedCase;
    V2QuickCaptureDraft? continuedDraft;
    var newCaseSaves = 0;

    await tester.pumpWidget(
      shell(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showV2QuickCapture(
              context,
              studentName: '林同学',
              subjects: const <String>['语文'],
              existingCases: const <V2ExistingCaseOption>[
                V2ExistingCaseOption(
                  id: 'case-reading-1',
                  title: '阅读题容易漏看限制词',
                  subject: '语文',
                  statusLabel: '跟进中',
                  nextStepLabel: '周五再检查',
                  dueLabel: '周五',
                ),
                V2ExistingCaseOption(
                  id: 'case-reading-2',
                  title: '概括题信息筛选不全',
                  subject: '语文',
                  statusLabel: '跟进中',
                  nextStepLabel: '继续观察',
                  dueLabel: '待安排',
                ),
                V2ExistingCaseOption(
                  id: 'case-reading-3',
                  title: '说明文术语辨析不稳',
                  subject: '语文',
                  statusLabel: '跟进中',
                  nextStepLabel: '下次课复查',
                  dueLabel: '下周',
                ),
                V2ExistingCaseOption(
                  id: 'case-reading-4',
                  title: '论证思路容易漏掉层次',
                  subject: '语文',
                  statusLabel: '跟进中',
                  nextStepLabel: '待安排',
                  dueLabel: '待安排',
                ),
                V2ExistingCaseOption(
                  id: 'case-math',
                  title: '函数题思路不清',
                  subject: '数学',
                  statusLabel: '跟进中',
                  nextStepLabel: '再练两题',
                  dueLabel: '明天',
                ),
              ],
              attachmentPicker: (_) async => attachment,
              onSave: (_) async => newCaseSaves += 1,
              onContinueExisting: (option, draft) async {
                continuedCase = option;
                continuedDraft = draft;
              },
            ),
            child: const Text('打开记录'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开记录'));
    await tester.pumpAndSettle();

    expect(find.text('阅读题容易漏看限制词'), findsOneWidget);
    expect(find.text('论证思路容易漏掉层次'), findsNothing);
    expect(find.text('函数题思路不清'), findsNothing);
    expect(find.textContaining('已有问题'), findsWidgets);
    expect(find.text('查看其余 1 个问题'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('v2-quick-capture-body')),
      '今天两道阅读题又漏看“不正确的是”。',
    );
    await tester.tap(find.byKey(const Key('v2-media-add')));
    await tester.pumpAndSettle();

    final toggle = find.byKey(
      const Key('v2-quick-capture-existing-toggle-all'),
    );
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('论证思路容易漏掉层次'), findsOneWidget);

    final fourthCase = find.byKey(
      const Key('v2-quick-capture-existing-case-reading-4'),
    );
    await tester.ensureVisible(fourthCase);
    await tester.tap(fourthCase);
    await tester.pumpAndSettle();

    expect(newCaseSaves, 0);
    expect(continuedCase?.id, 'case-reading-4');
    expect(continuedDraft?.subject, '语文');
    expect(continuedDraft?.body, '今天两道阅读题又漏看“不正确的是”。');
    expect(continuedDraft?.attachments, hasLength(1));
    expect(
      continuedDraft?.attachments.single.attachmentId,
      attachment.attachmentId,
    );
  });

  testWidgets(
    'continuing a pending-verification Case stays an observation and keeps text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const data = V2WorkspaceData(
        students: <V2Student>[
          V2Student(
            id: 'student-1',
            name: '林同学',
            grade: '初三',
            subjects: <String>['语文'],
            openCaseCount: 1,
            updatedLabel: '已有更新',
            teacherSummary: '当前工作区 · 语文',
          ),
        ],
        focusItems: <V2FocusItem>[
          V2FocusItem(
            id: 'case-pending',
            studentId: 'student-1',
            title: '阅读题容易漏看限制词',
            summary: '上一次已经完成针对性训练，等待后续复查。',
            nextStep: '下次课复查',
            dueLabel: '明天',
            subject: '语文',
            pendingVerification: true,
            caseStatus: V2CaseStatus.pendingVerification,
          ),
        ],
        timeline: <V2TimelineEntry>[],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light(),
          home: const V2WorkspacePreview(data: data),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('v2-today-quick-capture')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('v2-quick-capture-body')),
        '今天课堂上又漏看了一次限制词。',
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('v2-quick-capture-existing-case-pending')),
      );
      await tester.pumpAndSettle();

      expect(find.text('记到已有问题'), findsOneWidget);
      expect(find.text('今天课堂上又漏看了一次限制词。'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '保存到原问题'), findsOneWidget);
      expect(find.text('通过'), findsNothing);
      expect(find.text('部分通过'), findsNothing);
      expect(find.text('未通过'), findsNothing);
      expect(find.text('新表现'), findsOneWidget);
    },
  );
}
