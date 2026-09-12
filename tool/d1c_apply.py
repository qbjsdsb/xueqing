from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    source = p.read_text()
    count = source.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected 1 match, got {count}: {old[:100]!r}')
    p.write_text(source.replace(old, new, 1))


repo = 'lib/cloud/responsibility_scoped_learning_repository.dart'
replace_once(
    repo,
    'abstract interface class ResponsibilityWriteRepository {\n',
    '''abstract interface class OrganizationQuickCaptureRepository {
  Future<QuickCaptureReceipt> quickCaptureForOrganization(
    QuickCaptureCommand command, {
    required String expectedResponsibilityMembershipId,
  });
}

abstract interface class ResponsibilityWriteRepository {
''',
)
replace_once(
    repo,
    'class ResponsibilityScopedLearningRepository\n    implements LearningRepository, ResponsibilityReadRepository {',
    '''class ResponsibilityScopedLearningRepository
    implements
        LearningRepository,
        ResponsibilityReadRepository,
        OrganizationQuickCaptureRepository {''',
)
replace_once(
    repo,
    '  @override\n  Future<WorkspaceCaseType> createCaseType({',
    '''  @override
  Future<QuickCaptureReceipt> quickCaptureForOrganization(
    QuickCaptureCommand command, {
    required String expectedResponsibilityMembershipId,
  }) {
    final context = _responsibilityContext;
    if (context == null) {
      throw StateError('organization_responsibility_context_required');
    }
    if (!context.profileLeadMembershipIds.containsKey(command.profileId)) {
      throw StateError('organization_profile_responsibility_required');
    }
    return _responsibilityWriteRepository.quickCaptureInScope(
      command: command,
      workspaceScope: WorkspaceWriteScope.organization,
      expectedResponsibilityMembershipId: expectedResponsibilityMembershipId,
    );
  }

  @override
  Future<WorkspaceCaseType> createCaseType({''',
)

controller = 'lib/features/design_v2/v2_workflow_controller.dart'
replace_once(
    controller,
    'class V2WorkflowController {\n',
    '''typedef V2QuickCaptureCommandHandler = Future<QuickCaptureReceipt> Function(
  QuickCaptureCommand command,
);

class V2WorkflowController {
''',
)
replace_once(
    controller,
    '    this.sessionUserId,\n    DateTime Function()? now,',
    '    this.sessionUserId,\n    this.quickCaptureCommandHandler,\n    DateTime Function()? now,',
)
replace_once(
    controller,
    '  final String? sessionUserId;\n  final DateTime Function() _now;',
    '  final String? sessionUserId;\n  final V2QuickCaptureCommandHandler? quickCaptureCommandHandler;\n  final DateTime Function() _now;',
)
replace_once(
    controller,
    '''    final receipt = await learningRepository.quickCapture(
      QuickCaptureCommand(
        operationId: write.operationId,
        profileId: profile.profileId,
        expectedProfileVersion: profile.profileVersion,
        caseType: caseType.baseType,
        organizationCaseTypeId: caseType.organizationCaseTypeId,
        title: _headline(body),
        description: null,
        observedAt: write.observedAt ?? _now(),
        evidenceSummary: body,
      ),
    );
''',
    '''    final command = QuickCaptureCommand(
      operationId: write.operationId,
      profileId: profile.profileId,
      expectedProfileVersion: profile.profileVersion,
      caseType: caseType.baseType,
      organizationCaseTypeId: caseType.organizationCaseTypeId,
      title: _headline(body),
      description: null,
      observedAt: write.observedAt ?? _now(),
      evidenceSummary: body,
    );
    final handler = quickCaptureCommandHandler;
    final receipt = handler == null
        ? await learningRepository.quickCapture(command)
        : await handler(command);
''',
)

org = 'lib/features/design_v2/v2_organization_workspace_page.dart'
replace_once(
    org,
    "import '../../cloud/learning_repository.dart';\nimport '../../cloud/responsibility_read_repository.dart';",
    "import '../../cloud/composer_draft_store.dart';\nimport '../../cloud/learning_repository.dart';\nimport '../../cloud/responsibility_read_repository.dart';\nimport '../../cloud/responsibility_scoped_learning_repository.dart';",
)
replace_once(
    org,
    "import 'v2_fixture.dart';\nimport 'v2_update_flow.dart';\nimport 'v2_workspace_data.dart';",
    "import 'v2_composers.dart';\nimport 'v2_fixture.dart';\nimport 'v2_update_flow.dart';\nimport 'v2_workflow_controller.dart';\nimport 'v2_workspace_data.dart';",
)
replace_once(
    org,
    '''/// D1a is deliberately read-only on the learning side. Organization authority
/// may inspect the already-authorized workspace and see the current teaching
/// responsibility, but Quick Capture remains a separate D1b write boundary.''',
    '''/// Organization authority may supervise the already-authorized workspace and
/// record a new fact without taking over teaching responsibility. Organization
/// Quick Capture stays bound to the selected Profile's current active Lead.''',
)
replace_once(
    org,
    '  Future<void> _checkForUpdates() async {',
    '''  V2WorkflowController? _organizationWorkflowController() {
    final progressiveRepository = widget.runtime.progressiveCaseRepository;
    final learningRepository = widget.runtime.learningRepository;
    if (progressiveRepository == null ||
        learningRepository is! OrganizationQuickCaptureRepository) {
      return null;
    }
    return V2WorkflowController(
      workspace: widget.workspace,
      learningRepository: widget.runtime.learningRepository,
      progressiveCaseRepository: progressiveRepository,
      evidenceAttachmentRepository: widget.runtime.evidenceAttachmentRepository,
      quickCaptureCommandHandler: (command) async {
        final leadMembershipId = widget.responsibility
            .leadMembershipIdForProfile(command.profileId);
        if (leadMembershipId == null) {
          throw const V2WorkflowSaveException(
            '这个学科还没有明确主责老师。先设置主责老师后再建立正式学情，避免问题无人跟进。',
            recordMayBeSaved: false,
          );
        }
        try {
          return await learningRepository.quickCaptureForOrganization(
            command,
            expectedResponsibilityMembershipId: leadMembershipId,
          );
        } catch (error) {
          final detail = error.toString().toLowerCase();
          if (detail.contains('responsibility_conflict')) {
            throw V2WorkflowSaveException(
              '主责老师刚刚发生变化，请关闭当前窗口，刷新学情后再记录。',
              recordMayBeSaved: false,
              cause: error,
            );
          }
          if (detail.contains('case_responsibility_required')) {
            throw V2WorkflowSaveException(
              '这个学科还没有明确主责老师。先设置主责老师后再建立正式学情，避免问题无人跟进。',
              recordMayBeSaved: false,
              cause: error,
            );
          }
          rethrow;
        }
      },
    );
  }

  Future<void> _checkForUpdates() async {''',
)
replace_once(
    org,
    '''                        responsibility: widget.responsibility,
                      )''',
    '''                        responsibility: widget.responsibility,
                        workflowController: _organizationWorkflowController(),
                        composerDraftStore: widget.runtime.composerDraftStore,
                        composerDraftScopeKey:
                            widget.runtime.composerDraftStore != null &&
                                widget.runtime.sessionUserId != null
                            ? '${quickCaptureComposerScopeKey(sessionUserId: widget.runtime.sessionUserId!, organizationId: widget.workspace.organizationId)}:organization'
                            : null,
                        onChanged: widget.onChanged,
                      )''',
)
replace_once(
    org,
    '''    required this.responsibility,
  });

  final TeacherWorkspace workspace;
  final V2WorkspaceData data;
  final WorkspaceResponsibilityContext responsibility;''',
    '''    required this.responsibility,
    required this.workflowController,
    required this.composerDraftStore,
    required this.composerDraftScopeKey,
    required this.onChanged,
  });

  final TeacherWorkspace workspace;
  final V2WorkspaceData data;
  final WorkspaceResponsibilityContext responsibility;
  final V2WorkflowController? workflowController;
  final ComposerDraftStore? composerDraftStore;
  final String? composerDraftScopeKey;
  final VoidCallback? onChanged;''',
)
replace_once(
    org,
    '  List<V2FocusItem> _itemsForStudent(V2Student student) => [',
    '''  Future<void> _openQuickCapture(
    BuildContext context,
    V2Student student,
  ) async {
    final controller = widget.workflowController;
    if (controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前版本暂时不能安全记录机构学情，请刷新或更新后再试。')),
      );
      return;
    }
    final profiles = widget.workspace.students
        .where((profile) => profile.id == student.id)
        .toList(growable: false);
    if (profiles.isEmpty) return;
    final hasLead = profiles.any(
      (profile) =>
          widget.responsibility.leadMembershipIdForProfile(profile.profileId) !=
          null,
    );
    if (!hasLead) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '这个学生当前学科还没有明确主责老师。先设置主责老师后再建立正式学情，避免问题无人跟进。',
          ),
        ),
      );
      return;
    }

    final draftStore = widget.composerDraftStore;
    final draftScopeKey = widget.composerDraftScopeKey;
    ComposerDraftSnapshot? initialDraft;
    if (draftStore != null && draftScopeKey != null) {
      final stored = await draftStore.load(draftScopeKey);
      if (stored?.studentId == student.id) initialDraft = stored;
    }
    if (!context.mounted) return;
    final storedOperationId = initialDraft?.state['operation_id'];
    final operationId =
        storedOperationId is String && storedOperationId.trim().isNotEmpty
        ? storedOperationId
        : createOperationId();
    final persistence = draftStore != null && draftScopeKey != null
        ? V2QuickCapturePersistence(
            store: draftStore,
            scopeKey: draftScopeKey,
            studentId: student.id,
            operationId: operationId,
            initialDraft: initialDraft,
          )
        : null;
    final activeItems = widget.data.focusItemsForStudent(student);
    final existingCases = activeItems
        .map(
          (item) => V2ExistingCaseOption(
            id: item.id,
            title: item.title,
            subject: item.subject,
            statusLabel: _caseStatusLabel(item),
            nextStepLabel: item.nextStep,
            dueLabel: item.dueLabel,
          ),
        )
        .toList(growable: false);
    final problemTypes = controller.caseTypeChoices
        .map(
          (choice) => V2ProblemTypeOption(key: choice.key, label: choice.label),
        )
        .toList(growable: false);
    final saved = await showV2QuickCapture(
      context,
      studentName: student.name,
      subjects: student.subjects,
      problemTypes: problemTypes,
      existingCases: existingCases,
      persistence: persistence,
      onSave: (draft) => controller.quickCapture(
        V2QuickCaptureWrite(
          operationId: operationId,
          studentId: student.id,
          subject: draft.subject,
          caseTypeKey: draft.caseTypeKey,
          body: draft.body,
          attachments: draft.attachments,
        ),
      ),
    );
    if (saved && context.mounted) {
      widget.onChanged?.call();
    }
  }

  String _responsibilitySummaryForStudent(V2Student student) {
    final labels = <String>[];
    for (final profile in widget.workspace.students.where(
      (profile) => profile.id == student.id,
    )) {
      final leadMembershipId = widget.responsibility
          .leadMembershipIdForProfile(profile.profileId);
      final leadName = leadMembershipId == null
          ? '未设置主责'
          : widget.responsibility.displayNameForMembership(leadMembershipId) ??
                '主责老师';
      labels.add('${profile.subject} $leadName');
    }
    return labels.isEmpty ? '主责信息暂不可用' : labels.join(' · ');
  }

  List<V2FocusItem> _itemsForStudent(V2Student student) => [''',
)
replace_once(
    org,
    '''                          leadLabelByCaseId: _leadLabelByCaseId,
                        );''',
    '''                          leadLabelByCaseId: _leadLabelByCaseId,
                          responsibilitySummary: _responsibilitySummaryForStudent(
                            student,
                          ),
                          onQuickCapture: () =>
                              _openQuickCapture(context, student),
                        );''',
)
replace_once(
    org,
    '''    required this.leadLabelByCaseId,
  });

  final V2Student student;
  final List<V2FocusItem> items;
  final Map<String, String> leadLabelByCaseId;''',
    '''    required this.leadLabelByCaseId,
    required this.responsibilitySummary,
    required this.onQuickCapture,
  });

  final V2Student student;
  final List<V2FocusItem> items;
  final Map<String, String> leadLabelByCaseId;
  final String responsibilitySummary;
  final VoidCallback onQuickCapture;''',
)
replace_once(
    org,
    "        subtitle: Text('${student.grade} · $subjectLabel · 暂无学情记录'),\n      );",
    '''        subtitle: Text(
          '${student.grade} · $subjectLabel · 暂无学情记录\n主责：$responsibilitySummary',
        ),
        isThreeLine: true,
        trailing: IconButton(
          key: Key('v2-organization-quick-capture-${student.id}'),
          tooltip: '记录问题',
          onPressed: onQuickCapture,
          icon: const Icon(Icons.note_add_outlined),
        ),
      );''',
)
replace_once(
    org,
    '''      subtitle: Text(
        '${student.grade} · $subjectLabel · '
        '${activeCount == 0 ? '暂无进行中问题' : '$activeCount 个进行中问题'}',
      ),
      children: [''',
    '''      subtitle: Text(
        '${student.grade} · $subjectLabel · '
        '${activeCount == 0 ? '暂无进行中问题' : '$activeCount 个进行中问题'}\n'
        '主责：$responsibilitySummary',
      ),
      trailing: IconButton(
        key: Key('v2-organization-quick-capture-${student.id}'),
        tooltip: '记录问题',
        onPressed: onQuickCapture,
        icon: const Icon(Icons.note_add_outlined),
      ),
      children: [''',
)

test = 'test/cloud/responsibility_scoped_learning_repository_test.dart'
replace_once(
    test,
    "  group('ResponsibilityScopedLearningRepository', () {\n",
    '''  group('ResponsibilityScopedLearningRepository', () {
    test('Organization Quick Capture uses the observed Lead expectation', () async {
      final base = _FakeLearningRepository();
      final writer = _FakeResponsibilityWriteRepository();
      final gateway = ResponsibilityScopedLearningRepository(
        base,
        _FakeResponsibilityReadRepository(_context()),
        writer,
      );

      await gateway.loadWorkspace();
      await gateway.loadContext(organizationId: 'org-1');
      final receipt = await gateway.quickCaptureForOrganization(
        _command(profileId: 'profile-org-only'),
        expectedResponsibilityMembershipId: 'membership-other',
      );

      expect(receipt.caseId, 'case-scoped');
      expect(base.legacyQuickCaptureCalls, 0);
      expect(writer.calls, hasLength(1));
      expect(writer.calls.single.workspaceScope, WorkspaceWriteScope.organization);
      expect(
        writer.calls.single.expectedResponsibilityMembershipId,
        'membership-other',
      );
      expect(writer.calls.single.command.profileId, 'profile-org-only');
    });

''',
)
