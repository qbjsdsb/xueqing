from pathlib import Path
import re


def read(path):
    return Path(path).read_text(encoding='utf-8')


def write(path, text):
    Path(path).write_text(text, encoding='utf-8')


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


workspace_path = 'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart'
workspace = read(workspace_path)

workspace = replace_once(
    workspace,
    "  bool _showAllPendingVerification = false;\n  bool _showAllNewCases = false;\n  bool _showAllFutureActions = false;",
    "  bool _showAllPendingVerification = false;\n  bool _showAllFutureActions = false;",
    'remove Today new-case expansion state',
)
workspace = replace_once(
    workspace,
    "    final pendingVerification = <WorkspaceCaseWithContext>[];\n    final newCases = <WorkspaceCaseWithContext>[];",
    "    final pendingVerification = <WorkspaceCaseWithContext>[];",
    'remove Today new-case collection',
)
workspace = replace_once(
    workspace,
    "        if (learningCase.status == LearningCaseStatus.newCase &&\n            learningCase.primaryAction == null) {\n          newCases.add(\n            WorkspaceCaseWithContext(\n              student: student,\n              learningCase: learningCase,\n            ),\n          );\n          continue;\n        }",
    "        if (learningCase.status == LearningCaseStatus.newCase &&\n            learningCase.primaryAction == null) {\n          // A newly recorded fact is not a task. It remains on the student's\n          // growth record until the teacher explicitly creates a reminder.\n          continue;\n        }",
    'make new record non-task',
)
workspace = replace_once(
    workspace,
    "    final hasImmediateWork =\n        hasScheduledWork ||\n        pendingVerification.isNotEmpty ||\n        newCases.isNotEmpty ||\n        undated.isNotEmpty;\n    final hasBlockBeforeFuture =\n        hasScheduledWork ||\n        !hasImmediateWork ||\n        pendingVerification.isNotEmpty ||\n        newCases.isNotEmpty;",
    "    final hasImmediateWork =\n        hasScheduledWork ||\n        pendingVerification.isNotEmpty ||\n        undated.isNotEmpty;\n    final hasBlockBeforeFuture =\n        hasScheduledWork ||\n        !hasImmediateWork ||\n        pendingVerification.isNotEmpty;",
    'remove new records from Today work state',
)
pattern = re.compile(
    r"\n        if \(newCases\.isNotEmpty\) \.\.\.\[.*?\n        \],\n        if \(future\.isNotEmpty\)",
    re.S,
)
workspace, count = pattern.subn("\n        if (future.isNotEmpty)", workspace, count=1)
if count != 1:
    raise RuntimeError(f'remove Today 待整理 section: expected 1 match, found {count}')

workspace = replace_once(
    workspace,
    "  late final TextEditingController _titleController;\n  late final TextEditingController _evidenceController;\n  late final FocusNode _titleFocusNode;",
    "  late final TextEditingController _titleController;\n  late final FocusNode _titleFocusNode;",
    'quick capture controllers',
)
workspace = replace_once(
    workspace,
    "  String? _studentError;\n  String? _titleError;\n  String? _evidenceError;\n  String? _attachmentError;\n  String? _saveError;\n  bool _saving = false;\n  PickedEvidenceAttachment? _selectedAttachment;\n\n  bool get _isDirty =>\n      _titleController.text.trim().isNotEmpty ||\n      _evidenceController.text.trim().isNotEmpty ||\n      _selectedAttachment != null;",
    "  String? _studentError;\n  String? _titleError;\n  String? _attachmentError;\n  String? _saveError;\n  bool _saving = false;\n  bool _showMoreOptions = false;\n  PickedEvidenceAttachment? _selectedAttachment;\n\n  bool get _isDirty =>\n      _titleController.text.trim().isNotEmpty ||\n      _selectedAttachment != null ||\n      _selectedCaseTypeKey != WorkspaceCaseType.builtInTypes.last.key;",
    'quick capture state',
)
workspace = replace_once(
    workspace,
    "    _selectedStudent = widget.initialStudent;\n    _operationId = createOperationId();\n    _titleController = TextEditingController();\n    _evidenceController = TextEditingController();\n    _titleFocusNode = FocusNode();\n    _titleController.addListener(_clearInlineErrors);\n    _evidenceController.addListener(_clearInlineErrors);",
    "    _selectedStudent = widget.initialStudent ??\n        (widget.students.length == 1 ? widget.students.first : null);\n    _operationId = createOperationId();\n    _titleController = TextEditingController();\n    _titleFocusNode = FocusNode();\n    _titleController.addListener(_clearInlineErrors);",
    'quick capture init',
)
workspace = replace_once(
    workspace,
    "    _titleController\n      ..removeListener(_clearInlineErrors)\n      ..dispose();\n    _evidenceController\n      ..removeListener(_clearInlineErrors)\n      ..dispose();\n    _titleFocusNode.dispose();",
    "    _titleController\n      ..removeListener(_clearInlineErrors)\n      ..dispose();\n    _titleFocusNode.dispose();",
    'quick capture dispose',
)
workspace = replace_once(
    workspace,
    "    if ((_titleError != null && _titleController.text.trim().isNotEmpty) ||\n        (_evidenceError != null &&\n            _evidenceController.text.trim().isNotEmpty) ||\n        _attachmentError != null) {\n      setState(() {\n        if (_titleController.text.trim().isNotEmpty) {\n          _titleError = null;\n        }\n        if (_evidenceController.text.trim().isNotEmpty) {\n          _evidenceError = null;\n        }\n        _attachmentError = null;\n      });\n    }",
    "    if ((_titleError != null && _titleController.text.trim().isNotEmpty) ||\n        _attachmentError != null) {\n      setState(() {\n        if (_titleController.text.trim().isNotEmpty) {\n          _titleError = null;\n        }\n        _attachmentError = null;\n      });\n    }",
    'quick capture inline errors',
)
workspace = replace_once(
    workspace,
    "      if (attachment != null && mounted) {\n        setState(() => _selectedAttachment = attachment);\n      }",
    "      if (attachment != null && mounted) {\n        setState(() {\n          _selectedAttachment = attachment;\n          _showMoreOptions = true;\n        });\n      }",
    'restore attachment expands options',
)

save_start = workspace.index("  Future<void> _save() async {", workspace.index("class _WorkspaceQuickCaptureFormState"))
student_marker = "    final student = _selectedStudent!;"
student_pos = workspace.index(student_marker, save_start)
new_save_prefix = """  String _deriveQuickCaptureTitle(String note) {
    final normalized = note.replaceAll(RegExp(r'\\s+'), ' ').trim();
    final punctuationIndex = normalized.indexOf(RegExp(r'[。！？!?；;]'));
    var candidate = punctuationIndex > 0
        ? normalized.substring(0, punctuationIndex)
        : normalized;
    const maxTitleLength = 48;
    if (candidate.length > maxTitleLength) {
      candidate = '${candidate.substring(0, maxTitleLength)}…';
    }
    return candidate;
  }

  Future<void> _save() async {
    var valid = true;
    if (_selectedStudent == null) {
      _studentError = '请选择学生';
      valid = false;
    }
    final note = _titleController.text.trim();
    if (note.isEmpty) {
      _titleError = '请写下今天看到的情况';
      valid = false;
    }
    if (!valid) {
      setState(() {});
      return;
    }

"""
workspace = workspace[:save_start] + new_save_prefix + workspace[student_pos:]
workspace = replace_once(
    workspace,
    "          title: _titleController.text.trim(),\n          description: _evidenceController.text.trim(),\n          observedAt: DateTime.now(),\n          evidenceSummary: _evidenceController.text.trim(),",
    "          title: _deriveQuickCaptureTitle(note),\n          description: note,\n          observedAt: DateTime.now(),\n          evidenceSummary: note,",
    'quick capture command uses one note',
)

build_start = workspace.index("                  _buildStudentField(context),", workspace.index("class _WorkspaceQuickCaptureFormState"))
build_end = workspace.index("                  if (_saveError != null) ...[", build_start)
new_capture_fields = """                  if (widget.initialStudent != null)
                    _WorkspaceContextLine(
                      label: '学生',
                      value: [
                        widget.initialStudent!.name,
                        widget.initialStudent!.subject,
                      ].join(' · '),
                    )
                  else
                    _buildStudentField(context),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('quick-capture-title-field'),
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    autofocus: _selectedStudent != null,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 7,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: '今天发现什么？ *',
                      hintText: '例如：阅读题经常漏看限制词。今天连续两题都没注意“不正确的是”。',
                      errorText: _titleError,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '一句话也可以。保存后只进入学生记录，不会自动生成待办。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('quick-capture-more-options'),
                      onPressed: _saving
                          ? null
                          : () => setState(
                              () => _showMoreOptions = !_showMoreOptions,
                            ),
                      icon: Icon(
                        _showMoreOptions
                            ? Icons.expand_less
                            : Icons.tune_outlined,
                      ),
                      label: Text(_showMoreOptions ? '收起更多选项' : '更多选项'),
                    ),
                  ),
                  if (_showMoreOptions) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _buildCaseTypeField(context),
                    if (widget.evidenceAttachmentRepository != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _buildAttachmentField(context),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.md),
                  const _WorkspaceContextLine(
                    label: '保存后',
                    value: '进入学生成长记录，不自动生成待办；需要提醒时再设置。',
                  ),
"""
workspace = workspace[:build_start] + new_capture_fields + workspace[build_end:]
workspace = workspace.replace(
    "                    '先记下刚看到的问题和具体表现，课后再补充判断与跟进。',",
    "                    '先把刚看到的情况记下来。分类、图片和后续提醒都可以以后再补。',",
    1,
)
workspace = workspace.replace(
    "            '可以补一张题目、作业或课堂照片；仍建议写一句文字，之后更容易查找。',",
    "            '图片只用于补充现场信息；主要记录仍以刚才那句话为准。',",
    1,
)
write(workspace_path, workspace)

progress_path = 'lib/features/teacher_workspace/presentation/progressive_case_forms.dart'
progress = read(progress_path)
progress = replace_once(
    progress,
    "  bool _saving = false;\n  bool _submissionAttempted = false;\n  RecordCaseProgressCommand? _submittedCommand;",
    "  bool _saving = false;\n  bool _submissionAttempted = false;\n  bool _showRecordOptions = false;\n  bool _showNextStepOptions = false;\n  RecordCaseProgressCommand? _submittedCommand;",
    'progress disclosure state',
)
progress = replace_once(
    progress,
    "    CaseProgressKind.observation => '这次看到了什么？ *',\n    CaseProgressKind.intervention => '这次怎么处理的？ *',\n    CaseProgressKind.assessment => '这次检查结果怎么样？ *',",
    "    CaseProgressKind.observation => '这次有什么新情况？ *',\n    CaseProgressKind.intervention => '这次怎么处理的？ *',\n    CaseProgressKind.assessment => '补充说明（可选）',",
    'progress summary labels',
)
progress = replace_once(
    progress,
    "    if (summary.isEmpty) {\n      _summaryError = '请写下这次实际发生的情况';\n      valid = false;\n    }",
    "    if (summary.isEmpty && _kind != CaseProgressKind.assessment) {\n      _summaryError = '请写下这次实际发生的情况';\n      valid = false;\n    }",
    'assessment summary optional',
)
progress = replace_once(
    progress,
    "    final action = widget.currentAction;\n    return RecordCaseProgressCommand(",
    "    final effectiveSummary =\n        summary.isEmpty && _kind == CaseProgressKind.assessment\n        ? '检查结果：${_assessmentResult.label}'\n        : summary;\n    final action = widget.currentAction;\n    return RecordCaseProgressCommand(",
    'derive assessment summary',
)
progress = replace_once(
    progress,
    "      summary: summary,",
    "      summary: effectiveSummary,",
    'use effective progress summary',
)
progress = progress.replace(
    "                    '只记这次真实发生了什么；要不要提醒下一步，由你决定。',",
    "                    '先写下这次真实发生了什么。分类、提醒和结束跟进都按需要再选。',",
    1,
)

start_marker = "                  const SizedBox(height: AppSpacing.md),\n                  Text('这次记录什么'"
start = progress.index(start_marker)
end_marker = "                  if (_nextStep == CaseProgressNextStep.remind) ...["
end = progress.index(end_marker, start)
new_progress_controls = """                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('progress-summary'),
                    controller: _summaryController,
                    autofocus: true,
                    enabled: !_inputsLocked,
                    minLines: 3,
                    maxLines: 7,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: _summaryLabel,
                      hintText: _summaryHint,
                      errorText: _summaryError,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('progress-record-options-toggle'),
                      onPressed: _inputsLocked
                          ? null
                          : () => setState(
                              () => _showRecordOptions = !_showRecordOptions,
                            ),
                      icon: Icon(
                        _showRecordOptions
                            ? Icons.expand_less
                            : Icons.label_outline,
                      ),
                      label: Text(
                        _showRecordOptions ? '收起记录方式' : '补充记录方式（可选）',
                      ),
                    ),
                  ),
                  if (_showRecordOptions) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final kind in CaseProgressKind.values)
                          ChoiceChip(
                            key: ValueKey<String>(
                              'progress-kind-${kind.wireValue}',
                            ),
                            label: Text(kind.label),
                            selected: _kind == kind,
                            onSelected: _inputsLocked
                                ? null
                                : (_) => setState(() {
                                    _kind = kind;
                                    _summaryError = null;
                                  }),
                          ),
                      ],
                    ),
                  ],
                  if (_kind == CaseProgressKind.assessment) ...[
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<CaseAssessmentResult>(
                      key: const Key('progress-assessment-result'),
                      initialValue: _assessmentResult,
                      decoration: const InputDecoration(labelText: '检查结果 *'),
                      items: [
                        for (final result in CaseAssessmentResult.values)
                          DropdownMenuItem<CaseAssessmentResult>(
                            value: result,
                            child: Text(result.label),
                          ),
                      ],
                      onChanged: _inputsLocked
                          ? null
                          : (result) {
                              if (result != null) {
                                setState(() => _assessmentResult = result);
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '只选检查结果也可以保存；需要时再补一句说明。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('progress-next-options-toggle'),
                      onPressed: _inputsLocked
                          ? null
                          : () => setState(
                              () => _showNextStepOptions = !_showNextStepOptions,
                            ),
                      icon: Icon(
                        _showNextStepOptions
                            ? Icons.expand_less
                            : Icons.notifications_none_outlined,
                      ),
                      label: Text(
                        _showNextStepOptions
                            ? '收起后续选项'
                            : '需要提醒或结束跟进？',
                      ),
                    ),
                  ),
                  if (_showNextStepOptions) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final step in CaseProgressNextStep.values)
                          ChoiceChip(
                            key: ValueKey<String>(
                              'progress-next-${step.wireValue}',
                            ),
                            label: Text(step.label),
                            selected: _nextStep == step,
                            onSelected: _inputsLocked
                                ? null
                                : (_) => setState(() {
                                    _nextStep = step;
                                    _reminderError = null;
                                  }),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(switch (_nextStep) {
                      CaseProgressNextStep.continueTracking =>
                        '默认不生成待办；之后有新情况再记录。',
                      CaseProgressNextStep.remind =>
                        '只有确实需要提醒自己时才生成一条待办。',
                      CaseProgressNextStep.close =>
                        '结束当前跟进，完整历史仍然保留。',
                    }, style: Theme.of(context).textTheme.bodySmall),
                  ],
"""
progress = progress[:start] + new_progress_controls + progress[end:]
progress = progress.replace(
    "                                    CaseProgressNextStep.continueTracking =>\n                                      '保存进展',",
    "                                    CaseProgressNextStep.continueTracking =>\n                                      '保存记录',",
    1,
)
write(progress_path, progress)

learning_path = 'lib/cloud/learning_repository.dart'
learning = read(learning_path)
learning = learning.replace("    LearningCaseStatus.newCase => '待整理',", "    LearningCaseStatus.newCase => '新记录',", 1)
old_timeline = """        final problemTitle = _requiredString(row['title'], 'case_title');
        timeline.add(
          WorkspaceTimelineEvent(
            id: _requiredString(eventRow['id'], 'event_id'),
            occurredAt: _requiredDateTime(
              eventRow['occurred_at'],
              'event_occurred_at',
            ),
            typeLabel: '发现问题',
            text: initialEvidence == null
                ? problemTitle
                : '$problemTitle\\n具体表现：${initialEvidence.summary}',
          ),
        );
"""
new_timeline = """        final problemTitle = _requiredString(row['title'], 'case_title');
        final problemDescription = _stringValue(row['description'])?.trim();
        final initialSummary = initialEvidence?.summary.trim();
        timeline.add(
          WorkspaceTimelineEvent(
            id: _requiredString(eventRow['id'], 'event_id'),
            occurredAt: _requiredDateTime(
              eventRow['occurred_at'],
              'event_occurred_at',
            ),
            typeLabel: '发现问题',
            text: initialEvidence == null
                ? problemTitle
                : problemDescription != null &&
                      problemDescription.isNotEmpty &&
                      initialSummary == problemDescription
                ? problemDescription
                : '$problemTitle\\n学生表现：$initialSummary',
          ),
        );
"""
learning = replace_once(learning, old_timeline, new_timeline, 'single-note timeline presentation')
write(learning_path, learning)

export_path = 'lib/export/learning_record_export.dart'
export = read(export_path)
export = export.replace("      LearningCaseStatus.newCase => '待整理',", "      LearningCaseStatus.newCase => '新记录',", 1)
write(export_path, export)

print('Teacher friction reduction product changes applied.')
