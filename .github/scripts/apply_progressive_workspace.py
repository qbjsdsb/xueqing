from pathlib import Path

path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
text = path.read_text()


def replace_once(label: str, old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    text = text.replace(old, new, 1)


replace_once(
    'progressive repository import',
    "import '../../../cloud/organization_member_provisioning_repository.dart';\nimport '../../../config/app_config.dart';",
    "import '../../../cloud/organization_member_provisioning_repository.dart';\nimport '../../../cloud/progressive_case_repository.dart';\nimport '../../../config/app_config.dart';",
)
replace_once(
    'progressive form import',
    "import 'member_onboarding_page.dart';\nimport 'evidence_attachment_picker.dart';",
    "import 'member_onboarding_page.dart';\nimport 'evidence_attachment_picker.dart';\nimport 'progressive_case_forms.dart';",
)
replace_once(
    'entry constructor repository',
    "    this.authRepository,\n    this.learningRepository,\n    this.evidenceAttachmentRepository,",
    "    this.authRepository,\n    this.learningRepository,\n    this.progressiveCaseRepository,\n    this.evidenceAttachmentRepository,",
)
replace_once(
    'entry repository field',
    "  final AuthRepository? authRepository;\n  final LearningRepository? learningRepository;\n  final EvidenceAttachmentRepository? evidenceAttachmentRepository;",
    "  final AuthRepository? authRepository;\n  final LearningRepository? learningRepository;\n  final ProgressiveCaseRepository? progressiveCaseRepository;\n  final EvidenceAttachmentRepository? evidenceAttachmentRepository;",
)
replace_once(
    'entry state repository',
    "  AuthRepository? _authRepository;\n  LearningRepository? _learningRepository;\n  EvidenceAttachmentRepository? _evidenceAttachmentRepository;",
    "  AuthRepository? _authRepository;\n  LearningRepository? _learningRepository;\n  ProgressiveCaseRepository? _progressiveCaseRepository;\n  EvidenceAttachmentRepository? _evidenceAttachmentRepository;",
)
replace_once(
    'injected progressive repository',
    "      _authRepository = widget.authRepository;\n      _learningRepository = widget.learningRepository;\n      _evidenceAttachmentRepository = widget.evidenceAttachmentRepository;",
    "      _authRepository = widget.authRepository;\n      _learningRepository = widget.learningRepository;\n      _progressiveCaseRepository = widget.progressiveCaseRepository;\n      _evidenceAttachmentRepository = widget.evidenceAttachmentRepository;",
)
replace_once(
    'cloud progressive repository',
    "      _authRepository = SupabaseAuthRepository(CloudClient.client);\n      _learningRepository = SupabaseLearningRepository(CloudClient.client);\n      _evidenceAttachmentRepository = SupabaseEvidenceAttachmentRepository(\n        CloudClient.client,\n      );",
    "      _authRepository = SupabaseAuthRepository(CloudClient.client);\n      _learningRepository = SupabaseLearningRepository(CloudClient.client);\n      _progressiveCaseRepository = SupabaseProgressiveCaseRepository(\n        CloudClient.client,\n      );\n      _evidenceAttachmentRepository = SupabaseEvidenceAttachmentRepository(\n        CloudClient.client,\n      );",
)
replace_once(
    'workspace page injection',
    "          repository: _learningRepository!,\n          evidenceAttachmentRepository: _evidenceAttachmentRepository,",
    "          repository: _learningRepository!,\n          progressiveCaseRepository: _progressiveCaseRepository,\n          evidenceAttachmentRepository: _evidenceAttachmentRepository,",
)
replace_once(
    'workspace constructor repository',
    "    required this.repository,\n    this.evidenceAttachmentRepository,",
    "    required this.repository,\n    this.progressiveCaseRepository,\n    this.evidenceAttachmentRepository,",
)
replace_once(
    'workspace repository field',
    "  final LearningRepository repository;\n  final EvidenceAttachmentRepository? evidenceAttachmentRepository;",
    "  final LearningRepository repository;\n  final ProgressiveCaseRepository? progressiveCaseRepository;\n  final EvidenceAttachmentRepository? evidenceAttachmentRepository;",
)

methods = '''  Future<void> _recordProgress(
    WorkspaceStudent student,
    WorkspaceCase learningCase, {
    WorkspaceAction? currentAction,
    bool completeCurrentActionInitially = false,
    bool preserveSelection = false,
  }) async {
    final repository = widget.progressiveCaseRepository;
    if (repository == null) {
      return;
    }
    final workspace = await _workspaceFuture;
    if (!mounted) {
      return;
    }
    final result = await showCaseProgressForm(
      context,
      repository: repository,
      learningCase: learningCase,
      currentAction: currentAction,
      completeCurrentActionInitially: completeCurrentActionInitially,
      businessDate: workspace.businessDate,
    );
    if (!mounted || result == null) {
      return;
    }
    final reloaded = preserveSelection
        ? await _reload(
            preserveStudent: student,
            preserveCaseId: learningCase.id,
          )
        : await _reload();
    if (!mounted || !reloaded) {
      return;
    }
    final message = switch (result.nextStep) {
      'remind' => '已记录进展，并设置提醒。',
      'close' => '已记录进展，并结束跟进。',
      _ => '已记录进展。',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _endProgressiveFollowUp(
    WorkspaceStudent student,
    WorkspaceCase learningCase, {
    bool preserveSelection = false,
  }) async {
    final repository = widget.progressiveCaseRepository;
    if (repository == null) {
      return;
    }
    final result = await showEndCaseFollowUpForm(
      context,
      repository: repository,
      learningCase: learningCase,
    );
    if (!mounted || result == null) {
      return;
    }
    final reloaded = preserveSelection
        ? await _reload(
            preserveStudent: student,
            preserveCaseId: learningCase.id,
          )
        : await _reload();
    if (!mounted || !reloaded) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已结束跟进，历史记录完整保留。')),
    );
  }

'''
replace_once(
    'insert progressive workspace methods',
    "  Future<CaseCommandReceipt?> _showCaseForm({",
    methods + "  Future<CaseCommandReceipt?> _showCaseForm({",
)

replace_once(
    'progressive Today completion',
    "  Future<void> _completeAction(\n    TeacherWorkspace workspace,\n    WorkspaceActionWithContext item,\n  ) async {\n    if (_completingActionId != null) {\n      return;\n    }\n    setState(() => _completingActionId = item.action.id);",
    "  Future<void> _completeAction(\n    TeacherWorkspace workspace,\n    WorkspaceActionWithContext item,\n  ) async {\n    if (_completingActionId != null) {\n      return;\n    }\n    if (widget.progressiveCaseRepository != null) {\n      setState(() => _completingActionId = item.action.id);\n      try {\n        await _recordProgress(\n          item.student,\n          item.learningCase,\n          currentAction: item.action,\n          completeCurrentActionInitially: true,\n        );\n      } finally {\n        if (mounted) {\n          setState(() => _completingActionId = null);\n        }\n      }\n      return;\n    }\n    setState(() => _completingActionId = item.action.id);",
)
replace_once(
    'action group progressive flag',
    "          student: group.first.student,\n          items: group,\n          onOpenCase:",
    "          student: group.first.student,\n          items: group,\n          progressiveFlow: widget.progressiveCaseRepository != null,\n          onOpenCase:",
)
replace_once(
    'case detail mode variables',
    "    final primaryAction = learningCase.primaryAction;\n    final commandLabel = _caseCommandLabel(learningCase);\n    final canStabilize = _canStabilizeCase(learningCase);",
    "    final primaryAction = learningCase.primaryAction;\n    final useProgressiveFlow = widget.progressiveCaseRepository != null;\n    final commandLabel = useProgressiveFlow\n        ? null\n        : _caseCommandLabel(learningCase);\n    final canStabilize =\n        !useProgressiveFlow && _canStabilizeCase(learningCase);",
)
replace_once(
    'case next action copy',
    "        _WorkspaceNarrativeSection(\n          title: '下一步',\n          content: primaryAction == null\n              ? '当前没有待完成的主要行动。'\n              : '${primaryAction.title}（${_formatActionDate(primaryAction)}）',\n          isPrimary: true,\n        ),",
    "        _WorkspaceNarrativeSection(\n          title: useProgressiveFlow ? '当前提醒' : '下一步',\n          content: primaryAction == null\n              ? useProgressiveFlow\n                    ? '当前没有待办；有新情况时直接记录进展。'\n                    : '当前没有待完成的主要行动。'\n              : '${primaryAction.title}（${_formatActionDate(primaryAction)}）',\n          isPrimary: true,\n        ),",
)
replace_once(
    'case state notices',
    "        if (learningCase.status == LearningCaseStatus.pendingVerification)\n          const _WorkspaceStateNotice(\n            title: '本次验证通过，仍待确认是否稳定',\n            message: '本次检查已经通过，还需要你确认这个问题是否已经稳定。',\n            icon: Icons.fact_check_outlined,\n          )\n        else if (learningCase.status == LearningCaseStatus.stable)\n          const _WorkspaceStateNotice(\n            title: '稳定；仍需安排下一次检查',\n            message: '当前表现已经稳定，但还没有结束跟进；请保留下一次复查。',\n            icon: Icons.check_circle_outline,\n          )\n        else if (learningCase.status == LearningCaseStatus.newCase)\n          const _WorkspaceStateNotice(\n            title: '待整理问题',\n            message: '这是一条课堂快速记录；确认前请补充教师判断和合适的下一步。',\n            icon: Icons.edit_note_outlined,\n          ),",
    "        if (learningCase.status == LearningCaseStatus.pendingVerification)\n          _WorkspaceStateNotice(\n            title: useProgressiveFlow ? '本次检查已经记录' : '本次验证通过，仍待确认是否稳定',\n            message: useProgressiveFlow\n                ? '可以继续观察、设置提醒，或者结束本轮跟进。'\n                : '本次检查已经通过，还需要你确认这个问题是否已经稳定。',\n            icon: Icons.fact_check_outlined,\n          )\n        else if (learningCase.status == LearningCaseStatus.stable)\n          _WorkspaceStateNotice(\n            title: useProgressiveFlow ? '当前表现已经稳定' : '稳定；仍需安排下一次检查',\n            message: useProgressiveFlow\n                ? '可以继续观察，也可以直接结束本轮跟进。'\n                : '当前表现已经稳定，但还没有结束跟进；请保留下一次复查。',\n            icon: Icons.check_circle_outline,\n          )\n        else if (learningCase.status == LearningCaseStatus.newCase)\n          _WorkspaceStateNotice(\n            title: '待整理问题',\n            message: useProgressiveFlow\n                ? '这是一条课堂快速记录；有新情况时继续记录，确认无需再跟进时可以直接结束。'\n                : '这是一条课堂快速记录；确认前请补充教师判断和合适的下一步。',\n            icon: Icons.edit_note_outlined,\n          ),",
)
progressive_section = '''        if (useProgressiveFlow &&
            learningCase.status != LearningCaseStatus.closed) ...[
          const SizedBox(height: AppSpacing.md),
          _WorkspaceCaseCommandSection(
            title: '继续理解这个问题',
            message: '记录本次真实发生的情况；只有确实需要提醒自己时才设置下一步。',
            buttonLabel: '记录进展',
            onPressed: () => unawaited(
              _recordProgress(
                student,
                learningCase,
                currentAction: primaryAction,
                preserveSelection: true,
              ),
            ),
            secondaryButtonLabel: '结束跟进',
            onSecondaryPressed: () => unawaited(
              _endProgressiveFollowUp(
                student,
                learningCase,
                preserveSelection: true,
              ),
            ),
          ),
        ],
'''
replace_once(
    'insert progressive case section',
    "        if (commandLabel != null) ...[",
    progressive_section + "        if (commandLabel != null) ...[",
)
replace_once(
    'legacy stable close guard',
    "        if (learningCase.status == LearningCaseStatus.stable) ...[",
    "        if (!useProgressiveFlow &&\n            learningCase.status == LearningCaseStatus.stable) ...[",
)
replace_once(
    'command section constructor',
    "    required this.buttonLabel,\n    required this.onPressed,\n  });",
    "    required this.buttonLabel,\n    required this.onPressed,\n    this.secondaryButtonLabel,\n    this.onSecondaryPressed,\n  });",
)
replace_once(
    'command section fields',
    "  final String buttonLabel;\n  final VoidCallback onPressed;",
    "  final String buttonLabel;\n  final VoidCallback onPressed;\n  final String? secondaryButtonLabel;\n  final VoidCallback? onSecondaryPressed;",
)
replace_once(
    'command section secondary action',
    "                FilledButton.icon(\n                  onPressed: onPressed,\n                  icon: Icon(Icons.arrow_forward, size: 18),\n                  label: Text(buttonLabel),\n                ),",
    "                FilledButton.icon(\n                  onPressed: onPressed,\n                  icon: Icon(Icons.arrow_forward, size: 18),\n                  label: Text(buttonLabel),\n                ),\n                if (secondaryButtonLabel != null &&\n                    onSecondaryPressed != null) ...[\n                  const SizedBox(height: AppSpacing.xs),\n                  OutlinedButton.icon(\n                    onPressed: onSecondaryPressed,\n                    icon: const Icon(Icons.stop_circle_outlined, size: 18),\n                    label: Text(secondaryButtonLabel!),\n                  ),\n                ],",
)
replace_once(
    'action group constructor progressive flag',
    "    required this.items,\n    required this.onOpenCase,",
    "    required this.items,\n    required this.progressiveFlow,\n    required this.onOpenCase,",
)
replace_once(
    'action group progressive field',
    "  final List<WorkspaceActionWithContext> items;\n  final ValueChanged<WorkspaceCase> onOpenCase;",
    "  final List<WorkspaceActionWithContext> items;\n  final bool progressiveFlow;\n  final ValueChanged<WorkspaceCase> onOpenCase;",
)
replace_once(
    'Today action button copy',
    "                            icon: const Icon(Icons.check),\n                            label: const Text('完成行动'),",
    "                            icon: Icon(\n                              progressiveFlow\n                                  ? Icons.edit_note_outlined\n                                  : Icons.check,\n                            ),\n                            label: Text(progressiveFlow ? '处理' : '完成行动'),",
)

path.write_text(text)
