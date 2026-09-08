from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing expected block: {label}')
    return text.replace(old, new, 1)


def sub_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'expected one regex block for {label}, got {count}')
    return updated

fixture_path = Path('lib/features/design_prototype/design_fixture.dart')
fixture = fixture_path.read_text(encoding='utf-8')
fixture_replacements = {
    "/// `pendingVerification` is deliberately not a value here: it is a Case-level\n/// bucket and therefore cannot be duplicated in an ordinary action bucket.":
        "/// Case status and Action due buckets are intentionally separate. A Case in\n/// any open status enters Today only when it actually has an explicit Action.",
    "statusLabel: '待验证',": "statusLabel: '继续关注',",
    "assessment: '本次验证通过，仍待确认是否稳定。',": "assessment: '本次检查达到预期，先保留记录并继续关注。',",
    "nextActionDue: '9 月 4 日',": "nextActionDue: '9 月 4 日',",
    "typeLabel: 'Assessment / Verification',\n              text: '本次验证通过，等待教师确认是否稳定。',":
        "typeLabel: '检查结果',\n              text: '本次检查达到预期；目前继续关注，不额外制造确认任务。',",
    "typeLabel: 'Evidence',": "typeLabel: '学生表现',",
    "typeLabel: 'Intervention',": "typeLabel: '教学处理',",
    "title: '确认是否稳定',\n            dueLabel: '今天到期',\n            kind: PrototypeActionKind.verification,\n            dueBucket: PrototypeActionDueBucket.today,\n            dueDate: previewDate,":
        "title: '再做两道迁移题并核对过程',\n            dueLabel: '9 月 4 日',\n            kind: PrototypeActionKind.verification,\n            dueBucket: PrototypeActionDueBucket.future,\n            dueDate: DateTime(2026, 9, 4),",
    "statusLabel: '干预中',": "statusLabel: '跟进中',",
    "statusLabel: '待整理',": "statusLabel: '新记录',",
    "evidence: '课堂口头练习中出现一次选择犹豫，尚未补充题目记录。',":
        "evidence: '课堂口头练习中出现一次选择犹豫。',",
    "judgement: '尚未形成足够判断，需要补充一条具体题目证据。',":
        "judgement: '目前信息还少，先保留这条事实；以后有新情况再继续记录。',",
    "nextAction: '补充一条题目证据后再整理',\n          nextActionDue: '待安排',":
        "nextAction: '尚未设置提醒',\n          nextActionDue: '—',",
    "typeLabel: 'Quick Capture',\n              text: '课堂中先记录为待整理问题。',":
        "typeLabel: '发现问题',\n              text: '课堂中记录一条新情况。',",
    "          primaryAction: PrototypeAction(\n            id: 'demo-action-b1',\n            title: '补充一条题目证据后再整理',\n            dueLabel: '待安排',\n            kind: PrototypeActionKind.evidence,\n            dueBucket: PrototypeActionDueBucket.undated,\n          ),\n": "",
    "typeLabel: '课堂记录',\n          text: '新增一条待整理问题，尚未安排日期。',":
        "typeLabel: '发现问题',\n          text: '记录一条新情况；目前没有设置提醒。',",
}
for old, new in fixture_replacements.items():
    fixture = replace_once(fixture, old, new, old[:50])
# Remaining intervening fixture labels.
fixture = fixture.replace("statusLabel: '干预中',", "statusLabel: '跟进中',")
fixture = fixture.replace("typeLabel: 'Intervention',", "typeLabel: '教学处理',")
fixture = fixture.replace("typeLabel: 'Evidence',", "typeLabel: '学生表现',")
fixture_path.write_text(fixture, encoding='utf-8')

page_path = Path('lib/features/design_prototype/presentation/design_prototype_page.dart')
page = page_path.read_text(encoding='utf-8')
page = replace_once(
    page,
    "ScaffoldMessenger.of(context)\n          .showSnackBar(const SnackBar(content: Text('已记录为待整理问题，并已显示在当前预览。')));",
    "ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('已记录到学生成长记录，并已显示在当前预览。')),\n      );",
    'quick capture success copy',
)

page = sub_once(
    page,
    r"  void _addQuickCapture\(PrototypeQuickCapture capture\) \{.*?\n  \}\n\n  void _addPreviewDraft",
    '''  void _addQuickCapture(PrototypeQuickCapture capture) {
    final studentId = capture.studentId;
    if (studentId == null) return;

    final studentIndex = _students.indexWhere(
      (student) => student.id == studentId,
    );
    if (studentIndex < 0) return;

    final student = _students[studentIndex];
    final now = DateTime.now();
    final event = PrototypeTimelineEvent(
      dateLabel: _previewDateLabel(now),
      typeLabel: '发现问题',
      text: capture.note,
    );
    final caseNumber = ++_localCaptureSerial;
    final learningCase = PrototypeCase(
      id: 'preview-case-$caseNumber',
      title: capture.title,
      status: PrototypeCaseStatus.newCase,
      statusLabel: '新记录',
      priorityLabel: '新记录',
      subject: student.subject,
      problem: capture.title,
      evidence: capture.note,
      judgement: '尚未形成教师判断。',
      intervention: '尚未记录。',
      assessment: '尚未记录。',
      nextAction: '尚未设置提醒',
      nextActionDue: '—',
      timeline: <PrototypeTimelineEvent>[event],
    );
    final updatedStudent = PrototypeStudent(
      id: student.id,
      name: student.name,
      grade: student.grade,
      subject: student.subject,
      context: student.context,
      cases: <PrototypeCase>[learningCase, ...student.cases],
      recentFacts: <PrototypeTimelineEvent>[event, ...student.recentFacts],
    );

    setState(() {
      _students[studentIndex] = updatedStudent;
      if (_selectedStudent?.id == student.id) {
        _selectedStudent = updatedStudent;
      }
    });
  }

  void _addPreviewDraft''',
    'add quick capture',
)

page = sub_once(
    page,
    r"  Widget _buildPreviewDraftSection\(\{String\? studentId\}\) \{.*?\n  \}\n\n  Widget _buildCurrentPage",
    '''  Widget _buildPreviewDraftSection({String? studentId}) {
    final drafts = _previewDrafts
        .where((draft) => studentId == null || draft.studentId == studentId)
        .toList();
    if (drafts.isEmpty) return const SizedBox.shrink();

    return DesignSection(
      title: '本次预览会话草稿',
      count: '${drafts.length} 条',
      showTopDivider: true,
      child: Column(
        children: [
          for (final draft in drafts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(draft.note.isEmpty ? '未填写内容' : draft.note),
              subtitle: const Text('仅本次预览会话保留'),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentPage''',
    'preview draft section',
)

page = sub_once(
    page,
    r"  Widget _buildToday\(BuildContext context\) \{.*?\n  \}\n\n  List<_ActionWithContext> _actionsInBucket",
    '''  Widget _buildToday(BuildContext context) {
    final actions = <_ActionWithContext>[];
    for (final student in _students) {
      for (final learningCase in student.cases) {
        final action = learningCase.primaryAction;
        if (action == null ||
            _completedActionIds.contains(action.id) ||
            learningCase.status == PrototypeCaseStatus.closed) {
          continue;
        }
        actions.add(
          _ActionWithContext(
            student: student,
            learningCase: learningCase,
            action: action,
          ),
        );
      }
    }

    final overdue = _actionsInBucket(
      actions,
      PrototypeActionDueBucket.overdue,
    );
    final dueToday = _actionsInBucket(
      actions,
      PrototypeActionDueBucket.today,
    );
    final future = _actionsInBucket(
      actions,
      PrototypeActionDueBucket.future,
    );
    final undated = _actionsInBucket(
      actions,
      PrototypeActionDueBucket.undated,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DesignPreviewBanner(),
        const SizedBox(height: AppSpacing.lg),
        DesignPageHeader(
          title: '今日',
          subtitle: '只放已经明确安排的事；普通记录安静留在学生成长历史里。',
          actions: [
            FilledButton.icon(
              key: const Key('design-preview-today-record-question'),
              onPressed: () => _showQuickCapture(),
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('记录问题'),
            ),
          ],
        ),
        _buildPreviewDraftSection(),
        if (overdue.isNotEmpty || dueToday.isNotEmpty) ...[
          DesignSection(
            key: const Key('today-work-section'),
            title: '今天的工作',
            count: '${overdue.length + dueToday.length} 项',
            child: Column(
              children: [
                if (overdue.isNotEmpty) ...[
                  _ActionSubheading(
                    label: '已逾期',
                    color: Theme.of(context).colorScheme.error,
                    icon: Icons.warning_amber_outlined,
                  ),
                  ..._buildActionGroups(overdue),
                ],
                if (dueToday.isNotEmpty) ...[
                  if (overdue.isNotEmpty) const Divider(height: AppSpacing.lg),
                  _ActionSubheading(
                    label: '今天到期',
                    color: Theme.of(context).colorScheme.secondary,
                    icon: Icons.today_outlined,
                  ),
                  ..._buildActionGroups(dueToday),
                ],
              ],
            ),
          ),
        ] else
          const DesignStateNotice(
            title: '今天暂时没有需要处理的事项',
            message: '可以回看最近学生，或在课堂中随手记下一条新情况。',
            icon: Icons.check_circle_outline,
          ),
        if (future.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          DesignSection(
            key: const Key('future-actions-section'),
            title: '之后要处理',
            count: '${future.length} 项',
            showTopDivider: true,
            child: Column(children: _buildActionGroups(future)),
          ),
        ],
        if (undated.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          DesignSection(
            key: const Key('undated-actions-section'),
            title: '待安排',
            count: '${undated.length} 项',
            showTopDivider: true,
            child: Column(children: _buildActionGroups(undated)),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        DesignSection(
          title: '最近学生',
          showTopDivider: true,
          action: TextButton(
            onPressed: () => _selectDestination(1),
            child: const Text('查看全部'),
          ),
          child: Column(
            children: [
              for (final student in _students)
                DesignStudentRow(
                  student: student,
                  onOpen: () => _openStudent(student),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<_ActionWithContext> _actionsInBucket''',
    'today',
)

page = page.replace(
    "DesignPageHeader(\n          title: '学情',\n          subtitle: '按 Case 查看问题、证据、教学动作和下一行动。',",
    "DesignPageHeader(\n          title: '学情',\n          subtitle: '查看学生问题和连续成长记录，需要时再安排提醒。',",
    1,
)
page = page.replace("title: '当前 Learning Cases',", "title: '全部问题',", 1)

page = sub_once(
    page,
    r"  Widget _buildStudentDetail\(.*?\n  \}\n\n  Widget _buildCaseDetail",
    '''  Widget _buildStudentDetail(
    BuildContext context,
    PrototypeStudent student,
    WindowSizeClass sizeClass,
  ) {
    final importantCases = student.cases
        .where((item) => item.status != PrototypeCaseStatus.closed)
        .take(3)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesignPageHeader(
          title: student.name,
          subtitle: '${student.grade} · ${student.subject} · ${student.context}',
          leading: IconButton(
            tooltip: '返回',
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            FilledButton.icon(
              onPressed: () => _showQuickCapture(student: student),
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('记录问题'),
            ),
          ],
        ),
        DesignStateNotice(
          title: '学科上下文',
          message: '当前仅展示 ${student.subject} 的设计预览资料。真实版本会按权限和负责范围显示。',
          icon: Icons.menu_book_outlined,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (importantCases.isEmpty)
          const DesignStateNotice(
            title: '还没有需要跟进的问题',
            message: '发现情况时，可以先记下来；以后有新情况再继续记录。',
            icon: Icons.inbox_outlined,
          )
        else
          DesignSection(
            title: '现在最重要的事',
            count: '${importantCases.length} 项',
            child: Column(
              children: [
                for (final learningCase in importantCases)
                  DesignCaseRow(
                    student: student,
                    learningCase: learningCase,
                    onOpen: () => _openCase(learningCase),
                    onPrimaryAction: _casePrimaryAction(learningCase),
                    primaryActionLabel: _casePrimaryLabel(learningCase),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        DesignSection(
          title: '全部问题',
          count: '${student.cases.length} 个',
          showTopDivider: true,
          child: student.cases.isEmpty
              ? const DesignStateNotice(
                  title: '还没有问题记录',
                  message: '发现情况时，可以从这里开始记录。',
                  icon: Icons.inbox_outlined,
                )
              : Column(
                  children: [
                    for (final learningCase in student.cases)
                      DesignCaseRow(
                        student: student,
                        learningCase: learningCase,
                        onOpen: () => _openCase(learningCase),
                        onPrimaryAction: _casePrimaryAction(learningCase),
                        primaryActionLabel: _casePrimaryLabel(learningCase),
                      ),
                  ],
                ),
        ),
        _buildPreviewDraftSection(studentId: student.id),
        const SizedBox(height: AppSpacing.lg),
        _DetailFacts(student: student, sizeClass: sizeClass),
      ],
    );
  }

  Widget _buildCaseDetail''',
    'student detail',
)

page = sub_once(
    page,
    r"  Widget _buildCaseDetail\(.*?\n  \}\n\n  bool _isCaseStateCommand",
    '''  Widget _buildCaseDetail(
    BuildContext context,
    PrototypeStudent student,
    PrototypeCase learningCase,
  ) {
    final hasReminder = learningCase.primaryAction != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesignPageHeader(
          title: learningCase.title,
          subtitle: '${student.name} · ${learningCase.subject}',
          leading: IconButton(
            tooltip: '返回学生详情',
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            DesignStatusMarker(label: learningCase.statusLabel),
            FilledButton(
              onPressed: _casePrimaryAction(learningCase),
              child: Text(_casePrimaryLabel(learningCase)),
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            DesignMetadata(learningCase.priorityLabel),
            DesignMetadata(
              hasReminder
                  ? '当前提醒：${learningCase.nextAction}'
                  : '当前没有设置提醒',
            ),
            if (hasReminder)
              DesignMetadata(
                learningCase.nextActionDue,
                icon: Icons.event_outlined,
              ),
          ],
        ),
        if (learningCase.status == PrototypeCaseStatus.pendingVerification) ...[
          const SizedBox(height: AppSpacing.lg),
          const DesignStateNotice(
            title: '这次检查已经记录',
            message: '之后有新情况继续记录；只有确实需要某天提醒自己时，才设置提醒。',
            icon: Icons.fact_check_outlined,
          ),
        ] else if (learningCase.status == PrototypeCaseStatus.stable) ...[
          const SizedBox(height: AppSpacing.lg),
          const DesignStateNotice(
            title: '当前表现暂时稳定',
            message: '记录会继续保留；没有新的教学需要时，不自动生成复查任务。',
            icon: Icons.check_circle_outline,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _CaseNarrativeSection(
          title: '问题',
          content: learningCase.problem,
          actionLabel: '补充问题说明',
          onAction: () => _showPrototypeNotice('补充问题说明'),
        ),
        _CaseNarrativeSection(
          title: '学生表现',
          content: learningCase.evidence,
          actionLabel: '补充学生表现',
          onAction: () => _showPrototypeNotice('补充学生表现'),
        ),
        _CaseNarrativeSection(
          title: '教师判断',
          content: learningCase.judgement,
          actionLabel: '记录教师判断',
          onAction: () => _showPrototypeNotice('记录教师判断'),
        ),
        _CaseNarrativeSection(
          title: '教学处理',
          content: learningCase.intervention,
          actionLabel: '记录教学处理',
          onAction: () => _showPrototypeNotice('记录教学处理'),
        ),
        _CaseNarrativeSection(
          title: '检查结果',
          content: learningCase.assessment,
          actionLabel: '记录检查结果',
          onAction: () => _showPrototypeNotice('记录检查结果'),
        ),
        _CaseNarrativeSection(
          title: '当前提醒',
          content: hasReminder
              ? '${learningCase.nextAction}（${learningCase.nextActionDue}）'
              : '尚未设置提醒。需要时再设置，不影响问题记录继续保留。',
          actionLabel: hasReminder ? '调整提醒' : '设置提醒',
          onAction: () => _showPrototypeNotice(hasReminder ? '调整提醒' : '设置提醒'),
          isPrimary: hasReminder,
        ),
        DesignSection(
          title: '最近记录',
          showTopDivider: true,
          child: Column(
            children: [
              for (final event in learningCase.timeline)
                DesignTimelineItem(event: event),
            ],
          ),
        ),
      ],
    );
  }

  bool _isCaseStateCommand''',
    'case detail',
)

page = sub_once(
    page,
    r"  bool _isCaseStateCommand\(PrototypeCase learningCase\) \{.*?\n  String _casePrimaryLabel\(PrototypeCase learningCase\) \{.*?\n  \}\n",
    '''  VoidCallback _casePrimaryAction(PrototypeCase learningCase) {
    if (learningCase.status == PrototypeCaseStatus.closed) {
      return () => _showPrototypeNotice('重新跟进');
    }
    if (learningCase.primaryAction != null) {
      return () => _showPrototypeNotice('处理');
    }
    return () => _showPrototypeNotice('记录进展');
  }

  void _showPrototypeNotice(String actionLabel) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$actionLabel 入口已定义；当前预览不会写入业务数据。')));
  }

  String _casePrimaryLabel(PrototypeCase learningCase) {
    if (learningCase.status == PrototypeCaseStatus.closed) {
      return '重新跟进';
    }
    return learningCase.primaryAction == null ? '记录进展' : '处理';
  }
''',
    'case primary helpers',
)

# Processing an Action in design preview should demonstrate the entry, not fake completion.
page = sub_once(
    page,
    r"  void _completeAction\(PrototypeAction action\) \{.*?\n  \}\n",
    '''  void _completeAction(PrototypeAction action) {
    _showPrototypeNotice('处理“${action.title}”');
  }
''',
    'complete action preview',
)

page = sub_once(
    page,
    r"class _DesignQuickCaptureFormState extends State<DesignQuickCaptureForm> \{.*?\n\}\n\nclass _ContextField",
    '''class _DesignQuickCaptureFormState extends State<DesignQuickCaptureForm> {
  late final TextEditingController _noteController;
  late final FocusNode _noteFocusNode;
  PrototypeStudent? _selectedStudent;
  bool _saving = false;
  String? _studentError;
  String? _noteError;

  bool get _isDirty => _noteController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selectedStudent = widget.student ??
        (widget.students.length == 1 ? widget.students.first : null);
    _noteController = TextEditingController()..addListener(_onTextChanged);
    _noteFocusNode = FocusNode(debugLabel: '设计预览快速记录');
  }

  @override
  void dispose() {
    _noteController
      ..removeListener(_onTextChanged)
      ..dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_noteError != null && _noteController.text.trim().isNotEmpty) {
      setState(() => _noteError = null);
    }
  }

  String _deriveTitle(String note) {
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
    if (_selectedStudent == null) {
      setState(() => _studentError = '请选择学生');
      return;
    }
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      setState(() => _noteError = '请写下今天看到的情况');
      return;
    }
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    Navigator.of(context).pop(
      QuickCaptureResult.saved(
        PrototypeQuickCapture(
          studentId: _selectedStudent!.id,
          title: _deriveTitle(note),
          note: note,
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    if (!_isDirty && !_saving) {
      Navigator.of(context).pop();
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('暂存这段记录？'),
        content: const Text('这段内容还没有保存为正式预览记录。暂存后只保留在本次预览会话中。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('放弃记录'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('暂存草稿'),
          ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      result
          ? QuickCaptureResult.draft(
              PrototypeQuickCapture(
                studentId: _selectedStudent?.id,
                title: note.isEmpty ? '' : _deriveTitle(note),
                note: note,
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope<void>(
      canPop: !_isDirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) unawaited(_cancel());
      },
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '记录问题',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: _saving ? null : _cancel,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '先把刚看到的情况记下来；没有明确提醒，就不会自动变成待办。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (widget.student != null)
                    _ContextField(
                      label: '学生',
                      value: '${widget.student!.name} · ${widget.student!.subject}',
                    )
                  else
                    DropdownButtonFormField<PrototypeStudent>(
                      initialValue: _selectedStudent,
                      decoration: InputDecoration(
                        labelText: '学生 *',
                        errorText: _studentError,
                      ),
                      hint: const Text('选择学生后开始'),
                      items: [
                        for (final student in widget.students)
                          DropdownMenuItem<PrototypeStudent>(
                            value: student,
                            child: Text('${student.name} · ${student.subject}'),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (student) {
                              setState(() {
                                _selectedStudent = student;
                                _studentError = null;
                              });
                              if (student != null) {
                                _noteFocusNode.requestFocus();
                              }
                            },
                    ),
                  _ContextField(
                    label: '学科',
                    value: _selectedStudent?.subject ?? '尚未选择',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('design-preview-quick-capture-note'),
                    controller: _noteController,
                    focusNode: _noteFocusNode,
                    autofocus: _selectedStudent != null,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 7,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: '今天发现什么？ *',
                      hintText: '写下刚才真实看到的题目、行为或表现',
                      errorText: _noteError,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '一句话也可以。真实工作台里的分类、图片和提醒都按需展开。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_saving)
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text('保存中…'),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _cancel,
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          key: const Key('design-preview-quick-capture-save'),
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? '保存中…' : '记录问题'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContextField''',
    'quick capture form',
)
page_path.write_text(page, encoding='utf-8')

components_path = Path('lib/features/design_prototype/presentation/design_components.dart')
components = components_path.read_text(encoding='utf-8')
components = components.replace(
    "student.cases.isEmpty\n                        ? '还没有 Learning Case'\n                        : '${student.cases.length} 个当前 Learning Case',",
    "student.cases.isEmpty\n                        ? '暂无需要跟进的问题'\n                        : '${student.cases.length} 个问题记录',",
    1,
)
components = components.replace(
    "label: 'Case 信息：${student.name} · ${learningCase.title}',",
    "label: '问题信息：${student.name} · ${learningCase.title}',",
    1,
)
components = components.replace(
    "DesignMetadata('下一步：${learningCase.nextAction}'),",
    "DesignMetadata(\n                    learningCase.primaryAction == null\n                        ? '当前没有设置提醒'\n                        : '当前提醒：${learningCase.nextAction}',\n                  ),",
    1,
)
components = components.replace("child: const Text('查看 Case'),", "child: const Text('查看问题'),")
components = components.replace(
    "child: Text(primaryActionLabel ?? '处理下一步'),",
    "child: Text(primaryActionLabel ?? '记录进展'),",
    1,
)
components = components.replace(
    "FilledButton(onPressed: onComplete, child: const Text('完成'))",
    "FilledButton(onPressed: onComplete, child: const Text('处理'))",
    1,
)
components = components.replace(
    "  if (label.contains('验证')) {",
    "  if (label.contains('验证') || label.contains('关注')) {",
    1,
)
components_path.write_text(components, encoding='utf-8')
