from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected one anchor, found {count}: {old[:100]!r}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


def replace_all_checked(path: str, old: str, new: str, minimum: int = 1) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count < minimum:
        raise RuntimeError(f"{path}: expected at least {minimum} anchors, found {count}: {old!r}")
    file.write_text(text.replace(old, new), encoding="utf-8")


learning = "lib/cloud/learning_repository.dart"
workspace = "lib/features/teacher_workspace/presentation/teacher_workspace_page.dart"
ux_copy = "docs/design/UX_COPY.md"

# Expose the current membership id so a teacher can export only records they
# personally created/performed without weakening any server-side permission.
replace_once(
    learning,
    """    this.businessDate,\n    this.organizationId,\n    this.caseTypes = WorkspaceCaseType.builtInTypes,""",
    """    this.businessDate,\n    this.organizationId,\n    this.membershipId,\n    this.caseTypes = WorkspaceCaseType.builtInTypes,""",
)
replace_once(
    learning,
    """  final DateTime? businessDate;\n  final String? organizationId;\n  final List<WorkspaceCaseType> caseTypes;""",
    """  final DateTime? businessDate;\n  final String? organizationId;\n  final String? membershipId;\n  final List<WorkspaceCaseType> caseTypes;""",
)
replace_all_checked(
    learning,
    """        organizationId: organizationId,\n        viewerName: viewerName,""",
    """        organizationId: organizationId,\n        membershipId: membershipId,\n        viewerName: viewerName,""",
    minimum=1,
)
replace_once(
    learning,
    """      organizationId: organizationId,\n      viewerName: viewerName,""",
    """      organizationId: organizationId,\n      membershipId: membershipId,\n      viewerName: viewerName,""",
)

# Read operation identity with lifecycle events. It lets the display layer fold
# multiple database audit rows from one teacher action into one readable item.
replace_once(
    learning,
    ".select('id,learning_case_id,event_type,occurred_at,metadata')",
    ".select(\n              'id,learning_case_id,event_type,occurred_at,metadata,'\n              'operation_id,operation_event_key',\n            )",
)

old_timeline = """    final timeline = <WorkspaceTimelineEvent>[];\n    for (final eventRow\n        in eventRows[caseId] ?? const <Map<String, dynamic>>[]) {\n      final eventType = _stringValue(eventRow['event_type']) ?? 'event';\n      timeline.add(\n        WorkspaceTimelineEvent(\n          id: _requiredString(eventRow['id'], 'event_id'),\n          occurredAt: _requiredDateTime(\n            eventRow['occurred_at'],\n            'event_occurred_at',\n          ),\n          typeLabel: _eventTypeLabel(eventType),\n          text: _eventText(eventType, eventRow['metadata']),\n        ),\n      );\n    }\n    for (final item in evidence) {\n      timeline.add(\n        WorkspaceTimelineEvent(\n          id: 'evidence:${item.id}',\n          occurredAt: item.observedAt,\n          typeLabel: 'Evidence / 证据',\n          text: '${item.title}：${item.summary}',\n        ),\n      );\n    }\n    for (final item in interventions) {\n      timeline.add(\n        WorkspaceTimelineEvent(\n          id: 'intervention:${item.id}',\n          occurredAt: item.occurredAt,\n          typeLabel: 'Intervention / 教学动作',\n          text: item.strategy,\n        ),\n      );\n    }\n    for (final item in assessments) {\n      timeline.add(\n        WorkspaceTimelineEvent(\n          id: 'assessment:${item.id}',\n          occurredAt: item.assessedAt,\n          typeLabel: 'Assessment / 验证',\n          text:\n              '${_assessmentResultLabel(item.result)}：${item.evidenceSummary}',\n        ),\n      );\n    }\n    timeline.sort((left, right) => right.occurredAt.compareTo(left.occurredAt));\n"""
new_timeline = """    final timeline = buildTeacherReadableTimeline(\n      caseTitle: _requiredString(row['title'], 'case_title'),\n      firstObservedAt: _requiredDateTime(\n        row['first_observed_at'],\n        'case_first_observed_at',\n      ),\n      evidence: evidence,\n      interventions: interventions,\n      assessments: assessments,\n      actions: actions,\n      eventRows: eventRows[caseId] ?? const <Map<String, dynamic>>[],\n    );\n"""
replace_once(learning, old_timeline, new_timeline)

readable_timeline_helpers = r'''List<WorkspaceTimelineEvent> buildTeacherReadableTimeline({
  required String caseTitle,
  required DateTime firstObservedAt,
  required List<WorkspaceEvidence> evidence,
  required List<WorkspaceIntervention> interventions,
  required List<WorkspaceAssessment> assessments,
  required List<WorkspaceAction> actions,
  required List<Map<String, dynamic>> eventRows,
}) {
  final actionById = <String, WorkspaceAction>{
    for (final action in actions) action.id: action,
  };
  final eventByRecordId = <String, Map<String, dynamic>>{};
  final operationTypes = <String, Set<String>>{};
  final initialEvidenceIds = <String>{};

  for (final event in eventRows) {
    final eventType = _stringValue(event['event_type']) ?? 'event';
    final operationId = _stringValue(event['operation_id']);
    if (operationId != null) {
      operationTypes.putIfAbsent(operationId, () => <String>{}).add(eventType);
    }
    final metadata = _timelineMetadata(event['metadata']);
    final recordId = _timelineRecordId(metadata);
    if (recordId != null) {
      eventByRecordId[recordId] = event;
    }
    if (eventType == 'case_created') {
      final evidenceId = _stringValue(metadata['evidence_id']);
      if (evidenceId != null) initialEvidenceIds.add(evidenceId);
    }
  }

  final timeline = <WorkspaceTimelineEvent>[];
  final foldedOperationIds = <String>{};

  for (final item in evidence) {
    final event = eventByRecordId[item.id] ??
        _timelineCaseCreatedEvent(eventRows, item.id);
    final operationId = _stringValue(event?['operation_id']);
    if (operationId != null) foldedOperationIds.add(operationId);
    final isInitial = initialEvidenceIds.contains(item.id) ||
        (initialEvidenceIds.isEmpty &&
            item.title == caseTitle &&
            item.observedAt.difference(firstObservedAt).abs() <
                const Duration(seconds: 2));
    final body = isInitial && item.title == caseTitle
        ? item.summary
        : '${item.title}：${item.summary}';
    timeline.add(
      WorkspaceTimelineEvent(
        id: 'evidence:${item.id}',
        occurredAt: item.observedAt,
        typeLabel: isInitial ? '发现问题' : '学生表现',
        text: _timelineTextWithNextStep(
          body,
          _timelineNextStep(event, actionById),
        ),
      ),
    );
  }

  for (final item in interventions) {
    final event = eventByRecordId[item.id];
    final operationId = _stringValue(event?['operation_id']);
    if (operationId != null) foldedOperationIds.add(operationId);
    final body = item.notes?.trim().isNotEmpty == true
        ? '${item.strategy}\n${item.notes!.trim()}'
        : item.strategy;
    timeline.add(
      WorkspaceTimelineEvent(
        id: 'intervention:${item.id}',
        occurredAt: item.occurredAt,
        typeLabel: '教学处理',
        text: _timelineTextWithNextStep(
          body,
          _timelineNextStep(event, actionById),
        ),
      ),
    );
  }

  for (final item in assessments) {
    final event = eventByRecordId[item.id];
    final operationId = _stringValue(event?['operation_id']);
    if (operationId != null) foldedOperationIds.add(operationId);
    final types = operationId == null
        ? const <String>{}
        : operationTypes[operationId] ?? const <String>{};
    final typeLabel = types.contains('case_closed')
        ? '检查结果 · 结束跟进'
        : types.contains('case_stabilized')
        ? '检查结果 · 暂时稳定'
        : '检查结果';
    final details = item.notes?.trim().isNotEmpty == true
        ? '${item.evidenceSummary}\n${item.notes!.trim()}'
        : item.evidenceSummary;
    final body = '${_assessmentResultLabel(item.result)}：$details';
    timeline.add(
      WorkspaceTimelineEvent(
        id: 'assessment:${item.id}',
        occurredAt: item.assessedAt,
        typeLabel: typeLabel,
        text: _timelineTextWithNextStep(
          body,
          _timelineNextStep(event, actionById),
        ),
      ),
    );
  }

  for (final event in eventRows) {
    final operationId = _stringValue(event['operation_id']);
    if (operationId != null && foldedOperationIds.contains(operationId)) {
      continue;
    }
    final lifecycle = _teacherLifecycleTimelineEvent(event, actionById);
    if (lifecycle != null) timeline.add(lifecycle);
  }

  timeline.sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
  return List<WorkspaceTimelineEvent>.unmodifiable(timeline);
}

Map<String, dynamic> _timelineMetadata(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String? _timelineRecordId(Map<String, dynamic> metadata) {
  for (final key in const <String>[
    'record_id',
    'evidence_id',
    'intervention_id',
    'assessment_id',
  ]) {
    final value = _stringValue(metadata[key]);
    if (value != null) return value;
  }
  return null;
}

Map<String, dynamic>? _timelineCaseCreatedEvent(
  List<Map<String, dynamic>> eventRows,
  String evidenceId,
) {
  for (final event in eventRows) {
    if (_stringValue(event['event_type']) != 'case_created') continue;
    if (_stringValue(_timelineMetadata(event['metadata'])['evidence_id']) ==
        evidenceId) {
      return event;
    }
  }
  return null;
}

String? _timelineNextStep(
  Map<String, dynamic>? event,
  Map<String, WorkspaceAction> actionById,
) {
  if (event == null) return null;
  final metadata = _timelineMetadata(event['metadata']);
  final actionId = _stringValue(metadata['next_action_id']) ??
      _stringValue(metadata['action_id']);
  if (actionId == null) return null;
  final action = actionById[actionId];
  if (action == null) return null;
  final dueDate = action.businessDueDate ?? action.dueAt;
  return dueDate == null
      ? action.title
      : '${action.title}（${dueDate.month}月${dueDate.day}日）';
}

String _timelineTextWithNextStep(String body, String? nextStep) {
  return nextStep == null ? body : '$body\n下一步：$nextStep';
}

WorkspaceTimelineEvent? _teacherLifecycleTimelineEvent(
  Map<String, dynamic> event,
  Map<String, WorkspaceAction> actionById,
) {
  final eventType = _stringValue(event['event_type']) ?? 'event';
  final metadata = _timelineMetadata(event['metadata']);
  final occurredAt = _requiredDateTime(event['occurred_at'], 'event_occurred_at');
  final id = _requiredString(event['id'], 'event_id');
  final nextStep = _timelineNextStep(event, actionById);
  switch (eventType) {
    case 'case_stabilized':
      return WorkspaceTimelineEvent(
        id: id,
        occurredAt: occurredAt,
        typeLabel: '暂时稳定',
        text: _timelineTextWithNextStep(
          '老师确认当前表现已经达到预期。',
          nextStep,
        ),
      );
    case 'case_closed':
      final note = _stringValue(metadata['closure_note']);
      final body = note ??
          switch (_stringValue(metadata['closure_reason'])) {
            'resolved' => '当前问题已经达到预期，本轮跟进结束。',
            'pause_tracking' => '目前暂不继续跟进，历史记录完整保留。',
            'not_issue' => '确认无需继续作为问题跟进。',
            _ => '本轮跟进结束，历史记录完整保留。',
          };
      return WorkspaceTimelineEvent(
        id: id,
        occurredAt: occurredAt,
        typeLabel: '结束跟进',
        text: body,
      );
    case 'case_reopened':
      return WorkspaceTimelineEvent(
        id: id,
        occurredAt: occurredAt,
        typeLabel: '重新跟进',
        text: _timelineTextWithNextStep(
          '出现新的相关表现，重新开始跟进。',
          nextStep,
        ),
      );
    case 'action_completed':
      return WorkspaceTimelineEvent(
        id: id,
        occurredAt: occurredAt,
        typeLabel: '完成一步',
        text: _timelineTextWithNextStep('完成了当前安排。', nextStep),
      );
    case 'action_rescheduled':
      return WorkspaceTimelineEvent(
        id: id,
        occurredAt: occurredAt,
        typeLabel: '调整提醒',
        text: '调整了下一次提醒时间。',
      );
    default:
      return null;
  }
}

'''
replace_once(
    learning,
    "String createOperationId() {",
    readable_timeline_helpers + "String createOperationId() {",
)

old_event_helpers = """String _eventTypeLabel(String value) {\n  return switch (value) {\n    'case_created' => 'Case / 创建',\n    'case_confirmed' => 'Case / 确认',\n    'evidence_recorded' => 'Evidence / 证据',\n    'intervention_recorded' => 'Intervention / 教学动作',\n    'assessment_recorded' => 'Assessment / 验证',\n    'case_stabilized' => 'Case / 稳定',\n    'case_closed' => 'Case / 关闭',\n    'case_reopened' => 'Case / 重新打开',\n    'action_completed' => 'Action / 完成',\n    'action_rescheduled' => 'Action / 改期',\n    _ => '记录',\n  };\n}\n\nString _eventText(String eventType, dynamic rawMetadata) {\n  final metadata = rawMetadata is Map\n      ? Map<String, dynamic>.from(rawMetadata)\n      : const <String, dynamic>{};\n  return switch (eventType) {\n    'case_created' => '创建了这条 Learning Case。',\n    'case_confirmed' => 'Case 已确认，进入正式跟进。',\n    'evidence_recorded' => '补充了一条 Evidence。',\n    'intervention_recorded' => '记录了一次教学动作。',\n    'assessment_recorded' =>\n      '记录了一次验证：${_assessmentResultLabel(metadata['result'])}。',\n    'case_stabilized' => '教师确认 Case 已稳定，仍可安排复查。',\n    'case_closed' => 'Case 已关闭。',\n    'case_reopened' => 'Case 因关闭后的新复发证据重新打开。',\n    'action_completed' => '完成了当前行动，并安排了下一步。',\n    'action_rescheduled' => '调整了下一行动的日期。',\n    _ => '记录了一条 Case 事件。',\n  };\n}\n\n"""
replace_once(learning, old_event_helpers, "")

# Teacher workspace: connect export in real runtime and keep it optional in tests.
replace_once(
    workspace,
    "import 'package:flutter/foundation.dart';",
    "import 'package:file_saver/file_saver.dart';\nimport 'package:flutter/foundation.dart';",
)
replace_once(
    workspace,
    "import '../../../cloud/learning_repository.dart';",
    "import '../../../cloud/learning_export_repository.dart';\nimport '../../../cloud/learning_repository.dart';",
)
replace_once(
    workspace,
    "import '../../../config/app_config.dart';",
    "import '../../../config/app_config.dart';\nimport '../../../export/learning_history_export.dart';",
)
replace_once(
    workspace,
    """    this.learningRepository,\n    this.progressiveCaseRepository,""",
    """    this.learningRepository,\n    this.learningExportRepository,\n    this.progressiveCaseRepository,""",
)
replace_once(
    workspace,
    """  final LearningRepository? learningRepository;\n  final ProgressiveCaseRepository? progressiveCaseRepository;""",
    """  final LearningRepository? learningRepository;\n  final LearningExportRepository? learningExportRepository;\n  final ProgressiveCaseRepository? progressiveCaseRepository;""",
)
replace_once(
    workspace,
    """  LearningRepository? _learningRepository;\n  ProgressiveCaseRepository? _progressiveCaseRepository;""",
    """  LearningRepository? _learningRepository;\n  LearningExportRepository? _learningExportRepository;\n  ProgressiveCaseRepository? _progressiveCaseRepository;""",
)
replace_once(
    workspace,
    """      _learningRepository = widget.learningRepository;\n      _progressiveCaseRepository = widget.progressiveCaseRepository;""",
    """      _learningRepository = widget.learningRepository;\n      _learningExportRepository = widget.learningExportRepository;\n      _progressiveCaseRepository = widget.progressiveCaseRepository;""",
)
replace_once(
    workspace,
    """      _learningRepository = SupabaseLearningRepository(CloudClient.client);\n      _progressiveCaseRepository = SupabaseProgressiveCaseRepository(""",
    """      _learningRepository = SupabaseLearningRepository(CloudClient.client);\n      _learningExportRepository = SupabaseLearningExportRepository(\n        CloudClient.client,\n      );\n      _progressiveCaseRepository = SupabaseProgressiveCaseRepository(""",
)
replace_once(
    workspace,
    """          repository: _learningRepository!,\n          progressiveCaseRepository: _progressiveCaseRepository,""",
    """          repository: _learningRepository!,\n          learningExportRepository: _learningExportRepository,\n          progressiveCaseRepository: _progressiveCaseRepository,""",
)
replace_once(
    workspace,
    """    required this.repository,\n    this.progressiveCaseRepository,""",
    """    required this.repository,\n    this.learningExportRepository,\n    this.progressiveCaseRepository,""",
)
replace_once(
    workspace,
    """  final LearningRepository repository;\n  final ProgressiveCaseRepository? progressiveCaseRepository;""",
    """  final LearningRepository repository;\n  final LearningExportRepository? learningExportRepository;\n  final ProgressiveCaseRepository? progressiveCaseRepository;""",
)
replace_once(
    workspace,
    """  bool _checkingForUpdates = false;\n  int _loadSequence = 0;""",
    """  bool _checkingForUpdates = false;\n  bool _exportingHistory = false;\n  int _loadSequence = 0;""",
)

export_methods = r'''  Future<void> _exportStudentSubjectHistory(
    TeacherWorkspace workspace,
    WorkspaceStudent student,
  ) async {
    final repository = widget.learningExportRepository;
    final organizationId = workspace.organizationId;
    if (repository == null || organizationId == null || _exportingHistory) {
      return;
    }
    await _runHistoryExport(() {
      final teacherNames = <String, String>{
        if (workspace.membershipId != null)
          workspace.membershipId!: workspace.viewerName,
      };
      return repository.loadStudentSubjectHistory(
        organizationId: organizationId,
        profileId: student.profileId,
        studentName: student.name,
        subjectName: student.subject,
        teacherNamesByMembershipId: teacherNames,
      );
    });
  }

  Future<void> _exportMyHistory(TeacherWorkspace workspace) async {
    final repository = widget.learningExportRepository;
    final organizationId = workspace.organizationId;
    final membershipId = workspace.membershipId;
    if (repository == null ||
        organizationId == null ||
        membershipId == null ||
        _exportingHistory) {
      return;
    }
    await _runHistoryExport(
      () => repository.loadTeacherHistory(
        organizationId: organizationId,
        membershipId: membershipId,
        teacherName: workspace.viewerName,
        teacherNamesByMembershipId: <String, String>{
          membershipId: workspace.viewerName,
        },
      ),
    );
  }

  Future<void> _runHistoryExport(
    Future<LearningHistoryExportData> Function() loadData,
  ) async {
    setState(() => _exportingHistory = true);
    try {
      final data = await loadData();
      final bytes = const LearningHistoryWorkbookBuilder().build(data);
      final savedPath = await FileSaver.instance.saveAs(
        name: data.suggestedFileName,
        bytes: bytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (!mounted || savedPath == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出 ${data.records.length} 条记录。')),
      );
    } catch (error) {
      if (!mounted) return;
      final detail = error.toString().toLowerCase();
      final message = detail.contains('permission') ||
              detail.contains('row-level') ||
              detail.contains('rls')
          ? '当前账号无权导出这个范围的学情记录。'
          : detail.contains('network') ||
                  detail.contains('socket') ||
                  detail.contains('timeout')
              ? '网络暂时不可用，未生成不完整的导出文件。'
              : '导出失败，没有改动任何学情记录。请重试。';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _exportingHistory = false);
    }
  }

'''
replace_once(
    workspace,
    "  Future<void> _showQuickCapture({WorkspaceStudent? student}) async {",
    export_methods + "  Future<void> _showQuickCapture({WorkspaceStudent? student}) async {",
)

# Pass export capability into the management area.
replace_once(
    workspace,
    """      provisioningRepository: widget.memberProvisioningRepository,\n      organizationId: organizationId,""",
    """      provisioningRepository: widget.memberProvisioningRepository,\n      learningExportRepository: widget.learningExportRepository,\n      organizationId: organizationId,""",
)

# Teacher list page gets a self-export action; student detail gets profile export.
replace_once(
    workspace,
    """              actions: [\n                if (workspace.canManageCaseTypes &&""",
    """              actions: [\n                if (widget.learningExportRepository != null &&\n                    workspace.organizationId != null &&\n                    workspace.membershipId != null)\n                  OutlinedButton.icon(\n                    key: const Key('workspace-export-my-history'),\n                    onPressed: _exportingHistory\n                        ? null\n                        : () => unawaited(_exportMyHistory(workspace)),\n                    icon: const Icon(Icons.download_outlined),\n                    label: const Text('导出我的记录'),\n                  ),\n                if (workspace.canManageCaseTypes &&""",
)
replace_once(
    workspace,
    "return _buildStudentDetail(_selectedStudent!, sizeClass);",
    "return _buildStudentDetail(workspace, _selectedStudent!, sizeClass);",
)
replace_once(
    workspace,
    """  Widget _buildStudentDetail(\n    WorkspaceStudent student,\n    WindowSizeClass sizeClass,""",
    """  Widget _buildStudentDetail(\n    TeacherWorkspace workspace,\n    WorkspaceStudent student,\n    WindowSizeClass sizeClass,""",
)
replace_once(
    workspace,
    """          actions: [\n            FilledButton.icon(\n              onPressed: () => _showQuickCapture(student: student),""",
    """          actions: [\n            if (widget.learningExportRepository != null &&\n                workspace.organizationId != null)\n              OutlinedButton.icon(\n                key: const Key('workspace-export-student-subject'),\n                onPressed: _exportingHistory\n                    ? null\n                    : () => unawaited(\n                        _exportStudentSubjectHistory(workspace, student),\n                      ),\n                icon: const Icon(Icons.download_outlined),\n                label: const Text('导出这门学科'),\n              ),\n            FilledButton.icon(\n              onPressed: () => _showQuickCapture(student: student),""",
)

# Chinese-first copy: internal identifiers stay untouched; teacher-facing labels do not.
replacements = {
    "'历史 timeline'": "'跟进记录'",
    "'收起历史'": "'只看最近记录'",
    "'展开历史'": "'查看全部记录'",
    "'已采取的方法'": "'教学处理'",
    "'尚未记录教学动作。'": "'还没有记录教学处理。'",
    "'验证记录'": "'检查记录'",
    "'尚未记录验证。'": "'还没有记录检查结果。'",
    "_CaseCommandMode.intervention => '记录教学动作'": "_CaseCommandMode.intervention => '记录教学处理'",
    "_CaseCommandMode.assessment => '记录验证结果'": "_CaseCommandMode.assessment => '记录检查结果'",
    "'系统类型始终保留。自定义类型只负责分类，所有问题仍沿用同一套证据、行动和验证流程。'": "'系统类型始终保留。自定义类型只负责分类，所有问题仍沿用同一套学生表现、教学处理、检查和跟进流程。'",
}
for old, new in replacements.items():
    replace_all_checked(workspace, old, new)
replace_all_checked(workspace, "下一行动", "下一步")
replace_all_checked(workspace, "operation ID", "提交标识")

# Render timeline by day; within a day show the clock time once per readable record.
replace_once(
    workspace,
    """              : Column(\n                  children: [\n                    for (final event in visibleTimeline)\n                      _WorkspaceTimelineItem(event: event),\n                  ],\n                ),""",
    """              : _WorkspaceTimelineList(events: visibleTimeline),""",
)

old_item = r'''class _WorkspaceTimelineItem extends StatelessWidget {
  const _WorkspaceTimelineItem({required this.event});

  final WorkspaceTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              _formatDate(event.occurredAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(
              Icons.circle,
              size: 8,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.typeLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(event.text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
'''
new_item = r'''class _WorkspaceTimelineList extends StatelessWidget {
  const _WorkspaceTimelineList({required this.events});

  final Iterable<WorkspaceTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<WorkspaceTimelineEvent>>{};
    final dates = <String, DateTime>{};
    for (final event in events) {
      final key =
          '${event.occurredAt.year}-${event.occurredAt.month}-${event.occurredAt.day}';
      groups.putIfAbsent(key, () => <WorkspaceTimelineEvent>[]).add(event);
      dates.putIfAbsent(key, () => event.occurredAt);
    }
    final entries = groups.entries.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? AppSpacing.xs : AppSpacing.md,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              _formatTimelineDay(dates[entries[index].key]!),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final event in entries[index].value)
            _WorkspaceTimelineItem(event: event),
          if (index < entries.length - 1) const Divider(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _WorkspaceTimelineItem extends StatelessWidget {
  const _WorkspaceTimelineItem({required this.event});

  final WorkspaceTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              _formatTimelineTime(event.occurredAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(
              Icons.circle,
              size: 8,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.typeLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(event.text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTimelineDay(DateTime value) {
  const weekdays = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return '${value.month}月${value.day}日 · ${weekdays[value.weekday - 1]}';
}

String _formatTimelineTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
'''
replace_once(workspace, old_item, new_item)

# Update the copy baseline so future work does not reintroduce technical English.
copy_replacements = {
    "| 学情 | Learning Case 与跟进入口 | 数据中心 |": "| 学情 | 问题与跟进入口 | 数据中心 |",
    "| Learning Case / 学情问题 | 可追踪的问题闭环 | 工单、风险卡 |": "| 跟进问题 | 可持续记录和跟进的学习问题 | 工单、风险卡 |",
    "| Evidence / 证据 | 可观察事实或材料 | 智能洞察 |": "| 学生表现 / 观察记录 | 可观察事实或材料 | Evidence、智能洞察 |",
    "| Intervention / 教学动作 | 已做或计划做的教学动作 | 赋能方案 |": "| 教学处理 | 教师实际采用的方法 | Intervention、赋能方案 |",
    "| Assessment / Verification | 一次检查及其结果/确认 | 成长指数 |": "| 检查结果 | 一次检查及其结果 | Assessment、Verification、成长指数 |",
    "| Next Action / 下一行动 | 下一次具体要做的事 | 推荐任务 |": "| 下一步 / 提醒 | 下一次具体要做的事 | Next Action、推荐任务 |",
    "### Learning Case": "### 跟进问题",
    "| 证据段 | `Evidence / 证据` |": "| 学生表现段 | `学生表现` |",
    "| 动作段 | `Intervention / 教学动作` |": "| 教学处理段 | `教学处理` |",
    "| 检查段 | `Assessment / Verification` |": "| 检查段 | `检查结果` |",
    "| 下一行动段 | `Next Action / 下一行动` |": "| 下一步段 | `下一步 / 提醒` |",
    "| 加证据 | `补充证据` |": "| 加学生表现 | `补充学生表现` |",
    "| 加动作 | `记录教学动作` |": "| 加教学处理 | `记录教学处理` |",
    "| 加检查 | `记录一次检查` |": "| 加检查 | `记录检查结果` |",
}
for old, new in copy_replacements.items():
    replace_all_checked(ux_copy, old, new)

# One-shot execution must not leave its own machinery in the product branch.
Path("tool/apply_readable_history_export_patch.py").unlink()
Path(".github/workflows/one-shot-readable-history-export.yml").unlink()
