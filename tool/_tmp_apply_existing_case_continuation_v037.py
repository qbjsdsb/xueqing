from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


composers_path = Path('lib/features/design_v2/v2_composers.dart')
composers = composers_path.read_text()

composers = replace_once(
    composers,
    """class V2ProgressDraft {
""",
    """class V2ExistingCaseOption {
  const V2ExistingCaseOption({
    required this.id,
    required this.title,
    required this.subject,
    required this.statusLabel,
    required this.nextStepLabel,
    required this.dueLabel,
  });

  final String id;
  final String title;
  final String subject;
  final String statusLabel;
  final String nextStepLabel;
  final String dueLabel;
}

typedef V2QuickCaptureContinueExisting = Future<void> Function(
  V2ExistingCaseOption option,
  V2QuickCaptureDraft draft,
);

class V2ProgressDraft {
""",
    'existing case option model',
)

composers = replace_once(
    composers,
    """  List<V2ProblemTypeOption> problemTypes = v2PreviewProblemTypeOptions,
  V2QuickCaptureSave? onSave,
  V2AttachmentPicker attachmentPicker = pickEvidenceAttachment,
  V2QuickCapturePersistence? persistence,
}) async {
""",
    """  List<V2ProblemTypeOption> problemTypes = v2PreviewProblemTypeOptions,
  List<V2ExistingCaseOption> existingCases = const <V2ExistingCaseOption>[],
  V2QuickCaptureSave? onSave,
  V2QuickCaptureContinueExisting? onContinueExisting,
  V2AttachmentPicker attachmentPicker = pickEvidenceAttachment,
  V2QuickCapturePersistence? persistence,
}) async {
""",
    'quick capture public continuation parameters',
)

composers = replace_once(
    composers,
    """          problemTypes: problemTypes,
          onSave: onSave,
          attachmentPicker: attachmentPicker,
          persistence: persistence,
""",
    """          problemTypes: problemTypes,
          existingCases: existingCases,
          onSave: onSave,
          onContinueExisting: onContinueExisting,
          attachmentPicker: attachmentPicker,
          persistence: persistence,
""",
    'quick capture pass continuation parameters',
)

composers = replace_once(
    composers,
    """  V2ProgressKind initialKind = V2ProgressKind.observation,
  String composerTitle = '记录进展',
  String primaryLabel = '保存进展',
  V2ProgressSave? onSave,
""",
    """  V2ProgressKind initialKind = V2ProgressKind.observation,
  String composerTitle = '记录进展',
  String primaryLabel = '保存进展',
  String initialBody = '',
  List<PickedEvidenceAttachment> initialAttachments =
      const <PickedEvidenceAttachment>[],
  V2ProgressSave? onSave,
""",
    'progress public initial values',
)

composers = replace_once(
    composers,
    """          initialKind: initialKind,
          composerTitle: composerTitle,
          primaryLabel: primaryLabel,
          onSave: onSave,
""",
    """          initialKind: initialKind,
          composerTitle: composerTitle,
          primaryLabel: primaryLabel,
          initialBody: initialBody,
          initialAttachments: initialAttachments,
          onSave: onSave,
""",
    'progress pass initial values',
)

composers = replace_once(
    composers,
    """    required this.problemTypes,
    required this.attachmentPicker,
    this.onSave,
    this.persistence,
""",
    """    required this.problemTypes,
    required this.attachmentPicker,
    this.existingCases = const <V2ExistingCaseOption>[],
    this.onSave,
    this.onContinueExisting,
    this.persistence,
""",
    'quick capture widget constructor',
)

composers = replace_once(
    composers,
    """  final List<V2ProblemTypeOption> problemTypes;
  final V2AttachmentPicker attachmentPicker;
  final V2QuickCaptureSave? onSave;
  final V2QuickCapturePersistence? persistence;
""",
    """  final List<V2ProblemTypeOption> problemTypes;
  final V2AttachmentPicker attachmentPicker;
  final List<V2ExistingCaseOption> existingCases;
  final V2QuickCaptureSave? onSave;
  final V2QuickCaptureContinueExisting? onContinueExisting;
  final V2QuickCapturePersistence? persistence;
""",
    'quick capture widget fields',
)

composers = replace_once(
    composers,
    """  bool get _canSave =>
      !_saving &&
      _selectedSubject != null &&
      _controller.text.trim().isNotEmpty;

  Future<void> _save() async {
""",
    """  bool get _canSave =>
      !_saving &&
      _selectedSubject != null &&
      _controller.text.trim().isNotEmpty;

  List<V2ExistingCaseOption> get _matchingExistingCases {
    final subject = _selectedSubject;
    if (subject == null) return const <V2ExistingCaseOption>[];
    return widget.existingCases
        .where((item) => item.subject == subject)
        .toList(growable: false);
  }

  V2QuickCaptureDraft _currentDraft() => V2QuickCaptureDraft(
    subject: _selectedSubject!,
    caseTypeKey: _problemTypeKey,
    body: _controller.text.trim(),
    attachments: List<PickedEvidenceAttachment>.unmodifiable(_attachments),
  );

  Future<void> _continueExisting(V2ExistingCaseOption option) async {
    final callback = widget.onContinueExisting;
    if (!_canSave || callback == null || option.subject != _selectedSubject) {
      return;
    }
    final draft = _currentDraft();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      if (widget.persistence != null) {
        await _persistDraft();
      }
      if (!mounted) return;
      Navigator.of(context).pop(false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(callback(option, draft));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = '暂时无法保护当前记录，请重试；已经输入的文字和图片仍在。';
      });
    }
  }

  Future<void> _save() async {
""",
    'quick capture continuation behavior',
)

composers = replace_once(
    composers,
    """    final draft = V2QuickCaptureDraft(
      subject: _selectedSubject!,
      caseTypeKey: _problemTypeKey,
      body: _controller.text.trim(),
      attachments: List<PickedEvidenceAttachment>.unmodifiable(_attachments),
    );
""",
    """    final draft = _currentDraft();
""",
    'reuse current quick capture draft',
)

composers = replace_once(
    composers,
    """  @override
  Widget build(BuildContext context) {
    return _ComposerScaffold(
      title: '记录新问题',
""",
    """  @override
  Widget build(BuildContext context) {
    final matchingExistingCases = _matchingExistingCases;
    return _ComposerScaffold(
      title: '记录新问题',
""",
    'quick capture existing case build state',
)

composers = replace_once(
    composers,
    """            ),
            const SizedBox(height: 12),
            V2MediaDraftStrip(
""",
    """            ),
            if (matchingExistingCases.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ExistingCaseContinuationPanel(
                totalCount: matchingExistingCases.length,
                items: matchingExistingCases.take(3).toList(growable: false),
                canContinue:
                    widget.onContinueExisting != null &&
                    _controller.text.trim().isNotEmpty &&
                    !_saving,
                onContinue: _continueExisting,
              ),
            ],
            const SizedBox(height: 12),
            V2MediaDraftStrip(
""",
    'quick capture existing case panel placement',
)

composers = replace_once(
    composers,
    """class V2ProgressComposer extends StatefulWidget {
""",
    """class _ExistingCaseContinuationPanel extends StatelessWidget {
  const _ExistingCaseContinuationPanel({
    required this.totalCount,
    required this.items,
    required this.canContinue,
    required this.onContinue,
  });

  final int totalCount;
  final List<V2ExistingCaseOption> items;
  final bool canContinue;
  final ValueChanged<V2ExistingCaseOption> onContinue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '这个学科还有 $totalCount 个问题正在跟进',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '如果刚才的情况属于已有问题，可以直接记到原问题；确实是新问题仍可继续记录。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[index].title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _existingCaseMeta(items[index]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    key: ValueKey<String>(
                      'v2-quick-capture-existing-${items[index].id}',
                    ),
                    onPressed: canContinue
                        ? () => onContinue(items[index])
                        : null,
                    child: const Text('记到这个问题'),
                  ),
                ],
              ),
            ),
          ],
          if (totalCount > items.length) ...[
            const SizedBox(height: 3),
            Text(
              '这里先显示最需要关注的 ${items.length} 个，其余可在学生详情中查看。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _existingCaseMeta(V2ExistingCaseOption item) {
    if (item.nextStepLabel == '待安排' && item.dueLabel == '待安排') {
      return '${item.statusLabel} · 下一步待安排';
    }
    return '${item.statusLabel} · 下一步 ${item.nextStepLabel} · ${item.dueLabel}';
  }
}

class V2ProgressComposer extends StatefulWidget {
""",
    'existing case continuation panel class',
)

composers = replace_once(
    composers,
    """    this.initialKind = V2ProgressKind.observation,
    this.composerTitle = '记录进展',
    this.primaryLabel = '保存进展',
    this.onSave,
""",
    """    this.initialKind = V2ProgressKind.observation,
    this.composerTitle = '记录进展',
    this.primaryLabel = '保存进展',
    this.initialBody = '',
    this.initialAttachments = const <PickedEvidenceAttachment>[],
    this.onSave,
""",
    'progress widget constructor initial values',
)

composers = replace_once(
    composers,
    """  final V2ProgressKind initialKind;
  final String composerTitle;
  final String primaryLabel;
  final V2ProgressSave? onSave;
""",
    """  final V2ProgressKind initialKind;
  final String composerTitle;
  final String primaryLabel;
  final String initialBody;
  final List<PickedEvidenceAttachment> initialAttachments;
  final V2ProgressSave? onSave;
""",
    'progress widget fields initial values',
)

composers = replace_once(
    composers,
    """    final initialDraft = widget.persistence?.initialDraft;
    if (initialDraft != null) {
      _applyInitialDraft(initialDraft);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_restoreLostAttachment());
      });
    }
""",
    """    final initialDraft = widget.persistence?.initialDraft;
    if (initialDraft != null) {
      _applyInitialDraft(initialDraft);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_restoreLostAttachment());
      });
    } else {
      _controller.text = widget.initialBody;
      _attachments.addAll(widget.initialAttachments.take(3));
      if (widget.persistence != null &&
          (_controller.text.trim().isNotEmpty || _attachments.isNotEmpty)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_persistDraftSilently());
        });
      }
    }
""",
    'progress apply transferred observation',
)

composers_path.write_text(composers)


preview_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
preview = preview_path.read_text()

preview = replace_once(
    preview,
    """  final problemTypes = controller == null
      ? v2PreviewProblemTypeOptions
      : controller.caseTypeChoices
            .map(
              (choice) =>
                  V2ProblemTypeOption(key: choice.key, label: choice.label),
            )
            .toList(growable: false);

  final saved = await showV2QuickCapture(
""",
    """  final problemTypes = controller == null
      ? v2PreviewProblemTypeOptions
      : controller.caseTypeChoices
            .map(
              (choice) =>
                  V2ProblemTypeOption(key: choice.key, label: choice.label),
            )
            .toList(growable: false);
  final activeItems = V2WorkspaceDataScope.of(
    context,
  ).focusItemsForStudent(student);
  final existingCases = activeItems
      .map(
        (item) => V2ExistingCaseOption(
          id: item.id,
          title: item.title,
          subject: item.subject,
          statusLabel: _caseStatusLabel(item),
          nextStepLabel: _displayNextStep(item.nextStep),
          dueLabel: item.dueLabel,
        ),
      )
      .toList(growable: false);

  final saved = await showV2QuickCapture(
""",
    'prepare existing cases for quick capture',
)

preview = replace_once(
    preview,
    """    problemTypes: problemTypes,
    persistence: persistence,
    onSave: controller == null
""",
    """    problemTypes: problemTypes,
    existingCases: existingCases,
    persistence: persistence,
    onContinueExisting: (option, draft) async {
      V2FocusItem? selected;
      for (final item in activeItems) {
        if (item.id == option.id && item.subject == draft.subject) {
          selected = item;
          break;
        }
      }
      if (selected == null || !context.mounted) return;
      await _showV2ProgressForCase(
        context,
        student,
        selected,
        transferredObservation: draft,
      );
    },
    onSave: controller == null
""",
    'wire quick capture existing continuation',
)

preview = replace_once(
    preview,
    """  ComposerDraftSnapshot? initialDraft,
  bool completeCurrentActionInitially = false,
}) async {
""",
    """  ComposerDraftSnapshot? initialDraft,
  bool completeCurrentActionInitially = false,
  V2QuickCaptureDraft? transferredObservation,
}) async {
""",
    'progress helper transferred observation parameter',
)

preview = replace_once(
    preview,
    """  final storedCompletesCurrentAction =
      initialDraft?.state['complete_current_action'] == true;
  final treatingCurrentAction =
      completeCurrentActionInitially || storedCompletesCurrentAction;
  final saved = await showV2ProgressComposer(
""",
    """  final storedCompletesCurrentAction =
      initialDraft?.state['complete_current_action'] == true;
  final treatingCurrentAction =
      completeCurrentActionInitially || storedCompletesCurrentAction;
  final continuingExisting = transferredObservation != null;
  final saved = await showV2ProgressComposer(
""",
    'progress helper continuation state',
)

preview = replace_once(
    preview,
    """    initialKind: item.pendingVerification
        ? V2ProgressKind.assessment
        : V2ProgressKind.observation,
    composerTitle: treatingCurrentAction
        ? (item.pendingVerification ? '处理复检提醒' : '处理提醒')
        : (item.pendingVerification ? '记录复检' : '记录进展'),
    primaryLabel: treatingCurrentAction
        ? (item.pendingVerification ? '保存复检处理' : '保存处理')
        : (item.pendingVerification ? '保存复检' : '保存进展'),
    persistence: persistence,
""",
    """    initialKind: continuingExisting
        ? V2ProgressKind.observation
        : item.pendingVerification
        ? V2ProgressKind.assessment
        : V2ProgressKind.observation,
    composerTitle: continuingExisting
        ? '记到已有问题'
        : treatingCurrentAction
        ? (item.pendingVerification ? '处理复检提醒' : '处理提醒')
        : (item.pendingVerification ? '记录复检' : '记录进展'),
    primaryLabel: continuingExisting
        ? '保存到原问题'
        : treatingCurrentAction
        ? (item.pendingVerification ? '保存复检处理' : '保存处理')
        : (item.pendingVerification ? '保存复检' : '保存进展'),
    initialBody: transferredObservation?.body ?? '',
    initialAttachments:
        transferredObservation?.attachments ?? const <PickedEvidenceAttachment>[],
    persistence: persistence,
""",
    'progress helper continuation presentation and transfer',
)

preview_path.write_text(preview)


test_path = Path('test/features/v037_existing_case_continuation_test.dart')
test_path.write_text("""import 'dart:convert';

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
                  id: 'case-reading',
                  title: '阅读题容易漏看限制词',
                  subject: '语文',
                  statusLabel: '跟进中',
                  nextStepLabel: '周五再检查',
                  dueLabel: '周五',
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
    expect(find.text('函数题思路不清'), findsNothing);
    expect(find.textContaining('已有问题'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('v2-quick-capture-body')),
      '今天两道阅读题又漏看“不正确的是”。',
    );
    await tester.tap(find.byKey(const Key('v2-media-add')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('v2-quick-capture-existing-case-reading')),
    );
    await tester.pumpAndSettle();

    expect(newCaseSaves, 0);
    expect(continuedCase?.id, 'case-reading');
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
        MaterialApp(theme: V2Theme.light(), home: const V2WorkspacePreview(data: data)),
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
""")
