from pathlib import Path

# 1) Expose the durable composer draft store through the authenticated runtime.
runtime_path = Path('lib/features/teacher_workspace/workspace_runtime.dart')
runtime = runtime_path.read_text(encoding='utf-8')
if "import '../../cloud/composer_draft_store.dart';" not in runtime:
    runtime = runtime.replace(
        "import '../../cloud/case_reopen_draft_store.dart';\n",
        "import '../../cloud/case_reopen_draft_store.dart';\nimport '../../cloud/composer_draft_store.dart';\n",
        1,
    )
constructor_marker = "    this.studentLearningRecordRepository,\n    this.sessionUserId,\n"
if "this.composerDraftStore," not in runtime:
    if constructor_marker not in runtime:
        raise SystemExit('runtime constructor marker not found')
    runtime = runtime.replace(
        constructor_marker,
        "    this.studentLearningRecordRepository,\n    this.composerDraftStore,\n    this.sessionUserId,\n",
        1,
    )
field_marker = "  final StudentLearningRecordRepository? studentLearningRecordRepository;\n  final UpdateService updateService;\n"
if "final ComposerDraftStore? composerDraftStore;" not in runtime:
    if field_marker not in runtime:
        raise SystemExit('runtime field marker not found')
    runtime = runtime.replace(
        field_marker,
        "  final StudentLearningRecordRepository? studentLearningRecordRepository;\n  final ComposerDraftStore? composerDraftStore;\n  final UpdateService updateService;\n",
        1,
    )
runtime_path.write_text(runtime, encoding='utf-8')

# 2) Own one production store at the authenticated entry boundary and inject it.
entry_path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
entry = entry_path.read_text(encoding='utf-8')
if "import '../../../cloud/composer_draft_store.dart';" not in entry:
    entry = entry.replace(
        "import '../../../cloud/case_reopen_draft_store.dart';\n",
        "import '../../../cloud/case_reopen_draft_store.dart';\nimport '../../../cloud/composer_draft_store.dart';\n",
        1,
    )
widget_arg_marker = "    this.caseReopenDraftStore,\n    this.authenticatedWorkspaceBuilder,\n"
if "this.composerDraftStore," not in entry:
    if widget_arg_marker not in entry:
        raise SystemExit('entry widget argument marker not found')
    entry = entry.replace(
        widget_arg_marker,
        "    this.caseReopenDraftStore,\n    this.composerDraftStore,\n    this.authenticatedWorkspaceBuilder,\n",
        1,
    )
widget_field_marker = "  final CaseReopenDraftStore? caseReopenDraftStore;\n  final AuthenticatedWorkspaceBuilder? authenticatedWorkspaceBuilder;\n"
if "final ComposerDraftStore? composerDraftStore;" not in entry:
    if widget_field_marker not in entry:
        raise SystemExit('entry widget field marker not found')
    entry = entry.replace(
        widget_field_marker,
        "  final CaseReopenDraftStore? caseReopenDraftStore;\n  final ComposerDraftStore? composerDraftStore;\n  final AuthenticatedWorkspaceBuilder? authenticatedWorkspaceBuilder;\n",
        1,
    )
state_field_marker = "  late final CaseReopenDraftStore _caseReopenDraftStore;\n"
if "late final ComposerDraftStore _composerDraftStore;" not in entry:
    if state_field_marker not in entry:
        raise SystemExit('entry state field marker not found')
    entry = entry.replace(
        state_field_marker,
        state_field_marker + "  late final ComposerDraftStore _composerDraftStore;\n",
        1,
    )
init_marker = "    _caseReopenDraftStore =\n        widget.caseReopenDraftStore ?? SecureCaseReopenDraftStore();\n"
if "widget.composerDraftStore ?? SecureComposerDraftStore()" not in entry:
    if init_marker not in entry:
        raise SystemExit('entry init marker not found')
    entry = entry.replace(
        init_marker,
        init_marker + "    _composerDraftStore =\n        widget.composerDraftStore ?? SecureComposerDraftStore();\n",
        1,
    )
runtime_call_marker = "            caseReopenDraftStore: _caseReopenDraftStore,\n            appVersion: widget.config.appVersion,\n"
if "composerDraftStore: _composerDraftStore," not in entry:
    if runtime_call_marker not in entry:
        raise SystemExit('entry runtime call marker not found')
    entry = entry.replace(
        runtime_call_marker,
        "            caseReopenDraftStore: _caseReopenDraftStore,\n            composerDraftStore: _composerDraftStore,\n            appVersion: widget.config.appVersion,\n",
        1,
    )
entry_path.write_text(entry, encoding='utf-8')

# 3) Build a user+organization-scoped key only after the authorized workspace loads.
loader_path = Path('lib/features/design_v2/v2_workspace_loader.dart')
loader = loader_path.read_text(encoding='utf-8')
if "import '../../cloud/composer_draft_store.dart';" not in loader:
    loader = loader.replace(
        "import '../../cloud/evidence_attachment_repository.dart';\n",
        "import '../../cloud/composer_draft_store.dart';\nimport '../../cloud/evidence_attachment_repository.dart';\n",
        1,
    )
loader_marker = "        return V2WorkspacePreview(\n          data: snapshotData.workspaceData,\n"
if "composerDraftScopeKey:" not in loader:
    if loader_marker not in loader:
        raise SystemExit('loader preview marker not found')
    replacement = """        final composerDraftStore = runtime?.composerDraftStore;
        final sessionUserId = runtime?.sessionUserId;
        final composerDraftScopeKey =
            composerDraftStore != null && sessionUserId != null
            ? quickCaptureComposerScopeKey(
                sessionUserId: sessionUserId,
                organizationId: workspace.organizationId,
              )
            : null;
        return V2WorkspacePreview(
          data: snapshotData.workspaceData,
          composerDraftStore: composerDraftStore,
          composerDraftScopeKey: composerDraftScopeKey,
"""
    loader = loader.replace(loader_marker, replacement, 1)
loader_path.write_text(loader, encoding='utf-8')

# 4) Wire persistence into Quick Capture and automatically restore only authorized drafts.
preview_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
preview = preview_path.read_text(encoding='utf-8')
if "import '../../cloud/composer_draft_store.dart';" not in preview:
    preview = preview.replace(
        "import '../../cloud/evidence_attachment_repository.dart';\n",
        "import '../../cloud/composer_draft_store.dart';\nimport '../../cloud/evidence_attachment_repository.dart';\n",
        1,
    )

scope_ctor_marker = "    required this.evidenceAttachmentRepository,\n    required this.studentExport,\n"
if "required this.composerDraftStore," not in preview:
    if scope_ctor_marker not in preview:
        raise SystemExit('runtime scope constructor marker not found')
    preview = preview.replace(
        scope_ctor_marker,
        "    required this.evidenceAttachmentRepository,\n    required this.composerDraftStore,\n    required this.composerDraftScopeKey,\n    required this.studentExport,\n",
        1,
    )
scope_field_marker = "  final EvidenceAttachmentRepository? evidenceAttachmentRepository;\n  final V2StudentExport? studentExport;\n"
if "final ComposerDraftStore? composerDraftStore;" not in preview:
    if scope_field_marker not in preview:
        raise SystemExit('runtime scope field marker not found')
    preview = preview.replace(
        scope_field_marker,
        "  final EvidenceAttachmentRepository? evidenceAttachmentRepository;\n  final ComposerDraftStore? composerDraftStore;\n  final String? composerDraftScopeKey;\n  final V2StudentExport? studentExport;\n",
        1,
    )
notify_marker = "      evidenceAttachmentRepository != oldWidget.evidenceAttachmentRepository ||\n      studentExport != oldWidget.studentExport ||\n"
if "composerDraftStore != oldWidget.composerDraftStore" not in preview:
    if notify_marker not in preview:
        raise SystemExit('runtime scope notify marker not found')
    preview = preview.replace(
        notify_marker,
        "      evidenceAttachmentRepository != oldWidget.evidenceAttachmentRepository ||\n      composerDraftStore != oldWidget.composerDraftStore ||\n      composerDraftScopeKey != oldWidget.composerDraftScopeKey ||\n      studentExport != oldWidget.studentExport ||\n",
        1,
    )

old_quick_start = """Future<void> _showV2QuickCaptureForStudent(
  BuildContext context,
  V2Student student,
) async {
  final runtime = _V2RuntimeScope.maybeOf(context);
  final controller = runtime?.workflowController;
  final operationId = controller == null ? null : createOperationId();
"""
new_quick_start = """Future<void> _showV2QuickCaptureForStudent(
  BuildContext context,
  V2Student student, {
  ComposerDraftSnapshot? initialDraft,
}) async {
  final runtime = _V2RuntimeScope.maybeOf(context);
  final controller = runtime?.workflowController;
  final storedOperationId = initialDraft?.state['operation_id'];
  final operationId = storedOperationId is String && storedOperationId.trim().isNotEmpty
      ? storedOperationId
      : createOperationId();
  final draftStore = runtime?.composerDraftStore;
  final draftScopeKey = runtime?.composerDraftScopeKey;
  final persistence = draftStore != null && draftScopeKey != null
      ? V2QuickCapturePersistence(
          store: draftStore,
          scopeKey: draftScopeKey,
          studentId: student.id,
          operationId: operationId,
          initialDraft: initialDraft,
        )
      : null;
"""
if old_quick_start not in preview:
    raise SystemExit('quick capture start marker not found')
preview = preview.replace(old_quick_start, new_quick_start, 1)
preview = preview.replace("                operationId: operationId!,\n", "                operationId: operationId,\n", 1)
quick_call_marker = """    problemTypes: problemTypes,
    onSave: controller == null
"""
if "    persistence: persistence,\n" not in preview:
    if quick_call_marker not in preview:
        raise SystemExit('quick capture call marker not found')
    preview = preview.replace(
        quick_call_marker,
        "    problemTypes: problemTypes,\n    persistence: persistence,\n    onSave: controller == null\n",
        1,
    )

preview_ctor_marker = "    this.data = v2FixtureWorkspaceData,\n    this.workflowController,\n"
if "this.composerDraftStore," not in preview:
    if preview_ctor_marker not in preview:
        raise SystemExit('preview constructor marker not found')
    preview = preview.replace(
        preview_ctor_marker,
        "    this.data = v2FixtureWorkspaceData,\n    this.workflowController,\n    this.composerDraftStore,\n    this.composerDraftScopeKey,\n",
        1,
    )
preview_field_marker = "  final V2WorkspaceData data;\n  final V2WorkflowController? workflowController;\n"
if "  final ComposerDraftStore? composerDraftStore;" not in preview:
    if preview_field_marker not in preview:
        raise SystemExit('preview field marker not found')
    preview = preview.replace(
        preview_field_marker,
        "  final V2WorkspaceData data;\n  final V2WorkflowController? workflowController;\n  final ComposerDraftStore? composerDraftStore;\n  final String? composerDraftScopeKey;\n",
        1,
    )
state_marker = "  bool _checkingForUpdates = false;\n  bool _refreshing = false;\n"
if "_quickCaptureDraftRecoveryScheduled" not in preview:
    if state_marker not in preview:
        raise SystemExit('preview state marker not found')
    preview = preview.replace(
        state_marker,
        state_marker + "  bool _quickCaptureDraftRecoveryScheduled = false;\n",
        1,
    )

did_update_marker = """    if (!identical(oldWidget.data, widget.data)) {
      _reconcileSelection();
    }
  }

  void _reconcileSelection() {
"""
if "oldWidget.composerDraftScopeKey" not in preview:
    if did_update_marker not in preview:
        raise SystemExit('preview didUpdateWidget marker not found')
    preview = preview.replace(
        did_update_marker,
        """    if (!identical(oldWidget.data, widget.data)) {
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
        _restoreQuickCaptureDraft(scopedContext);
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
    final stillAuthorized =
        student != null && (subject == null || student.subjects.contains(subject));
    if (!stillAuthorized) {
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
""",
        1,
    )

scope_build_marker = """    return _V2RuntimeScope(
      workflowController: widget.workflowController,
      evidenceAttachmentRepository: widget.evidenceAttachmentRepository,
      studentExport: widget.onExportStudent,
"""
if "      composerDraftStore: widget.composerDraftStore," not in preview:
    if scope_build_marker not in preview:
        raise SystemExit('runtime scope build marker not found')
    preview = preview.replace(
        scope_build_marker,
        """    return _V2RuntimeScope(
      workflowController: widget.workflowController,
      evidenceAttachmentRepository: widget.evidenceAttachmentRepository,
      composerDraftStore: widget.composerDraftStore,
      composerDraftScopeKey: widget.composerDraftScopeKey,
      studentExport: widget.onExportStudent,
""",
        1,
    )
builder_marker = """        child: Builder(
          builder: (context) {
            if (widget.data.students.isEmpty) {
"""
if "_scheduleQuickCaptureDraftRecovery(context);" not in preview:
    if builder_marker not in preview:
        raise SystemExit('preview builder marker not found')
    preview = preview.replace(
        builder_marker,
        """        child: Builder(
          builder: (context) {
            _scheduleQuickCaptureDraftRecovery(context);
            if (widget.data.students.isEmpty) {
""",
        1,
    )
preview_path.write_text(preview, encoding='utf-8')

# 5) Regression tests: authorized drafts reopen; stale unauthorized drafts are purged.
test_path = Path('test/features/v2_quick_capture_runtime_recovery_test.dart')
test_path.write_text(r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/composer_draft_store.dart';
import 'package:xueqing/features/design_v2/v2_fixture.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_data.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  const scope = 'quick-capture:user-a:org-a';
  const student = V2Student(
    id: 'student-a',
    name: '林同学',
    grade: '初三',
    subjects: ['语文'],
    openCaseCount: 0,
    updatedLabel: '已有更新',
    teacherSummary: '当前工作区 · 语文',
  );
  const data = V2WorkspaceData(students: [student], focusItems: [], timeline: []);

  Widget app({
    required ComposerDraftStore store,
    V2WorkspaceData workspaceData = data,
  }) => MaterialApp(
    theme: V2Theme.light(),
    home: V2WorkspacePreview(
      data: workspaceData,
      composerDraftStore: store,
      composerDraftScopeKey: scope,
    ),
  );

  testWidgets('authorized unfinished camera draft automatically reopens in V2', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = InMemoryComposerDraftStore();
    await store.save(
      scope,
      ComposerDraftSnapshot(
        kind: 'quick_capture',
        studentId: 'student-a',
        subject: '语文',
        state: const <String, dynamic>{
          'operation_id': 'operation-recovery',
          'case_type_key': 'unclassified',
          'body': '拍照前尚未保存的文言文问题。',
          'show_more': false,
        },
        attachments: const [],
        savedAt: DateTime(2026, 9, 10, 17),
      ),
    );

    await tester.pumpWidget(app(store: store));
    await tester.pumpAndSettle();

    expect(find.text('记录新问题'), findsOneWidget);
    expect(find.text('林同学 · 语文'), findsOneWidget);
    expect(find.text('拍照前尚未保存的文言文问题。'), findsOneWidget);
  });

  testWidgets('draft for a no-longer-authorized student is never exposed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = InMemoryComposerDraftStore();
    await store.save(
      scope,
      ComposerDraftSnapshot(
        kind: 'quick_capture',
        studentId: 'student-no-longer-assigned',
        subject: '语文',
        state: const <String, dynamic>{
          'operation_id': 'operation-stale',
          'case_type_key': 'unclassified',
          'body': '这段旧草稿不应该被展示。',
          'show_more': false,
        },
        attachments: const [],
        savedAt: DateTime(2026, 9, 10, 17),
      ),
    );

    await tester.pumpWidget(app(store: store));
    await tester.pumpAndSettle();

    expect(find.text('这段旧草稿不应该被展示。'), findsNothing);
    expect(find.text('记录新问题'), findsNothing);
    expect(await store.load(scope), isNull);
  });
}
''', encoding='utf-8')

contract_path = Path('test/features/v2_quick_capture_runtime_wiring_contract_test.dart')
contract_path.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production authenticated V2 wires durable quick-capture recovery', () {
    final entry = File(
      'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart',
    ).readAsStringSync();
    final runtime = File(
      'lib/features/teacher_workspace/workspace_runtime.dart',
    ).readAsStringSync();
    final loader = File(
      'lib/features/design_v2/v2_workspace_loader.dart',
    ).readAsStringSync();
    final preview = File(
      'lib/features/design_v2/v2_workspace_preview.dart',
    ).readAsStringSync();

    expect(entry, contains('SecureComposerDraftStore()'));
    expect(entry, contains('composerDraftStore: _composerDraftStore'));
    expect(runtime, contains('final ComposerDraftStore? composerDraftStore;'));
    expect(loader, contains('quickCaptureComposerScopeKey('));
    expect(loader, contains('organizationId: workspace.organizationId'));
    expect(preview, contains('_restoreQuickCaptureDraft'));
    expect(preview, contains('initialDraft: draft'));
  });
}
''', encoding='utf-8')
