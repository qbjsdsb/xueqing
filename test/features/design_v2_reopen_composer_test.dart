import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_reopen_composer.dart';
import 'package:xueqing/features/design_v2/v2_workflow_controller.dart';

void main() {
  testWidgets('failed reopen keeps exact content locked for safe retry', (
    tester,
  ) async {
    final drafts = <V2ReopenComposerDraft>[];
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V2ReopenCaseComposer(
            studentName: '林同学',
            subject: '语文',
            caseTitle: '阅读概括不完整',
            businessDate: DateTime(2026, 9, 10),
            onSave: (draft) async {
              drafts.add(draft);
              calls += 1;
              if (calls == 1) {
                throw const V2WorkflowSaveException(
                  '重新跟进尚未完成，请直接重试。',
                  recordMayBeSaved: true,
                );
              }
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('v2-reopen-summary')),
      '今天又出现漏掉结果信息的情况。',
    );
    await tester.enterText(
      find.byKey(const Key('v2-reopen-next-action')),
      '周五再检查一次概括题',
    );
    await tester.tap(find.byKey(const Key('v2-reopen-save')));
    await tester.pump();

    expect(find.text('重新跟进尚未完成，请直接重试。'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('v2-reopen-summary'))).enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('v2-reopen-next-action')))
          .enabled,
      isFalse,
    );

    await tester.tap(find.byKey(const Key('v2-reopen-save')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(drafts[0].recurrenceSummary, drafts[1].recurrenceSummary);
    expect(drafts[0].nextActionTitle, drafts[1].nextActionTitle);
    expect(drafts[1].recurrenceSummary, '今天又出现漏掉结果信息的情况。');
    expect(drafts[1].nextActionTitle, '周五再检查一次概括题');
  });

  testWidgets('stored reopen draft is restored read-only before retry', (
    tester,
  ) async {
    V2ReopenComposerDraft? submitted;
    final dueOn = DateTime(2026, 9, 12);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V2ReopenCaseComposer(
            studentName: '林同学',
            subject: '语文',
            caseTitle: '阅读概括不完整',
            businessDate: DateTime(2026, 9, 10),
            pendingDraft: V2ReopenDraftSnapshot(
              caseId: 'case-existing',
              recurrenceSummary: '昨天作业里再次漏掉结果。',
              nextActionTitle: '周五再核验',
              nextActionDueOn: dueOn,
            ),
            onSave: (draft) async => submitted = draft,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('v2-reopen-resume-note')), findsOneWidget);
    expect(find.text('昨天作业里再次漏掉结果。'), findsOneWidget);
    expect(find.text('周五再核验'), findsOneWidget);
    expect(find.text('9 月 12 日'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('v2-reopen-summary'))).enabled,
      isFalse,
    );

    await tester.tap(find.byKey(const Key('v2-reopen-save')));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.recurrenceSummary, '昨天作业里再次漏掉结果。');
    expect(submitted!.nextActionTitle, '周五再核验');
    expect(submitted!.nextActionDueOn, dueOn);
  });
}
