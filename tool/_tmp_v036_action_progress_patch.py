from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


composer_path = Path('lib/features/design_v2/v2_composers.dart')
composer = composer_path.read_text()
composer = replace_once(
    composer,
    "    V2NextStep.remind => '提醒我再检查',",
    "    V2NextStep.remind => '安排再次检查',",
    'next-step label',
)
composer = replace_once(
    composer,
    "  bool canCompleteCurrentAction = false,\n  DateTime? businessDate,",
    "  bool canCompleteCurrentAction = false,\n  bool completeCurrentActionInitially = false,\n  DateTime? businessDate,",
    'show progress parameters',
)
composer = replace_once(
    composer,
    "          canCompleteCurrentAction: canCompleteCurrentAction,\n          businessDate: businessDate,",
    "          canCompleteCurrentAction: canCompleteCurrentAction,\n          completeCurrentActionInitially: completeCurrentActionInitially,\n          businessDate: businessDate,",
    'show progress forwarding',
)
composer = replace_once(
    composer,
    "    this.canCompleteCurrentAction = false,\n    this.businessDate,",
    "    this.canCompleteCurrentAction = false,\n    this.completeCurrentActionInitially = false,\n    this.businessDate,",
    'composer constructor',
)
composer = replace_once(
    composer,
    "  final bool canCompleteCurrentAction;\n  final DateTime? businessDate;",
    "  final bool canCompleteCurrentAction;\n  final bool completeCurrentActionInitially;\n  final DateTime? businessDate;",
    'composer field',
)
composer = replace_once(
    composer,
    "    _kind = widget.initialKind;\n    final initialDraft = widget.persistence?.initialDraft;",
    "    _kind = widget.initialKind;\n    _completeCurrentAction =\n        widget.canCompleteCurrentAction &&\n        widget.completeCurrentActionInitially;\n    final initialDraft = widget.persistence?.initialDraft;",
    'initial completion state',
)
old_has_draft = """  bool get _hasDraft =>
      _controller.text.trim().isNotEmpty ||
      _attachments.isNotEmpty ||
      _kind != widget.initialKind ||
      _nextStep != V2NextStep.continueTracking ||
      _assessmentResult != null ||
      _reminderController.text.trim().isNotEmpty ||
      _reminderDate != null ||
      _completeCurrentAction;

  bool get _canSave {
    if (_saving || _controller.text.trim().isEmpty) {
      return false;
    }
    if (_kind == V2ProgressKind.assessment && _assessmentResult == null) {
      return false;
    }
    if (_nextStep == V2NextStep.remind && _reminderDate == null) {
      return false;
    }
    return true;
  }
"""
new_has_draft = """  bool get _initialCompleteCurrentAction =>
      widget.canCompleteCurrentAction &&
      widget.completeCurrentActionInitially;

  bool get _hasDraft =>
      _controller.text.trim().isNotEmpty ||
      _attachments.isNotEmpty ||
      _kind != widget.initialKind ||
      _nextStep != V2NextStep.continueTracking ||
      _assessmentResult != null ||
      _reminderController.text.trim().isNotEmpty ||
      _reminderDate != null ||
      _completeCurrentAction != _initialCompleteCurrentAction;

  bool get _canSave {
    if (_saving || _controller.text.trim().isEmpty) {
      return false;
    }
    if (_kind == V2ProgressKind.assessment && _assessmentResult == null) {
      return false;
    }
    return true;
  }
"""
composer = replace_once(composer, old_has_draft, new_has_draft, 'draft/save rules')
composer = replace_once(
    composer,
    "                      const Expanded(child: Text('同时完成当前待办')),",
    "                      const Expanded(child: Text('同时完成当前提醒')),",
    'completion wording',
)
old_step = """                onTap: () {
                  setState(() {
                    _nextStep = step;
                    if (step == V2NextStep.close) {
                      _completeCurrentAction = false;
                    }
                  });
                  unawaited(_persistDraftSilently());
                },
"""
new_step = """                onTap: () {
                  final previousStep = _nextStep;
                  setState(() {
                    _nextStep = step;
                    if (step == V2NextStep.close) {
                      _completeCurrentAction = false;
                    } else if (previousStep == V2NextStep.close &&
                        _initialCompleteCurrentAction) {
                      _completeCurrentAction = true;
                    }
                  });
                  unawaited(_persistDraftSilently());
                },
"""
composer = replace_once(composer, old_step, new_step, 'next-step transition')
old_date = """                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          key: const Key('v2-reminder-date'),
                          onPressed: _chooseReminderDate,
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 17,
                          ),
                          label: Text(
                            _reminderDate == null
                                ? '选择日期'
                                : '${_reminderDate!.month} 月 ${_reminderDate!.day} 日',
                          ),
                        ),
                      ),
"""
new_date = """                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              key: const Key('v2-reminder-date'),
                              onPressed: _chooseReminderDate,
                              icon: const Icon(
                                Icons.calendar_today_outlined,
                                size: 17,
                              ),
                              label: Text(
                                _reminderDate == null
                                    ? '选择日期（可选）'
                                    : '${_reminderDate!.month} 月 ${_reminderDate!.day} 日',
                              ),
                            ),
                            if (_reminderDate != null)
                              TextButton(
                                key: const Key('v2-reminder-clear-date'),
                                onPressed: () {
                                  setState(() => _reminderDate = null);
                                  unawaited(_persistDraftSilently());
                                },
                                child: const Text('暂不定日期'),
                              ),
                          ],
                        ),
                      ),
                      if (_reminderDate == null) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '暂不确定日期也可以保存，之后会出现在“待安排”。',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
"""
composer = replace_once(composer, old_date, new_date, 'optional reminder date')
composer_path.write_text(composer)

workspace_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
workspace = workspace_path.read_text()
complete_pattern = re.compile(
    r"Future<void> _showV2CompleteCurrentAction\(\n.*?\n}\n\nFuture<void> _showV2RescheduleCurrentAction\(",
    re.S,
)
complete_replacement = """Future<void> _showV2CompleteCurrentAction(
  BuildContext context,
  V2Student student,
  V2FocusItem item,
) async {
  final controller = _V2RuntimeScope.maybeOf(context)?.workflowController;
  final action = controller?.pendingActionFor(item.id);
  if (controller == null || action == null || !action.canComplete) {
    return;
  }
  await _showV2ProgressForCase(
    context,
    student,
    item,
    completeCurrentActionInitially: true,
  );
}

Future<void> _showV2RescheduleCurrentAction("""
workspace, count = complete_pattern.subn(complete_replacement, workspace, count=1)
if count != 1:
    raise SystemExit(f'complete action route: expected one match, found {count}')
workspace = replace_once(
    workspace,
    "  ComposerDraftSnapshot? initialDraft,\n}) async {",
    "  ComposerDraftSnapshot? initialDraft,\n  bool completeCurrentActionInitially = false,\n}) async {",
    'progress route parameter',
)
workspace = replace_once(
    workspace,
    "      : null;\n  final saved = await showV2ProgressComposer(\n",
    "      : null;\n  final storedCompletesCurrentAction =\n      initialDraft?.state['complete_current_action'] == true;\n  final treatingCurrentAction =\n      completeCurrentActionInitially || storedCompletesCurrentAction;\n  final saved = await showV2ProgressComposer(\n",
    'progress treatment mode',
)
workspace = replace_once(
    workspace,
    "    canCompleteCurrentAction:\n        controller?.hasPendingPrimaryAction(item.id) ?? false,\n    businessDate: controller?.businessDate,",
    "    canCompleteCurrentAction:\n        controller?.hasPendingPrimaryAction(item.id) ?? false,\n    completeCurrentActionInitially: treatingCurrentAction,\n    businessDate: controller?.businessDate,",
    'progress completion forwarding',
)
workspace = replace_once(
    workspace,
    "    composerTitle: item.pendingVerification ? '记录复检' : '记录进展',\n    primaryLabel: item.pendingVerification ? '保存复检' : '保存进展',",
    "    composerTitle: treatingCurrentAction\n        ? (item.pendingVerification ? '处理复检提醒' : '处理提醒')\n        : (item.pendingVerification ? '记录复检' : '记录进展'),\n    primaryLabel: treatingCurrentAction\n        ? (item.pendingVerification ? '保存复检处理' : '保存处理')\n        : (item.pendingVerification ? '保存复检' : '保存进展'),",
    'progress treatment wording',
)
workspace = replace_once(
    workspace,
    "                                    label: const Text('完成这一步'),",
    "                                    label: const Text('处理这一步'),",
    'case detail action wording',
)
workspace_path.write_text(workspace)

test_path = Path('test/features/design_v2_composers_test.dart')
tests = test_path.read_text()
tests = replace_once(
    tests,
    "      await tester.tap(find.text('提醒我再检查'));",
    "      await tester.tap(find.text('安排再次检查'));",
    'reminder selector test',
)
tests = replace_once(
    tests,
    """      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '保存进展'),
      );
      expect(save.onPressed, isNull);
""",
    """      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '保存进展'),
      );
      expect(save.onPressed, isNotNull);
      expect(
        find.text('暂不确定日期也可以保存，之后会出现在“待安排”。'),
        findsOneWidget,
      );
""",
    'undated reminder save test',
)
insertion = """
  testWidgets(
    'action handling starts with completion selected and can keep reminder undated',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      V2ProgressDraft? savedDraft;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => showV2ProgressComposer(
                context,
                studentName: '林同学',
                subject: '语文',
                caseTitle: '阅读概括不完整',
                canCompleteCurrentAction: true,
                completeCurrentActionInitially: true,
                composerTitle: '处理提醒',
                primaryLabel: '保存处理',
                attachmentPicker: (_) async => null,
                onSave: (draft) async => savedDraft = draft,
              ),
              child: const Text('处理提醒'),
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, '处理提醒'));
      await tester.pumpAndSettle();

      expect(find.text('同时完成当前提醒'), findsOneWidget);
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);

      await tester.enterText(
        find.byKey(const Key('v2-progress-body')),
        '今天复查时已经能主动圈出限制词。',
      );
      await tester.tap(find.text('安排再次检查'));
      await tester.pumpAndSettle();

      expect(find.text('选择日期（可选）'), findsOneWidget);
      final save = find.widgetWithText(FilledButton, '保存处理');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(savedDraft, isNotNull);
      expect(savedDraft!.completeCurrentAction, isTrue);
      expect(savedDraft!.nextStep, V2NextStep.remind);
      expect(savedDraft!.reminderDate, isNull);
    },
  );

"""
marker = "  testWidgets('Progress Composer can open directly in verification mode', (\n"
if marker not in tests:
    raise SystemExit('composer test insertion marker not found')
tests = tests.replace(marker, insertion + marker, 1)
test_path.write_text(tests)

contract = Path('test/features/v036_action_progress_closure_contract_test.dart')
contract.write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher reminder handling uses the full progress closure flow', () {
    final workspace = File(
      'lib/features/design_v2/v2_workspace_preview.dart',
    ).readAsStringSync();
    final composer = File(
      'lib/features/design_v2/v2_composers.dart',
    ).readAsStringSync();

    expect(workspace, contains('completeCurrentActionInitially: true'));
    expect(workspace, contains("label: const Text('处理这一步')"));
    expect(workspace, isNot(contains('showV2CompleteActionComposer(')));
    expect(workspace, contains("'处理提醒'"));
    expect(workspace, contains("'处理复检提醒'"));

    expect(composer, contains('completeCurrentActionInitially'));
    expect(composer, contains("V2NextStep.remind => '安排再次检查'"));
    expect(composer, contains("'选择日期（可选）'"));
    expect(
      composer,
      contains('暂不确定日期也可以保存，之后会出现在“待安排”。'),
    );
    expect(
      composer,
      isNot(
        contains(
          '_nextStep == V2NextStep.remind && _reminderDate == null',
        ),
      ),
    );
  });
}
""")
