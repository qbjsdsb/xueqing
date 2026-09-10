from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'expected one match in {path}, found {count}: {old[:140]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


picker = 'lib/features/teacher_workspace/presentation/evidence_attachment_picker.dart'
composers = 'lib/features/design_v2/v2_composers.dart'
preview = 'lib/features/design_v2/v2_workspace_preview.dart'
picker_test = 'test/features/evidence_attachment_picker_test.dart'
progress_test = 'test/features/v032_progress_recovery_test.dart'

# A startup prime can legitimately complete with null long before a later
# camera round-trip. If a protected draft is being restored, retry the plugin
# once instead of treating that old null as the final result.
replace_once(
    picker,
    '  Future<PickedEvidenceAttachment?> take() async {\n',
    '  Future<PickedEvidenceAttachment?> take({bool refreshIfEmpty = false}) async {\n',
)
replace_once(
    picker,
    "    if (result.error != null) {\n      Error.throwWithStackTrace(result.error!, result.stackTrace!);\n    }\n    return result.attachment;\n  }",
    "    if (result.error != null) {\n"
    "      Error.throwWithStackTrace(result.error!, result.stackTrace!);\n"
    "    }\n"
    "    if (result.attachment != null || !refreshIfEmpty) {\n"
    "      return result.attachment;\n"
    "    }\n"
    "    final refreshed = await _loadSafely();\n"
    "    if (refreshed.error != null) {\n"
    "      Error.throwWithStackTrace(refreshed.error!, refreshed.stackTrace!);\n"
    "    }\n"
    "    return refreshed.attachment;\n"
    "  }",
)
replace_once(
    picker,
    '  return _defaultLostDataRecovery.take();\n',
    '  return _defaultLostDataRecovery.take(refreshIfEmpty: true);\n',
)

# Test the exact stale-null scenario that real-device feedback exposed.
anchor = "  test(\n    'startup recovery errors are deferred until the result is consumed',"
stale_test = r'''  test(
    'lost-data recovery refreshes a stale startup null for a protected draft',
    () async {
      var calls = 0;
      final recovered = PickedEvidenceAttachment(
        attachmentId: '00000000-0000-4000-8000-000000000009',
        bytes: Uint8List.fromList(<int>[9, 8, 7]),
        fileName: '相机恢复.jpg',
        contentType: 'image/jpeg',
      );
      final recovery = EvidenceAttachmentLostDataRecovery(() async {
        calls++;
        return calls == 1 ? null : recovered;
      });

      recovery.prime();
      await Future<void>.delayed(Duration.zero);

      expect(await recovery.take(refreshIfEmpty: true), same(recovered));
      expect(calls, 2);
      expect(await recovery.take(refreshIfEmpty: true), isNull);
    },
  );

'''
replace_once(picker_test, anchor, stale_test + anchor)

# Progress now gets the same durable draft contract that Quick Capture already
# has, including stable operation ids across Activity/process recreation.
persistence_anchor = r'''Future<bool> showV2QuickCapture(
  BuildContext context, {'''
progress_persistence = r'''class V2ProgressPersistence {
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

'''
replace_once(composers, persistence_anchor, progress_persistence + persistence_anchor)

replace_once(
    composers,
    "  V2ProgressSave? onSave,\n  V2AttachmentPicker attachmentPicker = pickEvidenceAttachment,\n}) async {",
    "  V2ProgressSave? onSave,\n"
    "  V2AttachmentPicker attachmentPicker = pickEvidenceAttachment,\n"
    "  V2ProgressPersistence? persistence,\n"
    "}) async {",
)
replace_once(
    composers,
    "          onSave: onSave,\n          attachmentPicker: attachmentPicker,\n        ),\n      ) ??\n      false;\n  if (saved && context.mounted) {\n    ScaffoldMessenger.of(context).showSnackBar(\n      SnackBar(\n        content: Text(onSave == null ? 'V2 预览：进展已完成，但没有写入正式学情。' : '已保存进展。'),",
    "          onSave: onSave,\n"
    "          attachmentPicker: attachmentPicker,\n"
    "          persistence: persistence,\n"
    "        ),\n"
    "      ) ??\n"
    "      false;\n"
    "  if (saved && context.mounted) {\n"
    "    ScaffoldMessenger.of(context).showSnackBar(\n"
    "      SnackBar(\n"
    "        content: Text(onSave == null ? 'V2 预览：进展已完成，但没有写入正式学情。' : '已保存进展。'),",
)
replace_once(
    composers,
    "    this.businessDate,\n    this.onSave,\n    super.key,\n  });",
    "    this.businessDate,\n"
    "    this.onSave,\n"
    "    this.persistence,\n"
    "    super.key,\n"
    "  });",
)
replace_once(
    composers,
    "  final DateTime? businessDate;\n  final V2ProgressSave? onSave;\n",
    "  final DateTime? businessDate;\n"
    "  final V2ProgressSave? onSave;\n"
    "  final V2ProgressPersistence? persistence;\n",
)

progress_state_anchor = r'''  @override
  void dispose() {
    _controller.dispose();
    _reminderController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {'''
progress_state_methods = r'''  @override
  void initState() {
    super.initState();
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
    _completeCurrentAction = widget.canCompleteCurrentAction && complete == true;

    _attachments
      ..clear()
      ..addAll(
        snapshot.attachments.take(3).map(
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

  Future<void> _pickAttachment() async {'''
replace_once(composers, progress_state_anchor, progress_state_methods)

replace_once(
    composers,
    r'''  Future<void> _pickAttachment() async {
    if (_saving || _attachments.length >= 3) {
      return;
    }
    try {
      final picked = await widget.attachmentPicker(context);
      if (!mounted || picked == null) {
        return;
      }
      setState(() {
        _attachments.add(picked);
        _mediaError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _mediaError = describeEvidenceAttachmentError(error));
    }
  }
''',
    r'''  Future<void> _pickAttachment() async {
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
''',
)

replace_once(
    composers,
    "    if (selected != null && mounted) {\n      setState(() => _reminderDate = selected);\n    }",
    "    if (selected != null && mounted) {\n"
    "      setState(() => _reminderDate = selected);\n"
    "      unawaited(_persistDraftSilently());\n"
    "    }",
)

replace_once(
    composers,
    "    if (onSave == null) {\n      Navigator.of(context).pop(true);\n      return;\n    }\n    final reminderTitle = _reminderController.text.trim();",
    "    if (onSave == null) {\n"
    "      await _clearPersistedDraft();\n"
    "      if (mounted) Navigator.of(context).pop(true);\n"
    "      return;\n"
    "    }\n"
    "    final reminderTitle = _reminderController.text.trim();",
)
replace_once(
    composers,
    "    try {\n      await onSave(draft);\n      if (mounted) {\n        Navigator.of(context).pop(true);\n      }\n    } catch (error) {\n      if (mounted) {\n        setState(() {\n          _saving = false;\n          _saveError = _describeV2SaveError(error);\n        });\n      }\n    }",
    "    try {\n"
    "      await _persistDraftSilently();\n"
    "      await onSave(draft);\n"
    "      await _clearPersistedDraft();\n"
    "      if (mounted) {\n"
    "        Navigator.of(context).pop(true);\n"
    "      }\n"
    "    } catch (error) {\n"
    "      await _persistDraftSilently();\n"
    "      if (mounted) {\n"
    "        setState(() {\n"
    "          _saving = false;\n"
    "          _saveError = _describeV2SaveError(error);\n"
    "        });\n"
    "      }\n"
    "    }",
)
replace_once(
    composers,
    "    if (!_hasDraft) {\n      Navigator.of(context).pop(false);\n      return;\n    }",
    "    if (!_hasDraft) {\n"
    "      await _clearPersistedDraft();\n"
    "      if (mounted) Navigator.of(context).pop(false);\n"
    "      return;\n"
    "    }",
)
# Only the Progress close path still has a plain pop after the retry/discard
# branch at this point; Quick Capture already clears its draft.
progress_close_tail = "    if (action == _V2DraftCloseAction.retry) {\n      await _save();\n      return;\n    }\n    Navigator.of(context).pop(false);\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    return _ComposerScaffold(\n      title: '记录进展',"
progress_close_new = "    if (action == _V2DraftCloseAction.retry) {\n      await _save();\n      return;\n    }\n    await _clearPersistedDraft();\n    if (mounted) Navigator.of(context).pop(false);\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    return _ComposerScaffold(\n      title: '记录进展',"
replace_once(composers, progress_close_tail, progress_close_new)

replace_once(
    composers,
    "              onChanged: (_) => setState(() {}),\n              decoration: const InputDecoration(\n                hintText: '写下这次真实出现的表现、处理或检查结果…',",
    "              onChanged: (_) => setState(() {}),\n"
    "              decoration: const InputDecoration(\n"
    "                hintText: '写下这次真实出现的表现、处理或检查结果…',",
)
replace_once(
    composers,
    "              onRemove: (index) => setState(() => _attachments.removeAt(index)),\n",
    "              onRemove: _removeAttachment,\n",
)
replace_once(
    composers,
    r'''              onChanged: (value) => setState(() {
                _kind = value;
                if (value != V2ProgressKind.assessment) {
                  _assessmentResult = null;
                }
              }),''',
    r'''              onChanged: (value) {
                setState(() {
                  _kind = value;
                  if (value != V2ProgressKind.assessment) {
                    _assessmentResult = null;
                  }
                });
                unawaited(_persistDraftSilently());
              },''',
)
replace_once(
    composers,
    "                        onChanged: (value) =>\n                            setState(() => _assessmentResult = value),",
    "                        onChanged: (value) {\n"
    "                          setState(() => _assessmentResult = value);\n"
    "                          unawaited(_persistDraftSilently());\n"
    "                        },",
)
replace_once(
    composers,
    "                    : () => setState(\n                        () => _completeCurrentAction = !_completeCurrentAction,\n                      ),",
    "                    : () {\n"
    "                        setState(\n"
    "                          () => _completeCurrentAction = !_completeCurrentAction,\n"
    "                        );\n"
    "                        unawaited(_persistDraftSilently());\n"
    "                      },",
)
replace_once(
    composers,
    "                            : (value) => setState(\n                                () => _completeCurrentAction = value ?? false,\n                              ),",
    "                            : (value) {\n"
    "                                setState(\n"
    "                                  () => _completeCurrentAction = value ?? false,\n"
    "                                );\n"
    "                                unawaited(_persistDraftSilently());\n"
    "                              },",
)
replace_once(
    composers,
    r'''                onTap: () => setState(() {
                  _nextStep = step;
                  if (step == V2NextStep.close) {
                    _completeCurrentAction = false;
                  }
                }),''',
    r'''                onTap: () {
                  setState(() {
                    _nextStep = step;
                    if (step == V2NextStep.close) {
                      _completeCurrentAction = false;
                    }
                  });
                  unawaited(_persistDraftSilently());
                },''',
)
replace_once(
    composers,
    "                      TextField(\n                        key: const Key('v2-reminder-title'),\n                        controller: _reminderController,\n                        decoration: const InputDecoration(",
    "                      TextField(\n"
    "                        key: const Key('v2-reminder-title'),\n"
    "                        controller: _reminderController,\n"
    "                        decoration: const InputDecoration(",
)
replace_once(
    composers,
    "                        setState(() => _closeReason = value);\n                      }",
    "                        setState(() => _closeReason = value);\n"
    "                        unawaited(_persistDraftSilently());\n"
    "                      }",
)

# Wire persistent progress identities and generalized runtime recovery.
old_progress_head = r'''Future<void> _showV2ProgressForCase(
  BuildContext context,
  V2Student student,
  V2FocusItem item,
) async {
  final runtime = _V2RuntimeScope.maybeOf(context);
  final controller = runtime?.workflowController;
  final operationId = controller == null ? null : createOperationId();
  final photoEvidenceOperationId = controller == null
      ? null
      : createOperationId();
  final saved = await showV2ProgressComposer('''
new_progress_head = r'''Future<void> _showV2ProgressForCase(
  BuildContext context,
  V2Student student,
  V2FocusItem item, {
  ComposerDraftSnapshot? initialDraft,
}) async {
  final runtime = _V2RuntimeScope.maybeOf(context);
  final controller = runtime?.workflowController;
  final storedOperationId = initialDraft?.state['operation_id'];
  final storedPhotoOperationId = initialDraft?.state['photo_evidence_operation_id'];
  final operationId = storedOperationId is String && storedOperationId.trim().isNotEmpty
      ? storedOperationId
      : controller == null
      ? null
      : createOperationId();
  final photoEvidenceOperationId =
      storedPhotoOperationId is String && storedPhotoOperationId.trim().isNotEmpty
      ? storedPhotoOperationId
      : controller == null
      ? null
      : createOperationId();
  final store = runtime?.composerDraftStore;
  final scopeKey = runtime?.composerDraftScopeKey;
  final persistence =
      store != null &&
          scopeKey != null &&
          operationId != null &&
          photoEvidenceOperationId != null
      ? V2ProgressPersistence(
          store: store,
          scopeKey: scopeKey,
          studentId: student.id,
          subject: item.subject,
          caseId: item.id,
          operationId: operationId,
          photoEvidenceOperationId: photoEvidenceOperationId,
          initialDraft: initialDraft,
        )
      : null;
  final saved = await showV2ProgressComposer('''
replace_once(preview, old_progress_head, new_progress_head)
replace_once(
    preview,
    "    businessDate: controller?.businessDate,\n    onSave: controller == null",
    "    businessDate: controller?.businessDate,\n"
    "    persistence: persistence,\n"
    "    onSave: controller == null",
)

# Generalize the one-time post-frame restorer. Invalid or no-longer-authorized
# drafts are cleared rather than leaked into a new account/teaching context.
old_recovery_block = r'''  bool _quickCaptureDraftRecoveryScheduled = false;

  @override
  void initState() {
    super.initState();
    _reconcileSelection();
  }

  @override
  void didUpdateWidget(covariant V2WorkspacePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      _reconcileSelection();
    }
    if (oldWidget.composerDraftScopeKey != widget.composerDraftScopeKey ||
        oldWidget.composerDraftStore != widget.composerDraftStore) {
      _quickCaptureDraftRecoveryScheduled = false;
    }
  }

  void _scheduleQuickCaptureDraftRecovery(BuildContext scopedContext) {
    if (_quickCaptureDraftRecoveryScheduled ||
        widget.composerDraftStore == null ||
        widget.composerDraftScopeKey == null) {
      return;
    }
    _quickCaptureDraftRecoveryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scopedContext.mounted) {
        unawaited(_restoreQuickCaptureDraft(scopedContext));
      }
    });
  }

  Future<void> _restoreQuickCaptureDraft(BuildContext scopedContext) async {
    final store = widget.composerDraftStore;
    final scopeKey = widget.composerDraftScopeKey;
    if (store == null || scopeKey == null) return;

    ComposerDraftSnapshot? draft;
    try {
      draft = await store.load(scopeKey);
    } catch (_) {
      try {
        await store.clear(scopeKey);
      } catch (_) {}
      return;
    }
    if (!mounted || !scopedContext.mounted || draft == null) return;

    final operationId = draft.state['operation_id'];
    if (draft.kind != 'quick_capture' ||
        operationId is! String ||
        operationId.trim().isEmpty) {
      try {
        await store.clear(scopeKey);
      } catch (_) {}
      return;
    }

    V2Student? student;
    for (final candidate in widget.data.students) {
      if (candidate.id == draft.studentId) {
        student = candidate;
        break;
      }
    }
    final subject = draft.subject;
    if (student == null ||
        (subject != null && !student.subjects.contains(subject))) {
      try {
        await store.clear(scopeKey);
      } catch (_) {}
      return;
    }
    if (!mounted || !scopedContext.mounted) return;
    await _showV2QuickCaptureForStudent(
      scopedContext,
      student,
      initialDraft: draft,
    );
  }
'''
new_recovery_block = r'''  bool _composerDraftRecoveryScheduled = false;

  @override
  void initState() {
    super.initState();
    _reconcileSelection();
  }

  @override
  void didUpdateWidget(covariant V2WorkspacePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      _reconcileSelection();
    }
    if (oldWidget.composerDraftScopeKey != widget.composerDraftScopeKey ||
        oldWidget.composerDraftStore != widget.composerDraftStore) {
      _composerDraftRecoveryScheduled = false;
    }
  }

  void _scheduleComposerDraftRecovery(BuildContext scopedContext) {
    if (_composerDraftRecoveryScheduled ||
        widget.composerDraftStore == null ||
        widget.composerDraftScopeKey == null) {
      return;
    }
    _composerDraftRecoveryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scopedContext.mounted) {
        unawaited(_restoreComposerDraft(scopedContext));
      }
    });
  }

  Future<void> _clearComposerDraft() async {
    final store = widget.composerDraftStore;
    final scopeKey = widget.composerDraftScopeKey;
    if (store == null || scopeKey == null) return;
    try {
      await store.clear(scopeKey);
    } catch (_) {}
  }

  Future<void> _restoreComposerDraft(BuildContext scopedContext) async {
    final store = widget.composerDraftStore;
    final scopeKey = widget.composerDraftScopeKey;
    if (store == null || scopeKey == null) return;

    ComposerDraftSnapshot? draft;
    try {
      draft = await store.load(scopeKey);
    } catch (_) {
      await _clearComposerDraft();
      return;
    }
    if (!mounted || !scopedContext.mounted || draft == null) return;

    V2Student? student;
    for (final candidate in widget.data.students) {
      if (candidate.id == draft.studentId) {
        student = candidate;
        break;
      }
    }
    if (student == null) {
      await _clearComposerDraft();
      return;
    }

    final operationId = draft.state['operation_id'];
    if (operationId is! String || operationId.trim().isEmpty) {
      await _clearComposerDraft();
      return;
    }

    if (draft.kind == 'quick_capture') {
      final subject = draft.subject;
      if (subject != null && !student.subjects.contains(subject)) {
        await _clearComposerDraft();
        return;
      }
      if (!mounted || !scopedContext.mounted) return;
      await _showV2QuickCaptureForStudent(
        scopedContext,
        student,
        initialDraft: draft,
      );
      return;
    }

    if (draft.kind == 'progress') {
      final subject = draft.subject;
      final caseId = draft.caseId;
      final photoOperationId = draft.state['photo_evidence_operation_id'];
      if (subject == null ||
          !student.subjects.contains(subject) ||
          caseId == null ||
          photoOperationId is! String ||
          photoOperationId.trim().isEmpty) {
        await _clearComposerDraft();
        return;
      }
      V2FocusItem? item;
      for (final candidate in widget.data.focusItems) {
        if (candidate.id == caseId &&
            candidate.studentId == student.id &&
            candidate.subject == subject &&
            !candidate.closed) {
          item = candidate;
          break;
        }
      }
      if (item == null) {
        await _clearComposerDraft();
        return;
      }
      _openCase(item);
      await Future<void>.delayed(Duration.zero);
      if (!mounted || !scopedContext.mounted) return;
      await _showV2ProgressForCase(
        scopedContext,
        student,
        item,
        initialDraft: draft,
      );
      return;
    }

    await _clearComposerDraft();
  }
'''
replace_once(preview, old_recovery_block, new_recovery_block)
replace_once(
    preview,
    '            _scheduleQuickCaptureDraftRecovery(context);\n',
    '            _scheduleComposerDraftRecovery(context);\n',
)

# Regression tests cover both the restored form/photo and runtime authorization.
Path(progress_test).write_text(r'''import 'dart:typed_data';

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

  testWidgets('progress composer restores protected text and lost camera photo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = InMemoryComposerDraftStore();
    final draft = progressDraft();
    final recovered = PickedEvidenceAttachment(
      attachmentId: '00000000-0000-4000-8000-000000000010',
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      fileName: '恢复.jpg',
      contentType: 'image/jpeg',
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
    expect(saved?.state['photo_evidence_operation_id'], 'operation-photo-stable');
    expect(saved?.attachments, hasLength(1));
  });

  testWidgets('authorized progress draft automatically reopens exact active case', (
    tester,
  ) async {
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
  });

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
''', encoding='utf-8')

print('v0.3.2 Gate C durable composer recovery patch applied')
