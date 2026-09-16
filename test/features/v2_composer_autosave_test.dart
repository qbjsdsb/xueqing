import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/composer_draft_store.dart';
import 'package:xueqing/features/design_v2/v2_composers.dart';
import 'package:xueqing/features/design_v2/v2_draft_autosave_controller.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
    theme: V2Theme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('Quick Capture debounces typed text into the local draft', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = InMemoryComposerDraftStore();
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
                operationId: 'operation-quick-autosave',
              ),
              attachmentPicker: (_) async => null,
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
      '老师刚记录的这句话不应该等到拍照才被保护。',
    );

    await tester.pump(const Duration(milliseconds: 500));
    expect(await store.load(scope), isNull);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    final snapshot = await store.load(scope);
    expect(snapshot, isNotNull);
    expect(snapshot!.state['body'], '老师刚记录的这句话不应该等到拍照才被保护。');
    expect(snapshot.state['operation_id'], 'operation-quick-autosave');
  });

  testWidgets('Progress debounces body and reminder title into one draft', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = InMemoryComposerDraftStore();
    const scope = 'progress:user-1:org-1';

    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showV2ProgressComposer(
              context,
              studentName: '林同学',
              subject: '语文',
              caseTitle: '阅读概括不完整',
              persistence: V2ProgressPersistence(
                store: store,
                scopeKey: scope,
                studentId: 'student-1',
                subject: '语文',
                caseId: 'case-1',
                operationId: 'operation-progress-autosave',
                photoEvidenceOperationId: 'operation-photo-autosave',
              ),
              attachmentPicker: (_) async => null,
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('v2-progress-body')),
      '今天复检时仍然遗漏了一个限定词。',
    );
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump();

    var snapshot = await store.load(scope);
    expect(snapshot?.state['body'], '今天复检时仍然遗漏了一个限定词。');

    await tester.tap(find.text('安排再次检查'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('v2-reminder-title')),
      '下节课再检查同类题',
    );
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump();

    snapshot = await store.load(scope);
    expect(snapshot?.state['body'], '今天复检时仍然遗漏了一个限定词。');
    expect(snapshot?.state['reminder_title'], '下节课再检查同类题');
    expect(snapshot?.state['next_step'], V2NextStep.remind.name);
  });

  testWidgets('successful save cannot be resurrected by a pending autosave', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = InMemoryComposerDraftStore();
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
                operationId: 'operation-save-clear',
              ),
              attachmentPicker: (_) async => null,
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
      '输入后立刻保存。',
    );
    await tester.tap(find.widgetWithText(FilledButton, '记录问题'));
    await tester.pumpAndSettle();

    expect(await store.load(scope), isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(await store.load(scope), isNull);
  });

  testWidgets('discard cannot be resurrected by a pending autosave', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = InMemoryComposerDraftStore();
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
                operationId: 'operation-discard-clear',
              ),
              attachmentPicker: (_) async => null,
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
      '输入后立刻放弃。',
    );
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '放弃记录'));
    await tester.pumpAndSettle();

    expect(await store.load(scope), isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(await store.load(scope), isNull);
  });

  testWidgets('lifecycle transition flushes pending work before debounce', (
    tester,
  ) async {
    var persistCount = 0;
    final autosave = V2DraftAutosaveController(
      persist: () async => persistCount += 1,
    );
    addTearDown(autosave.dispose);

    autosave.schedule();
    autosave.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();

    expect(persistCount, 1);

    autosave.suspend();
    autosave.schedule();
    autosave.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 1));
    expect(persistCount, 1);
  });
}
