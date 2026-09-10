from pathlib import Path

path = Path('lib/features/design_v2/v2_workspace_preview.dart')
text = path.read_text(encoding='utf-8')

if not text.startswith("import 'dart:async';"):
    text = "import 'dart:async';\n\n" + text

constructor_old = """class V2WorkspacePreview extends StatefulWidget {
  const V2WorkspacePreview({
    super.key,
    this.data = v2FixtureWorkspaceData,
    this.workflowController,
    this.evidenceAttachmentRepository,
"""
constructor_new = """class V2WorkspacePreview extends StatefulWidget {
  const V2WorkspacePreview({
    super.key,
    this.data = v2FixtureWorkspaceData,
    this.workflowController,
    this.composerDraftStore,
    this.composerDraftScopeKey,
    this.evidenceAttachmentRepository,
"""
if constructor_old in text:
    text = text.replace(constructor_old, constructor_new, 1)
elif "class V2WorkspacePreview extends StatefulWidget" not in text or "    this.composerDraftScopeKey," not in text[text.index('class V2WorkspacePreview extends StatefulWidget'):]:
    raise SystemExit('V2WorkspacePreview constructor marker not found')

fields_old = """  final V2WorkspaceData data;
  final V2WorkflowController? workflowController;
  final EvidenceAttachmentRepository? evidenceAttachmentRepository;
"""
fields_new = """  final V2WorkspaceData data;
  final V2WorkflowController? workflowController;
  final ComposerDraftStore? composerDraftStore;
  final String? composerDraftScopeKey;
  final EvidenceAttachmentRepository? evidenceAttachmentRepository;
"""
preview_start = text.index('class V2WorkspacePreview extends StatefulWidget')
preview_tail = text[preview_start:]
if "final ComposerDraftStore? composerDraftStore;" not in preview_tail:
    if fields_old not in text:
        raise SystemExit('V2WorkspacePreview field marker not found')
    text = text.replace(fields_old, fields_new, 1)

state_start = text.index('class _V2WorkspacePreviewState extends State<V2WorkspacePreview>')
state_tail = text[state_start:]
if 'void _scheduleQuickCaptureDraftRecovery(BuildContext scopedContext)' not in state_tail:
    did_update_old = """    if (!identical(oldWidget.data, widget.data)) {
      _reconcileSelection();
    }
  }

  void _reconcileSelection() {
"""
    did_update_new = """    if (!identical(oldWidget.data, widget.data)) {
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

  void _reconcileSelection() {
"""
    if did_update_old not in text:
        raise SystemExit('V2WorkspacePreview didUpdateWidget marker not found')
    text = text.replace(did_update_old, did_update_new, 1)

path.write_text(text, encoding='utf-8')
