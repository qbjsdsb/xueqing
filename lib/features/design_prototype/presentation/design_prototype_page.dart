import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/layout/responsive.dart';
import '../../../app/theme/app_spacing.dart';
import '../design_fixture.dart';
import 'design_components.dart';

class DesignPrototypePage extends StatefulWidget {
  const DesignPrototypePage({super.key});

  @override
  State<DesignPrototypePage> createState() => _DesignPrototypePageState();
}

class _DesignPrototypePageState extends State<DesignPrototypePage> {
  int _selectedIndex = 0;
  PrototypeStudent? _selectedStudent;
  PrototypeCase? _selectedCase;
  final Set<String> _completedActionIds = <String>{};
  final TextEditingController _studentSearchController =
      TextEditingController();
  final FocusNode _studentSearchFocusNode = FocusNode(debugLabel: '学生搜索');
  late final List<PrototypeStudent> _students;
  int _localCaptureSerial = 0;
  final List<PrototypeQuickCapture> _previewDrafts = <PrototypeQuickCapture>[];

  @override
  void initState() {
    super.initState();
    _students = [
      for (final student in DesignFixture.students)
        _copyPrototypeStudent(student),
    ];
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    _studentSearchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _selectedStudent == null && _selectedCase == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: _DesignShell(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectDestination,
        onFocusStudentSearch: _focusStudentSearch,
        child: ResponsiveLayout(
          builder: (context, sizeClass) {
            return _PageFrame(
              sizeClass: sizeClass,
              child: _buildCurrentPage(context, sizeClass),
            );
          },
        ),
      ),
    );
  }

  void _selectDestination(int index) {
    setState(() {
      _selectedIndex = index;
      _selectedStudent = null;
      _selectedCase = null;
    });
  }

  void _focusStudentSearch() {
    if (_selectedIndex != 1 ||
        _selectedStudent != null ||
        _selectedCase != null) {
      setState(() {
        _selectedIndex = 1;
        _selectedStudent = null;
        _selectedCase = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _studentSearchFocusNode.requestFocus();
      });
      return;
    }

    _studentSearchFocusNode.requestFocus();
  }

  void _openStudent(PrototypeStudent student) {
    setState(() {
      _selectedStudent = student;
      _selectedCase = null;
    });
  }

  void _openCase(PrototypeCase learningCase) {
    setState(() {
      _selectedStudent = _studentForCase(learningCase);
      _selectedCase = learningCase;
    });
  }

  void _goBack() {
    if (_selectedCase != null) {
      setState(() => _selectedCase = null);
      return;
    }
    if (_selectedStudent != null) {
      setState(() => _selectedStudent = null);
    }
  }

  Future<void> _showQuickCapture({PrototypeStudent? student}) async {
    final sizeClass = ResponsiveBreakpoints.classify(
      MediaQuery.sizeOf(context).width,
    );
    final result = sizeClass == WindowSizeClass.compact
        ? await showModalBottomSheet<QuickCaptureResult>(
            context: context,
            isScrollControlled: true,
            isDismissible: false,
            enableDrag: false,
            backgroundColor: Colors.transparent,
            builder: (context) => DesignQuickCaptureForm(
              students: List<PrototypeStudent>.of(_students),
              student: student,
            ),
          )
        : await showDialog<QuickCaptureResult>(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              child: DesignQuickCaptureForm(
                students: List<PrototypeStudent>.of(_students),
                student: student,
              ),
            ),
          );

    if (!mounted || result == null) return;
    if (result.outcome == QuickCaptureOutcome.saved && result.capture != null) {
      _addQuickCapture(result.capture!);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已记录到学生成长记录，并已显示在当前预览。')));
      return;
    }
    if (result.outcome == QuickCaptureOutcome.draft && result.capture != null) {
      _addPreviewDraft(result.capture!);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('草稿已保留在本次预览会话中。')));
    }
  }

  PrototypeStudent _studentForCase(PrototypeCase targetCase) {
    return _students.firstWhere(
      (student) => student.cases.any((item) => item.id == targetCase.id),
    );
  }

  void _addQuickCapture(PrototypeQuickCapture capture) {
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

  void _addPreviewDraft(PrototypeQuickCapture draft) {
    setState(() {
      _previewDrafts.insert(0, draft);
    });
  }

  void _completeAction(PrototypeAction action) {
    _showPrototypeNotice('处理“${action.title}”');
  }

  Widget _buildPreviewDraftSection({String? studentId}) {
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

  Widget _buildCurrentPage(BuildContext context, WindowSizeClass sizeClass) {
    if (_selectedCase != null && _selectedStudent != null) {
      return _buildCaseDetail(context, _selectedStudent!, _selectedCase!);
    }
    if (_selectedStudent != null) {
      return _buildStudentDetail(context, _selectedStudent!, sizeClass);
    }

    return switch (_selectedIndex) {
      0 => _buildToday(context),
      1 => _buildStudents(context),
      2 => _buildLessons(context),
      _ => _buildLearning(context),
    };
  }

  Widget _buildToday(BuildContext context) {
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

    final overdue = _actionsInBucket(actions, PrototypeActionDueBucket.overdue);
    final dueToday = _actionsInBucket(actions, PrototypeActionDueBucket.today);
    final future = _actionsInBucket(actions, PrototypeActionDueBucket.future);
    final undated = _actionsInBucket(actions, PrototypeActionDueBucket.undated);

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

  List<_ActionWithContext> _actionsInBucket(
    Iterable<_ActionWithContext> actions,
    PrototypeActionDueBucket bucket,
  ) {
    return actions.where((item) => item.action.dueBucket == bucket).toList();
  }

  List<Widget> _buildActionGroups(List<_ActionWithContext> items) {
    final grouped = <String, List<_ActionWithContext>>{};
    for (final item in items) {
      grouped
          .putIfAbsent(item.student.id, () => <_ActionWithContext>[])
          .add(item);
    }

    return [
      for (final group in grouped.values)
        _StudentActionGroup(
          student: group.first.student,
          items: group,
          completedActionIds: _completedActionIds,
          onOpenCase: _openCase,
          onComplete: _completeAction,
        ),
    ];
  }

  Widget _buildStudents(BuildContext context) {
    return AnimatedBuilder(
      animation: _studentSearchController,
      builder: (context, _) {
        final query = _studentSearchController.text.trim();
        final students = _students.where((student) {
          if (query.isEmpty) return true;
          final searchable = StringBuffer()
            ..write(student.name)
            ..write(student.subject)
            ..write(student.context);
          for (final learningCase in student.cases) {
            searchable
              ..write(learningCase.title)
              ..write(learningCase.problem)
              ..write(learningCase.evidence)
              ..write(learningCase.nextAction);
          }
          for (final draft in _previewDrafts) {
            if (draft.studentId == student.id) {
              searchable
                ..write(draft.title)
                ..write(draft.note);
            }
          }
          return searchable.toString().toLowerCase().contains(
            query.toLowerCase(),
          );
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DesignPreviewBanner(),
            const SizedBox(height: AppSpacing.lg),
            DesignPageHeader(
              title: '学生',
              subtitle: '搜索学生，先理解当前重点，再进入需要处理的 Case。',
              actions: [
                FilledButton.icon(
                  onPressed: () => _showQuickCapture(),
                  icon: Icon(Icons.edit_note_outlined),
                  label: const Text('记录问题'),
                ),
              ],
            ),
            _buildPreviewDraftSection(),
            TextField(
              controller: _studentSearchController,
              focusNode: _studentSearchFocusNode,
              decoration: const InputDecoration(
                labelText: '搜索学生或学情',
                hintText: '输入姓名、学科或问题关键词',
                prefixIcon: Icon(Icons.search),
              ),
              textInputAction: TextInputAction.search,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (students.isEmpty)
              const DesignStateNotice(
                title: '没有找到匹配的学生',
                message: '换一个姓名、学科或问题关键词试试。',
                icon: Icons.search_off_outlined,
              )
            else
              DesignSection(
                title: '最近学生',
                count: '${students.length} 人',
                child: Column(
                  children: [
                    for (final student in students)
                      DesignStudentRow(
                        student: student,
                        onOpen: () => _openStudent(student),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLessons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DesignPreviewBanner(),
        const SizedBox(height: AppSpacing.lg),
        DesignPageHeader(title: '课程', subtitle: '从一次教学进入记录，不负责排课、考勤或收费。'),
        _buildPreviewDraftSection(),
        DesignSection(
          title: '可以开始记录',
          child: Column(
            children: [
              for (final student in _students)
                _LessonRow(
                  student: student,
                  onStart: () => _openStudent(student),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const DesignStateNotice(
          title: '课程安排不在本阶段展开',
          message: '这里先验证进入一次教学记录的入口；排课和课时管理属于其他产品边界。',
          icon: Icons.info_outline,
        ),
      ],
    );
  }

  Widget _buildLearning(BuildContext context) {
    final cases = [
      for (final student in _students)
        for (final learningCase in student.cases)
          (student: student, learningCase: learningCase),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DesignPreviewBanner(),
        const SizedBox(height: AppSpacing.lg),
        DesignPageHeader(
          title: '学情',
          subtitle: '查看学生问题和连续成长记录，需要时再安排提醒。',
          actions: [
            FilledButton.icon(
              onPressed: () => _showQuickCapture(),
              icon: Icon(Icons.edit_note_outlined),
              label: const Text('记录问题'),
            ),
          ],
        ),
        _buildPreviewDraftSection(),
        DesignSection(
          title: '全部问题',
          count: '${cases.length} 个',
          child: Column(
            children: [
              for (final item in cases)
                DesignCaseRow(
                  student: item.student,
                  learningCase: item.learningCase,
                  onOpen: () => _openCase(item.learningCase),
                  onPrimaryAction: _casePrimaryAction(item.learningCase),
                  primaryActionLabel: _casePrimaryLabel(item.learningCase),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentDetail(
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
          subtitle:
              '${student.grade} · ${student.subject} · ${student.context}',
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

  Widget _buildCaseDetail(
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
              hasReminder ? '当前提醒：${learningCase.nextAction}' : '当前没有设置提醒',
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

  VoidCallback _casePrimaryAction(PrototypeCase learningCase) {
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
}

String _previewDateLabel(DateTime value) => '${value.month} 月 ${value.day} 日';

PrototypeStudent _copyPrototypeStudent(PrototypeStudent student) {
  return PrototypeStudent(
    id: student.id,
    name: student.name,
    grade: student.grade,
    subject: student.subject,
    context: student.context,
    cases: List<PrototypeCase>.of(student.cases),
    recentFacts: List<PrototypeTimelineEvent>.of(student.recentFacts),
  );
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.sizeClass, required this.child});

  final WindowSizeClass sizeClass;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = sizeClass == WindowSizeClass.compact
        ? AppSpacing.md
        : sizeClass == WindowSizeClass.medium
        ? AppSpacing.lg
        : AppSpacing.xl;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.md,
        horizontalPadding,
        AppSpacing.xxl,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: child,
        ),
      ),
    );
  }
}

class _DesignShell extends StatelessWidget {
  const _DesignShell({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onFocusStudentSearch,
    required this.child,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onFocusStudentSearch;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            onFocusStudentSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            onFocusStudentSearch,
      },
      child: Focus(
        autofocus: true,
        child: ResponsiveLayout(
          builder: (context, sizeClass) {
            if (sizeClass == WindowSizeClass.compact) {
              return Scaffold(
                body: SafeArea(child: child),
                bottomNavigationBar: NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  destinations: _navigationDestinations,
                ),
              );
            }

            final extended = sizeClass == WindowSizeClass.expanded;
            return Scaffold(
              body: SafeArea(
                child: Row(
                  children: [
                    _DesignRail(
                      extended: extended,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onDestinationSelected,
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: child),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DesignRail extends StatelessWidget {
  const _DesignRail({
    required this.extended,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final bool extended;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: extended ? 232 : 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              extended ? AppSpacing.lg : AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: extended
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '学情闭环',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '教师工作台',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  )
                : const Center(child: Icon(Icons.menu_book_outlined, size: 24)),
          ),
          Expanded(
            child: NavigationRail(
              extended: extended,
              minExtendedWidth: 232,
              backgroundColor: Colors.transparent,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.none,
              indicatorColor: Theme.of(context).colorScheme.primaryContainer,
              selectedIconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.primary,
              ),
              unselectedIconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              destinations: _railDestinations,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              extended ? AppSpacing.lg : AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.lg,
            ),
            child: Text(
              extended ? '教师工作台 · 虚构数据' : '虚构数据',
              textAlign: extended ? TextAlign.start : TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

const _navigationDestinations = <NavigationDestination>[
  NavigationDestination(
    icon: Icon(Icons.today_outlined),
    selectedIcon: Icon(Icons.today),
    label: '今日',
  ),
  NavigationDestination(
    icon: Icon(Icons.people_outline),
    selectedIcon: Icon(Icons.people),
    label: '学生',
  ),
  NavigationDestination(
    icon: Icon(Icons.menu_book_outlined),
    selectedIcon: Icon(Icons.menu_book),
    label: '课程',
  ),
  NavigationDestination(
    icon: Icon(Icons.account_tree_outlined),
    selectedIcon: Icon(Icons.account_tree),
    label: '学情',
  ),
];

const _railDestinations = <NavigationRailDestination>[
  NavigationRailDestination(
    icon: Icon(Icons.today_outlined),
    selectedIcon: Icon(Icons.today),
    label: Text('今日'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.people_outline),
    selectedIcon: Icon(Icons.people),
    label: Text('学生'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.menu_book_outlined),
    selectedIcon: Icon(Icons.menu_book),
    label: Text('课程'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.account_tree_outlined),
    selectedIcon: Icon(Icons.account_tree),
    label: Text('学情'),
  ),
];

class _ActionWithContext {
  const _ActionWithContext({
    required this.student,
    required this.learningCase,
    required this.action,
  });

  final PrototypeStudent student;
  final PrototypeCase learningCase;
  final PrototypeAction action;
}

class _StudentActionGroup extends StatelessWidget {
  const _StudentActionGroup({
    required this.student,
    required this.items,
    required this.completedActionIds,
    required this.onOpenCase,
    required this.onComplete,
  });

  final PrototypeStudent student;
  final List<_ActionWithContext> items;
  final Set<String> completedActionIds;
  final ValueChanged<PrototypeCase> onOpenCase;
  final ValueChanged<PrototypeAction> onComplete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              '${student.name} · ${student.subject}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final item in items)
            DesignActionRow(
              student: item.student,
              learningCase: item.learningCase,
              action: item.action,
              isCompleted: completedActionIds.contains(item.action.id),
              onOpenCase: () => onOpenCase(item.learningCase),
              onComplete: () => onComplete(item.action),
            ),
        ],
      ),
    );
  }
}

class _ActionSubheading extends StatelessWidget {
  const _ActionSubheading({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.student, required this.onStart});

  final PrototypeStudent student;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.menu_book_outlined, size: 21),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                DesignMetadata('${student.subject} · ${student.context}'),
              ],
            ),
          ),
          FilledButton(onPressed: onStart, child: const Text('开始记录课程')),
        ],
      ),
    );
  }
}

class _DetailFacts extends StatelessWidget {
  const _DetailFacts({required this.student, required this.sizeClass});

  final PrototypeStudent student;
  final WindowSizeClass sizeClass;

  @override
  Widget build(BuildContext context) {
    final facts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final event in student.recentFacts)
          DesignTimelineItem(event: event),
      ],
    );
    if (sizeClass != WindowSizeClass.expanded) {
      return DesignSection(title: '最近关键事实', child: facts);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DesignSection(title: '最近关键事实', child: facts),
        ),
        const SizedBox(width: AppSpacing.xl),
        const Expanded(
          child: DesignStateNotice(
            title: '历史按需展开',
            message: '先用最近关键事实解释现在，需要时再查看更早 timeline。',
            icon: Icons.history_outlined,
          ),
        ),
      ],
    );
  }
}

class _CaseNarrativeSection extends StatelessWidget {
  const _CaseNarrativeSection({
    required this.title,
    required this.content,
    required this.actionLabel,
    required this.onAction,
    this.isPrimary = false,
  });

  final String title;
  final String content;
  final String actionLabel;
  final VoidCallback onAction;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const Divider(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

enum QuickCaptureOutcome { saved, draft }

class PrototypeQuickCapture {
  const PrototypeQuickCapture({
    this.studentId,
    required this.title,
    required this.note,
  });

  final String? studentId;
  final String title;
  final String note;
}

class QuickCaptureResult {
  const QuickCaptureResult.saved(this.capture)
    : outcome = QuickCaptureOutcome.saved;

  const QuickCaptureResult.draft(this.capture)
    : outcome = QuickCaptureOutcome.draft;

  final QuickCaptureOutcome outcome;
  final PrototypeQuickCapture? capture;
}

class DesignQuickCaptureForm extends StatefulWidget {
  const DesignQuickCaptureForm({
    required this.students,
    this.student,
    super.key,
  });

  final List<PrototypeStudent> students;
  final PrototypeStudent? student;

  @override
  State<DesignQuickCaptureForm> createState() => _DesignQuickCaptureFormState();
}

class _DesignQuickCaptureFormState extends State<DesignQuickCaptureForm> {
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
    _selectedStudent =
        widget.student ??
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
    final normalized = note.replaceAll(RegExp(r'\s+'), ' ').trim();
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
                      value:
                          '${widget.student!.name} · ${widget.student!.subject}',
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

class _ContextField extends StatelessWidget {
  const _ContextField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: content,
    );
  }
}
