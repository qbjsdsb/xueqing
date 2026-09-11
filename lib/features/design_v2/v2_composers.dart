import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_motion.dart';
import '../../cloud/composer_draft_store.dart';
import '../teacher_workspace/presentation/evidence_attachment_picker.dart';
import 'v2_workflow_controller.dart';

typedef V2AttachmentPicker = Future<PickedEvidenceAttachment?> Function(
  BuildContext context,
);

class V2ProblemTypeOption {
  const V2ProblemTypeOption({required this.key, required this.label});

  final String key;
  final String label;
}

const v2PreviewProblemTypeOptions = <V2ProblemTypeOption>[
  V2ProblemTypeOption(key: 'unclassified', label: '暂不分类'),
  V2ProblemTypeOption(key: 'builtin:knowledge', label: '知识漏洞'),
  V2ProblemTypeOption(key: 'builtin:habit', label: '学习习惯'),
  V2ProblemTypeOption(key: 'builtin:exam_strategy', label: '考试技巧'),
];

enum V2ProgressKind { observation, intervention, assessment }

extension V2ProgressKindLabel on V2ProgressKind {
  String get label => switch (this) {
    V2ProgressKind.observation => '新表现',
    V2ProgressKind.intervention => '教学处理',
    V2ProgressKind.assessment => '检查结果',
  };
}

enum V2AssessmentResult { passed, partial, notPassed }

extension V2AssessmentResultLabel on V2AssessmentResult {
  String get label => switch (this) {
    V2AssessmentResult.passed => '通过',
    V2AssessmentResult.partial => '部分通过',
    V2AssessmentResult.notPassed => '未通过',
  };
}

enum V2NextStep { continueTracking, remind, close }

extension V2NextStepLabel on V2NextStep {
  String get label => switch (this) {
    V2NextStep.continueTracking => '继续观察，不设提醒',
    V2NextStep.remind => '安排再次检查',
    V2NextStep.close => '结束跟进',
  };
}

enum V2CloseReason { resolved, pauseTracking, notIssue, other }

extension V2CloseReasonLabel on V2CloseReason {
  String get label => switch (this) {
    V2CloseReason.resolved => '问题已解决',
    V2CloseReason.pauseTracking => '暂不继续跟进',
    V2CloseReason.notIssue => '确认不是问题',
    V2CloseReason.other => '其他',
  };
}

class V2QuickCaptureDraft {
  const V2QuickCaptureDraft({
    required this.subject,
    required this.caseTypeKey,
    required this.body,
    required this.attachments,
  });

  final String subject;
  final String caseTypeKey;
  final String body;
  final List<PickedEvidenceAttachment> attachments;
}

class V2ProgressDraft {
  const V2ProgressDraft({
    required this.kind,
    required this.body,
    required this.attachments,
    required this.nextStep,
    required this.closeReason,
    required this.completeCurrentAction,
    this.assessmentResult,
    this.reminderTitle,
    this.reminderDate,
  });

  final V2ProgressKind kind;
  final String body;
  final List<PickedEvidenceAttachment> attachments;
  final V2AssessmentResult? assessmentResult;
  final V2NextStep nextStep;
  final String? reminderTitle;
  final DateTime? reminderDate;
  final V2CloseReason closeReason;
  final bool completeCurrentAction;
}

typedef V2QuickCaptureSave = Future<void> Function(V2QuickCaptureDraft draft);
typedef V2ProgressSave = Future<void> Function(V2ProgressDraft draft);

class V2QuickCapturePersistence {
  const V2QuickCapturePersistence({
    required this.store,
    required this.scopeKey,
    required this.studentId,
    required this.operationId,
    this.initialDraft,
    this.lostAttachmentLoader,
  });

  final ComposerDraftStore store;
  final String scopeKey;
  final String studentId;
  final String operationId;
  final ComposerDraftSnapshot? initialDraft;
  final EvidenceAttachmentLostDataLoader? lostAttachmentLoader;
}

class V2ProgressPersistence {
  const V2ProgressPersistence({
    required this.store,
    required this.scopeKey,
    required this.studentId,
    required this.subject,
    required this.caseId,
    required this.operationId,
    required this.photoEvidenceOperationId,
    this.initialDraft,
    this.lostAttachmentLoader,
  });

  final ComposerDraftStore store;
  final String scopeKey;
  final String studentId;
  final String subject;
  final String caseId;
  final String operationId;
  final String photoEvidenceOperationId;
  final ComposerDraftSnapshot? initialDraft;
  final EvidenceAttachmentLostDataLoader? lostAttachmentLoader;
}

Future<bool> showV2QuickCapture(
  BuildContext context, {
  required String studentName,
  required List<String> subjects,
  List<V2ProblemTypeOption> problemTypes = v2PreviewProblemTypeOptions,
  V2QuickCaptureSave? onSave,
  V2AttachmentPicker attachmentPicker = pickEvidenceAttachment,
  V2QuickCapturePersistence? persistence,
}) async {
  assert(subjects.isNotEmpty);
  assert(problemTypes.isNotEmpty);
  final saved =
      await _showAdaptiveComposer<bool>(
        context,
        child: V2QuickCaptureComposer(
          studentName: studentName,
          subjects: subjects,
          problemTypes: problemTypes,
          onSave: onSave,
          attachmentPicker: attachmentPicker,
          persistence: persistence,
        ),
      ) ??
      false;
  if (saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(onSave == null ? 'V2 预览：记录已完成，但没有写入正式学情。' : '已记录问题。'),
      ),
    );
  }
  return saved;
}

Future<bool> showV2ProgressComposer(
  BuildContext context, {
  required String studentName,
  required String subject,
  required String caseTitle,
  bool canCompleteCurrentAction = false,
  bool completeCurrentActionInitially = false,
  DateTime? businessDate,
  V2ProgressKind initialKind = V2ProgressKind.observation,
  String composerTitle = '记录进展',
  String primaryLabel = '保存进展',
  V2ProgressSave? onSave,
  V2AttachmentPicker attachmentPicker = pickEvidenceAttachment,
  V2ProgressPersistence? persistence,
}) async {
  final saved =
      await _showAdaptiveComposer<bool>(
        context,
        child: V2ProgressComposer(
          studentName: studentName,
          subject: subject,
          caseTitle: caseTitle,
          canCompleteCurrentAction: canCompleteCurrentAction,
          completeCurrentActionInitially: completeCurrentActionInitially,
          businessDate: businessDate,
          initialKind: initialKind,
          composerTitle: composerTitle,
          primaryLabel: primaryLabel,
          onSave: onSave,
          attachmentPicker: attachmentPicker,
          persistence: persistence,
        ),
      ) ??
      false;
  if (saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(onSave == null ? 'V2 预览：进展已完成，但没有写入正式学情。' : '已保存进展。'),
      ),
    );
  }
  return saved;
}

String _describeV2SaveError(Object error) {
  if (error is V2WorkflowSaveException) {
    return error.userMessage;
  }
  final detail = error.toString().toLowerCase();
  if (detail.contains('version_conflict')) {
    return '学情刚刚有更新，请关闭当前窗口，刷新后再记录。';
  }
  if (detail.contains('invalid_live_session') ||
      detail.contains('session') ||
      detail.contains('jwt')) {
    return '登录状态已变化，请重新登录后再保存。';
  }
  if (detail.contains('permission') ||
      detail.contains('forbidden') ||
      detail.contains('teaching_fact_gate') ||
      detail.contains('owner_permission_required') ||
      detail.contains('assignment')) {
    return '当前任课关系或权限已经变化，请刷新后再试。';
  }
  if (detail.contains('network') ||
      detail.contains('socket') ||
      detail.contains('timeout') ||
      detail.contains('connection')) {
    return '网络暂时不可用，当前文字和图片仍然保留，可以直接重试。';
  }
  return '暂时保存失败，当前输入没有清空，请重试。';
}

enum _V2DraftCloseAction { keepEditing, retry, discard }

Future<_V2DraftCloseAction?> _showV2DraftCloseDialog(
  BuildContext context, {
  required bool saveFailed,
}) {
  return showDialog<_V2DraftCloseAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(saveFailed ? '这条记录还没有确认保存' : '放弃这段记录？'),
      content: Text(
        saveFailed
            ? '当前文字和图片仍然保留。建议直接重新保存；如果放弃，这段未确认保存的内容会丢失。'
            : '当前输入还没有保存。确定放弃后，这段文字和图片不会进入学生成长记录。',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(_V2DraftCloseAction.keepEditing),
          child: const Text('继续编辑'),
        ),
        if (saveFailed)
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_V2DraftCloseAction.discard),
            child: const Text('放弃记录'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(
            saveFailed
                ? _V2DraftCloseAction.retry
                : _V2DraftCloseAction.discard,
          ),
          child: Text(saveFailed ? '重新保存' : '放弃记录'),
        ),
      ],
    ),
  );
}

Future<T?> _showAdaptiveComposer<T>(
  BuildContext context, {
  required Widget child,
}) {
  final compact = MediaQuery.sizeOf(context).width < 720;
  if (compact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      builder: (_) => child,
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 820),
        child: child,
      ),
    ),
  );
}

class V2QuickCaptureComposer extends StatefulWidget {
  const V2QuickCaptureComposer({
    required this.studentName,
    required this.subjects,
    required this.problemTypes,
    required this.attachmentPicker,
    this.onSave,
    this.persistence,
    super.key,
  });

  final String studentName;
  final List<String> subjects;
  final List<V2ProblemTypeOption> problemTypes;
  final V2AttachmentPicker attachmentPicker;
  final V2QuickCaptureSave? onSave;
  final V2QuickCapturePersistence? persistence;

  @override
  State<V2QuickCaptureComposer> createState() => _V2QuickCaptureComposerState();
}

class _V2QuickCaptureComposerState extends State<V2QuickCaptureComposer> {
  final _controller = TextEditingController();
  final _attachments = <PickedEvidenceAttachment>[];
  String? _selectedSubject;
  bool _showMore = false;
  late String _problemTypeKey;
  String? _mediaError;
  String? _saveError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _problemTypeKey = widget.problemTypes.first.key;
    if (widget.subjects.length == 1) {
      _selectedSubject = widget.subjects.single;
    }
    final initialDraft = widget.persistence?.initialDraft;
    if (initialDraft != null) {
      _applyInitialDraft(initialDraft);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _restoreLostAttachment();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyInitialDraft(ComposerDraftSnapshot snapshot) {
    final persistence = widget.persistence;
    if (persistence == null ||
        snapshot.kind != 'quick_capture' ||
        snapshot.studentId != persistence.studentId ||
        snapshot.state['operation_id'] != persistence.operationId) {
      return;
    }
    final subject = snapshot.subject;
    if (subject != null && widget.subjects.contains(subject)) {
      _selectedSubject = subject;
    }
    final caseTypeKey = snapshot.state['case_type_key'];
    if (caseTypeKey is String &&
        widget.problemTypes.any((option) => option.key == caseTypeKey)) {
      _problemTypeKey = caseTypeKey;
    }
    final body = snapshot.state['body'];
    if (body is String) {
      _controller.text = body;
    }
    final showMore = snapshot.state['show_more'];
    if (showMore is bool) {
      _showMore = showMore;
    }
    _attachments
      ..clear()
      ..addAll(
        snapshot.attachments
            .take(3)
            .map(
              (attachment) => PickedEvidenceAttachment(
                attachmentId: attachment.attachmentId,
                bytes: attachment.bytes,
                fileName: attachment.fileName,
                contentType: attachment.contentType,
              ),
            ),
      );
  }

  ComposerDraftSnapshot _draftSnapshot() {
    final persistence = widget.persistence!;
    return ComposerDraftSnapshot(
      kind: 'quick_capture',
      studentId: persistence.studentId,
      subject: _selectedSubject,
      state: <String, dynamic>{
        'operation_id': persistence.operationId,
        'case_type_key': _problemTypeKey,
        'body': _controller.text,
        'show_more': _showMore,
      },
      attachments: _attachments
          .map(
            (attachment) => ComposerDraftAttachment(
              attachmentId: attachment.attachmentId,
              bytes: attachment.bytes,
              fileName: attachment.fileName,
              contentType: attachment.contentType,
            ),
          )
          .toList(growable: false),
      savedAt: DateTime.now(),
    );
  }

  Future<void> _persistDraft() async {
    final persistence = widget.persistence;
    if (persistence == null) return;
    await persistence.store.save(persistence.scopeKey, _draftSnapshot());
  }

  Future<void> _persistDraftSilently() async {
    try {
      await _persistDraft();
    } catch (_) {
      // Best effort after an in-app state change. The external-picker boundary
      // below is strict and will not launch unless the draft was saved.
    }
  }

  Future<void> _clearPersistedDraft() async {
    final persistence = widget.persistence;
    if (persistence == null) return;
    try {
      await persistence.store.clear(persistence.scopeKey);
    } catch (_) {
      // A successful server write must not be reported as failed only because
      // local cleanup could not complete. Operation ids keep a stale retry safe.
    }
  }

  Future<void> _restoreLostAttachment() async {
    final persistence = widget.persistence;
    if (persistence?.initialDraft == null || _attachments.length >= 3) {
      return;
    }
    try {
      final loader =
          persistence?.lostAttachmentLoader ?? recoverLostEvidenceAttachment;
      final recovered = await loader();
      if (!mounted || recovered == null) return;
      if (_attachments.any(
        (attachment) => attachment.attachmentId == recovered.attachmentId,
      )) {
        return;
      }
      setState(() {
        _attachments.add(recovered);
        _mediaError = null;
      });
      await _persistDraftSilently();
    } catch (error) {
      if (!mounted) return;
      setState(() => _mediaError = describeEvidenceAttachmentError(error));
    }
  }

  Future<void> _pickAttachment() async {
    if (_saving || _attachments.length >= 3) {
      return;
    }
    if (widget.persistence != null) {
      try {
        await _persistDraft();
      } catch (_) {
        if (mounted) {
          setState(() {
            _mediaError = '暂时无法保护当前草稿，请稍后再拍照；已经输入的文字仍在当前窗口。';
          });
        }
        return;
      }
    }
    if (!mounted) return;
    try {
      final picked = await widget.attachmentPicker(context);
      if (!mounted || picked == null) {
        return;
      }
      setState(() {
        _attachments.add(picked);
        _mediaError = null;
      });
      await _persistDraftSilently();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _mediaError = describeEvidenceAttachmentError(error));
    }
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
    _persistDraftSilently();
  }

  bool get _hasDraft =>
      _controller.text.trim().isNotEmpty || _attachments.isNotEmpty;

  bool get _canSave =>
      !_saving &&
      _selectedSubject != null &&
      _controller.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) {
      return;
    }
    final onSave = widget.onSave;
    if (onSave == null) {
      await _clearPersistedDraft();
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    final draft = V2QuickCaptureDraft(
      subject: _selectedSubject!,
      caseTypeKey: _problemTypeKey,
      body: _controller.text.trim(),
      attachments: List<PickedEvidenceAttachment>.unmodifiable(_attachments),
    );
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await _persistDraftSilently();
      await onSave(draft);
      await _clearPersistedDraft();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      await _persistDraftSilently();
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = _describeV2SaveError(error);
        });
      }
    }
  }

  Future<void> _close() async {
    if (_saving) {
      return;
    }
    if (!_hasDraft) {
      await _clearPersistedDraft();
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    final action = await _showV2DraftCloseDialog(
      context,
      saveFailed: _saveError != null,
    );
    if (!mounted ||
        action == null ||
        action == _V2DraftCloseAction.keepEditing) {
      return;
    }
    if (action == _V2DraftCloseAction.retry) {
      await _save();
      return;
    }
    await _clearPersistedDraft();
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return _ComposerScaffold(
      title: '记录新问题',
      contextLine: _selectedSubject == null
          ? widget.studentName
          : '${widget.studentName} · $_selectedSubject',
      onClose: _saving ? null : _close,
      footer: _ComposerFooter(
        primaryLabel: '记录问题',
        onPrimary: _canSave ? _save : null,
        saving: _saving,
        previewMode: widget.onSave == null,
        errorText: _saveError,
      ),
      child: AbsorbPointer(
        absorbing: _saving,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.subjects.length > 1) ...[
              Text('选择学科', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              _InlineSelector<String>(
                key: const Key('v2-quick-capture-subject-selector'),
                value: _selectedSubject,
                values: widget.subjects,
                label: (value) => value,
                onChanged: (value) {
                  setState(() => _selectedSubject = value);
                  _persistDraftSilently();
                },
              ),
              const SizedBox(height: 22),
            ],
            Text('今天发现什么？', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              key: const Key('v2-quick-capture-body'),
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 7,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '写下刚才真实看到的题目、行为或表现…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            V2MediaDraftStrip(
              attachments: _attachments,
              onAdd: _pickAttachment,
              onRemove: _removeAttachment,
            ),
            if (_mediaError != null) ...[
              const SizedBox(height: 8),
              Text(
                _mediaError!,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              key: const Key('v2-quick-capture-more'),
              onPressed: () {
                setState(() => _showMore = !_showMore);
                _persistDraftSilently();
              },
              icon: Icon(_showMore ? Icons.expand_less : Icons.tune, size: 18),
              label: Text(_showMore ? '收起更多选项' : '更多选项'),
            ),
            AnimatedSize(
              duration: AppMotion.effectiveDuration(context),
              alignment: Alignment.topCenter,
              child: _showMore
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: DropdownButtonFormField<String>(
                        initialValue: _problemTypeKey,
                        decoration: const InputDecoration(labelText: '问题类型'),
                        items: widget.problemTypes
                            .map(
                              (option) => DropdownMenuItem(
                                value: option.key,
                                child: Text(option.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _problemTypeKey = value);
                            _persistDraftSilently();
                          }
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class V2ProgressComposer extends StatefulWidget {
  const V2ProgressComposer({
    required this.studentName,
    required this.subject,
    required this.caseTitle,
    required this.attachmentPicker,
    this.canCompleteCurrentAction = false,
    this.completeCurrentActionInitially = false,
    this.businessDate,
    this.initialKind = V2ProgressKind.observation,
    this.composerTitle = '记录进展',
    this.primaryLabel = '保存进展',
    this.onSave,
    this.persistence,
    super.key,
  });

  final String studentName;
  final String subject;
  final String caseTitle;
  final V2AttachmentPicker attachmentPicker;
  final bool canCompleteCurrentAction;
  final bool completeCurrentActionInitially;
  final DateTime? businessDate;
  final V2ProgressKind initialKind;
  final String composerTitle;
  final String primaryLabel;
  final V2ProgressSave? onSave;
  final V2ProgressPersistence? persistence;

  @override
  State<V2ProgressComposer> createState() => _V2ProgressComposerState();
}

class _V2ProgressComposerState extends State<V2ProgressComposer> {
  final _controller = TextEditingController();
  final _reminderController = TextEditingController();
  final _attachments = <PickedEvidenceAttachment>[];
  late V2ProgressKind _kind;
  V2NextStep _nextStep = V2NextStep.continueTracking;
  V2AssessmentResult? _assessmentResult;
  V2CloseReason _closeReason = V2CloseReason.resolved;
  DateTime? _reminderDate;
  bool _completeCurrentAction = false;
  String? _mediaError;
  String? _saveError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _completeCurrentAction =
        widget.canCompleteCurrentAction &&
        widget.completeCurrentActionInitially;
    final initialDraft = widget.persistence?.initialDraft;
    if (initialDraft != null) {
      _applyInitialDraft(initialDraft);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_restoreLostAttachment());
      });
    }
  }

  void _applyInitialDraft(ComposerDraftSnapshot snapshot) {
    final persistence = widget.persistence;
    if (persistence == null ||
        snapshot.kind != 'progress' ||
        snapshot.studentId != persistence.studentId ||
        snapshot.subject != persistence.subject ||
        snapshot.caseId != persistence.caseId ||
        snapshot.state['operation_id'] != persistence.operationId ||
        snapshot.state['photo_evidence_operation_id'] !=
            persistence.photoEvidenceOperationId) {
      return;
    }

    final body = snapshot.state['body'];
    if (body is String) _controller.text = body;
    final reminderTitle = snapshot.state['reminder_title'];
    if (reminderTitle is String) _reminderController.text = reminderTitle;

    final kindName = snapshot.state['kind'];
    for (final value in V2ProgressKind.values) {
      if (value.name == kindName) _kind = value;
    }
    final assessmentName = snapshot.state['assessment_result'];
    _assessmentResult = null;
    for (final value in V2AssessmentResult.values) {
      if (value.name == assessmentName) _assessmentResult = value;
    }
    final nextStepName = snapshot.state['next_step'];
    for (final value in V2NextStep.values) {
      if (value.name == nextStepName) _nextStep = value;
    }
    final closeReasonName = snapshot.state['close_reason'];
    for (final value in V2CloseReason.values) {
      if (value.name == closeReasonName) _closeReason = value;
    }
    final reminderDate = snapshot.state['reminder_date'];
    if (reminderDate is String) {
      _reminderDate = DateTime.tryParse(reminderDate)?.toLocal();
    }
    final complete = snapshot.state['complete_current_action'];
    _completeCurrentAction =
        widget.canCompleteCurrentAction && complete == true;

    _attachments
      ..clear()
      ..addAll(
        snapshot.attachments
            .take(3)
            .map(
              (attachment) => PickedEvidenceAttachment(
                attachmentId: attachment.attachmentId,
                bytes: attachment.bytes,
                fileName: attachment.fileName,
                contentType: attachment.contentType,
              ),
            ),
      );
  }

  ComposerDraftSnapshot _draftSnapshot() {
    final persistence = widget.persistence!;
    return ComposerDraftSnapshot(
      kind: 'progress',
      studentId: persistence.studentId,
      subject: persistence.subject,
      caseId: persistence.caseId,
      state: <String, dynamic>{
        'operation_id': persistence.operationId,
        'photo_evidence_operation_id': persistence.photoEvidenceOperationId,
        'body': _controller.text,
        'kind': _kind.name,
        'assessment_result': _assessmentResult?.name,
        'next_step': _nextStep.name,
        'reminder_title': _reminderController.text,
        'reminder_date': _reminderDate?.toIso8601String(),
        'close_reason': _closeReason.name,
        'complete_current_action': _completeCurrentAction,
      },
      attachments: _attachments
          .map(
            (attachment) => ComposerDraftAttachment(
              attachmentId: attachment.attachmentId,
              bytes: attachment.bytes,
              fileName: attachment.fileName,
              contentType: attachment.contentType,
            ),
          )
          .toList(growable: false),
      savedAt: DateTime.now(),
    );
  }

  Future<void> _persistDraft() async {
    final persistence = widget.persistence;
    if (persistence == null) return;
    await persistence.store.save(persistence.scopeKey, _draftSnapshot());
  }

  Future<void> _persistDraftSilently() async {
    try {
      await _persistDraft();
    } catch (_) {
      // External-picker boundaries use the strict variant below. Other state
      // changes are best effort so UI interaction never blocks on disk I/O.
    }
  }

  Future<void> _clearPersistedDraft() async {
    final persistence = widget.persistence;
    if (persistence == null) return;
    try {
      await persistence.store.clear(persistence.scopeKey);
    } catch (_) {
      // A confirmed server write remains success even if local cleanup fails.
      // Stable operation ids keep a stale retry idempotent.
    }
  }

  Future<void> _restoreLostAttachment() async {
    final persistence = widget.persistence;
    if (persistence?.initialDraft == null || _attachments.length >= 3) return;
    try {
      final loader =
          persistence?.lostAttachmentLoader ?? recoverLostEvidenceAttachment;
      final recovered = await loader();
      if (!mounted || recovered == null) return;
      if (_attachments.any(
        (attachment) => attachment.attachmentId == recovered.attachmentId,
      )) {
        return;
      }
      setState(() {
        _attachments.add(recovered);
        _mediaError = null;
      });
      await _persistDraftSilently();
    } catch (error) {
      if (!mounted) return;
      setState(() => _mediaError = describeEvidenceAttachmentError(error));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _reminderController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    if (_saving || _attachments.length >= 3) return;
    if (widget.persistence != null) {
      try {
        // Strictly persist every field before leaving Flutter for camera/gallery.
        await _persistDraft();
      } catch (_) {
        if (mounted) {
          setState(() {
            _mediaError = '暂时无法保护当前草稿，请稍后再拍照；已经输入的进展仍在当前窗口。';
          });
        }
        return;
      }
    }
    if (!mounted) return;
    try {
      final picked = await widget.attachmentPicker(context);
      if (!mounted || picked == null) return;
      setState(() {
        _attachments.add(picked);
        _mediaError = null;
      });
      await _persistDraftSilently();
    } catch (error) {
      if (!mounted) return;
      setState(() => _mediaError = describeEvidenceAttachmentError(error));
    }
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
    unawaited(_persistDraftSilently());
  }

  Future<void> _chooseReminderDate() async {
    final referenceDate = widget.businessDate ?? DateTime.now();
    final today = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final selected = await showDatePicker(
      context: context,
      initialDate: _reminderDate ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 2, 12, 31),
      helpText: '选择再次检查日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (selected != null && mounted) {
      setState(() => _reminderDate = selected);
      unawaited(_persistDraftSilently());
    }
  }

  bool get _initialCompleteCurrentAction =>
      widget.canCompleteCurrentAction && widget.completeCurrentActionInitially;

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

  Future<void> _save() async {
    if (!_canSave) {
      return;
    }
    final onSave = widget.onSave;
    if (onSave == null) {
      await _clearPersistedDraft();
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    final reminderTitle = _reminderController.text.trim();
    final draft = V2ProgressDraft(
      kind: _kind,
      body: _controller.text.trim(),
      attachments: List<PickedEvidenceAttachment>.unmodifiable(_attachments),
      assessmentResult: _assessmentResult,
      nextStep: _nextStep,
      reminderTitle: reminderTitle.isEmpty ? null : reminderTitle,
      reminderDate: _reminderDate,
      closeReason: _closeReason,
      completeCurrentAction:
          widget.canCompleteCurrentAction &&
          _nextStep != V2NextStep.close &&
          _completeCurrentAction,
    );
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await _persistDraftSilently();
      await onSave(draft);
      await _clearPersistedDraft();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      await _persistDraftSilently();
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = _describeV2SaveError(error);
        });
      }
    }
  }

  Future<void> _close() async {
    if (_saving) {
      return;
    }
    if (!_hasDraft) {
      await _clearPersistedDraft();
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    final action = await _showV2DraftCloseDialog(
      context,
      saveFailed: _saveError != null,
    );
    if (!mounted ||
        action == null ||
        action == _V2DraftCloseAction.keepEditing) {
      return;
    }
    if (action == _V2DraftCloseAction.retry) {
      await _save();
      return;
    }
    await _clearPersistedDraft();
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return _ComposerScaffold(
      title: widget.composerTitle,
      contextLine:
          '${widget.studentName} · ${widget.subject}\n${widget.caseTitle}',
      onClose: _saving ? null : _close,
      footer: _ComposerFooter(
        primaryLabel: widget.primaryLabel,
        onPrimary: _canSave ? _save : null,
        saving: _saving,
        previewMode: widget.onSave == null,
        errorText: _saveError,
      ),
      child: AbsorbPointer(
        absorbing: _saving,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('这次发生了什么？', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              key: const Key('v2-progress-body'),
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 7,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '写下这次真实出现的表现、处理或检查结果…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            V2MediaDraftStrip(
              attachments: _attachments,
              onAdd: _pickAttachment,
              onRemove: _removeAttachment,
            ),
            if (_mediaError != null) ...[
              const SizedBox(height: 8),
              Text(
                _mediaError!,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 22),
            Text('记录方式', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            _InlineSelector<V2ProgressKind>(
              key: const Key('v2-progress-kind-selector'),
              value: _kind,
              values: V2ProgressKind.values,
              label: (value) => value.label,
              onChanged: (value) {
                setState(() {
                  _kind = value;
                  if (value != V2ProgressKind.assessment) {
                    _assessmentResult = null;
                  }
                });
                unawaited(_persistDraftSilently());
              },
            ),
            AnimatedSize(
              duration: AppMotion.effectiveDuration(context),
              child: _kind == V2ProgressKind.assessment
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _InlineSelector<V2AssessmentResult>(
                        key: const Key('v2-assessment-selector'),
                        value: _assessmentResult,
                        values: V2AssessmentResult.values,
                        label: (value) => value.label,
                        onChanged: (value) {
                          setState(() => _assessmentResult = value);
                          unawaited(_persistDraftSilently());
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (widget.canCompleteCurrentAction) ...[
              const SizedBox(height: 18),
              InkWell(
                key: const Key('v2-complete-current-action'),
                onTap: _nextStep == V2NextStep.close
                    ? null
                    : () {
                        setState(
                          () =>
                              _completeCurrentAction = !_completeCurrentAction,
                        );
                        unawaited(_persistDraftSilently());
                      },
                borderRadius: BorderRadius.circular(5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _nextStep == V2NextStep.close
                            ? false
                            : _completeCurrentAction,
                        onChanged: _nextStep == V2NextStep.close
                            ? null
                            : (value) {
                                setState(
                                  () => _completeCurrentAction = value ?? false,
                                );
                                unawaited(_persistDraftSilently());
                              },
                      ),
                      const SizedBox(width: 4),
                      const Expanded(child: Text('同时完成当前提醒')),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 26),
            Text('下一步', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            for (final step in V2NextStep.values)
              _QuietRadioRow(
                key: ValueKey('v2-next-step-${step.name}'),
                label: step.label,
                selected: _nextStep == step,
                onTap: () {
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
              ),
            AnimatedSize(
              duration: AppMotion.effectiveDuration(context),
              alignment: Alignment.topCenter,
              child: switch (_nextStep) {
                V2NextStep.continueTracking => const SizedBox.shrink(),
                V2NextStep.remind => Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    children: [
                      TextField(
                        key: const Key('v2-reminder-title'),
                        controller: _reminderController,
                        decoration: const InputDecoration(
                          labelText: '提醒内容（可选）',
                          hintText: '例如：再检查一次同类题',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
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
                    ],
                  ),
                ),
                V2NextStep.close => Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: DropdownButtonFormField<V2CloseReason>(
                    initialValue: _closeReason,
                    decoration: const InputDecoration(labelText: '结束原因'),
                    items: V2CloseReason.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _closeReason = value);
                        unawaited(_persistDraftSilently());
                      }
                    },
                  ),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class V2MediaDraftStrip extends StatelessWidget {
  const V2MediaDraftStrip({
    required this.attachments,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  final List<PickedEvidenceAttachment> attachments;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextButton.icon(
              key: const Key('v2-media-add'),
              onPressed: attachments.length >= 3 ? null : onAdd,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: Text(attachments.isEmpty ? '拍照 / 相册' : '继续添加'),
            ),
            const SizedBox(width: 6),
            Text(
              '${attachments.length}/3',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        if (attachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < attachments.length; index++)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Container(
                        width: 92,
                        height: 72,
                        decoration: BoxDecoration(
                          border: Border.all(color: scheme.outlineVariant),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Image.memory(
                          attachments[index].bytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -7,
                      top: -7,
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: ValueKey('v2-media-remove-$index'),
                          customBorder: const CircleBorder(),
                          onTap: () => onRemove(index),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 15),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ComposerScaffold extends StatelessWidget {
  const _ComposerScaffold({
    required this.title,
    required this.contextLine,
    required this.onClose,
    required this.child,
    required this.footer,
  });

  final String title;
  final String contextLine;
  final VoidCallback? onClose;
  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final body = AnimatedPadding(
      duration: AppMotion.effectiveDuration(context),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          contextLine,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: onClose == null ? '正在保存' : '关闭',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                child: child,
              ),
            ),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            footer,
          ],
        ),
      ),
    );
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          onClose?.call();
        }
      },
      child: body,
    );
  }
}

class _ComposerFooter extends StatelessWidget {
  const _ComposerFooter({
    required this.primaryLabel,
    required this.onPrimary,
    required this.saving,
    required this.previewMode,
    this.errorText,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool saving;
  final bool previewMode;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final error = errorText?.trim();
    final note = Text(
      error != null && error.isNotEmpty
          ? error
          : previewMode
          ? 'V2 预览 · 不写入正式学情'
          : '保存到学生成长记录',
      key: const Key('v2-composer-save-status'),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: error != null && error.isNotEmpty
            ? Theme.of(context).colorScheme.error
            : null,
      ),
    );
    final action = FilledButton(
      onPressed: saving ? null : onPrimary,
      child: saving
          ? const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('保存中…'),
              ],
            )
          : Text(primaryLabel),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [note, const SizedBox(height: 8), action],
            );
          }
          return Row(
            children: [
              Expanded(child: note),
              const SizedBox(width: 16),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _InlineSelector<T> extends StatelessWidget {
  const _InlineSelector({
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final T? value;
  final List<T> values;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final option in values)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onChanged(option),
              borderRadius: BorderRadius.circular(5),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 2,
                      color: option == value
                          ? scheme.primary
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Text(
                  label(option),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: option == value
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuietRadioRow extends StatelessWidget {
  const _QuietRadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outline,
                  width: 1.4,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? scheme.primary : Colors.transparent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
