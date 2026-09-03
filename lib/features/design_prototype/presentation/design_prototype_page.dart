import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/layout/responsive.dart';
import '../../../app/theme/app_colors.dart';
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
      _selectedStudent = DesignFixture.studentForCase(learningCase);
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
            builder: (context) => DesignQuickCaptureForm(student: student),
          )
        : await showDialog<QuickCaptureResult>(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                Dialog(child: DesignQuickCaptureForm(student: student)),
          );

    if (!mounted || result == null) return;
    final message = switch (result) {
      QuickCaptureResult.saved => '已记录为待整理问题',
      QuickCaptureResult.draft => '已保留本机草稿（设计预览）',
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _completeAction(PrototypeAction action) {
    setState(() => _completedActionIds.add(action.id));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已完成：${action.title}')));
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
    final actionGroups = <String, List<_ActionWithContext>>{};
    for (final student in DesignFixture.students) {
      for (final learningCase in student.cases) {
        final action = learningCase.primaryAction;
        if (action == null ||
            _completedActionIds.contains(action.id) ||
            learningCase.status == PrototypeCaseStatus.pendingVerification) {
          continue;
        }
        actionGroups
            .putIfAbsent(student.id, () => <_ActionWithContext>[])
            .add(
              _ActionWithContext(
                student: student,
                learningCase: learningCase,
                action: action,
              ),
            );
      }
    }

    final ordinaryActions = actionGroups.values.expand((items) => items);
    final overdue = _actionsInBucket(
      ordinaryActions,
      PrototypeActionDueBucket.overdue,
    );
    final dueToday = _actionsInBucket(
      ordinaryActions,
      PrototypeActionDueBucket.today,
    );
    final future = _actionsInBucket(
      ordinaryActions,
      PrototypeActionDueBucket.future,
    );
    final undated = _actionsInBucket(
      ordinaryActions,
      PrototypeActionDueBucket.undated,
    );
    final pendingVerification = DesignFixture.students
        .expand(
          (student) => student.cases.map(
            (learningCase) => (student: student, learningCase: learningCase),
          ),
        )
        .where(
          (item) =>
              item.learningCase.status ==
              PrototypeCaseStatus.pendingVerification,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DesignPreviewBanner(),
        const SizedBox(height: AppSpacing.lg),
        DesignPageHeader(
          title: '今日',
          subtitle: '先处理今天要做的事，再回看需要判断的学生。',
          actions: [
            OutlinedButton.icon(
              onPressed: () => _showQuickCapture(),
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('记录问题'),
            ),
          ],
        ),
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
                    color: AppColors.danger,
                    icon: Icons.warning_amber_outlined,
                  ),
                  ..._buildActionGroups(overdue),
                ],
                if (dueToday.isNotEmpty) ...[
                  if (overdue.isNotEmpty) const Divider(height: AppSpacing.lg),
                  _ActionSubheading(
                    label: '今天到期',
                    color: AppColors.warning,
                    icon: Icons.today_outlined,
                  ),
                  ..._buildActionGroups(dueToday),
                ],
              ],
            ),
          ),
        ] else
          const DesignStateNotice(
            title: '今天没有待完成的行动',
            message: '可以回看最近记录，或在课堂中先记录一句问题。',
            icon: Icons.check_circle_outline,
          ),
        const SizedBox(height: AppSpacing.lg),
        DesignSection(
          key: const Key('pending-verification-section'),
          title: '待验证',
          count: '${pendingVerification.length} 个 Case',
          showTopDivider: true,
          child: pendingVerification.isEmpty
              ? const DesignStateNotice(
                  title: '还没有待验证事项',
                  message: '完成一次检查后，在这里确认是否稳定。',
                  icon: Icons.fact_check_outlined,
                )
              : Column(
                  children: [
                    for (final item in pendingVerification)
                      DesignCaseRow(
                        student: item.student,
                        learningCase: item.learningCase,
                        onOpen: () => _openCase(item.learningCase),
                        onPrimaryAction: _casePrimaryAction(item.learningCase),
                        primaryActionLabel: _casePrimaryLabel(
                          item.learningCase,
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (future.isNotEmpty)
          DesignSection(
            key: const Key('future-actions-section'),
            title: '未来',
            count: '${future.length} 项',
            showTopDivider: true,
            child: Column(children: _buildActionGroups(future)),
          ),
        if (future.isNotEmpty) const SizedBox(height: AppSpacing.lg),
        DesignSection(
          key: const Key('undated-actions-section'),
          title: '待安排',
          count: '${undated.length} 项',
          showTopDivider: true,
          child: undated.isEmpty
              ? const DesignStateNotice(
                  title: '没有待安排的行动',
                  message: '需要跟进但尚未设定日期的行动会一直保留在这里。',
                  icon: Icons.event_available_outlined,
                )
              : Column(children: _buildActionGroups(undated)),
        ),
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
              for (final student in DesignFixture.students)
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
        final students = DesignFixture.students.where((student) {
          if (query.isEmpty) return true;
          return '${student.name}${student.subject}${student.context}'.contains(
            query,
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
                OutlinedButton.icon(
                  onPressed: () => _showQuickCapture(),
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('记录问题'),
                ),
              ],
            ),
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
        DesignSection(
          title: '可以开始记录',
          child: Column(
            children: [
              for (final student in DesignFixture.students)
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
      for (final student in DesignFixture.students)
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
          subtitle: '按 Case 查看问题、证据、教学动作和下一行动。',
          actions: [
            OutlinedButton.icon(
              onPressed: () => _showQuickCapture(),
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('记录问题'),
            ),
          ],
        ),
        DesignSection(
          title: '当前 Learning Cases',
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
    final importantCases = student.cases.take(3).toList();
    final pendingCases = student.cases
        .where(
          (learningCase) =>
              learningCase.status == PrototypeCaseStatus.pendingVerification,
        )
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
            OutlinedButton.icon(
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
            title: '还没有 Learning Case',
            message: '发现问题时，可以先记录一句，课后再整理。',
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
          title: '当前 Learning Cases',
          count: '${student.cases.length} 个',
          showTopDivider: true,
          child: student.cases.isEmpty
              ? const DesignStateNotice(
                  title: '还没有当前 Case',
                  message: '问题出现时可以从这里开始记录。',
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
        const SizedBox(height: AppSpacing.lg),
        DesignSection(
          title: '待验证',
          count: '${pendingCases.length} 个',
          showTopDivider: true,
          child: pendingCases.isEmpty
              ? const DesignStateNotice(
                  title: '目前没有待验证 Case',
                  message: '完成一次检查后，回到这里确认是否稳定。',
                  icon: Icons.fact_check_outlined,
                )
              : Column(
                  children: [
                    for (final learningCase in pendingCases)
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
        _DetailFacts(student: student, sizeClass: sizeClass),
      ],
    );
  }

  Widget _buildCaseDetail(
    BuildContext context,
    PrototypeStudent student,
    PrototypeCase learningCase,
  ) {
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
            DesignMetadata('下一行动：${learningCase.nextAction}'),
            DesignMetadata(
              learningCase.nextActionDue,
              icon: Icons.event_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (learningCase.status == PrototypeCaseStatus.pendingVerification)
          const DesignStateNotice(
            title: '本次验证通过，仍待确认是否稳定',
            message: 'Assessment passed 不是 stable。请确认稳定或继续跟进，并保留这次检查记录。',
            icon: Icons.fact_check_outlined,
          )
        else if (learningCase.status == PrototypeCaseStatus.stable)
          const DesignStateNotice(
            title: '稳定；仍需安排下一次检查',
            message: '稳定不等于已关闭，仍需保留 review / verify action。',
            icon: Icons.check_circle_outline,
          ),
        const SizedBox(height: AppSpacing.lg),
        _CaseNarrativeSection(
          title: '问题',
          content: learningCase.problem,
          actionLabel: '补充问题说明',
          onAction: () => _showPrototypeNotice('补充问题说明'),
        ),
        _CaseNarrativeSection(
          title: 'Evidence / 证据',
          content: learningCase.evidence,
          actionLabel: '补充证据',
          onAction: () => _showPrototypeNotice('补充证据'),
        ),
        _CaseNarrativeSection(
          title: '教师判断',
          content: learningCase.judgement,
          actionLabel: '记录教师判断',
          onAction: () => _showPrototypeNotice('记录教师判断'),
        ),
        _CaseNarrativeSection(
          title: 'Intervention / 教学动作',
          content: learningCase.intervention,
          actionLabel: '记录教学动作',
          onAction: () => _showPrototypeNotice('记录教学动作'),
        ),
        _CaseNarrativeSection(
          title: 'Assessment / Verification',
          content: learningCase.assessment,
          actionLabel: '记录一次检查',
          onAction: () => _showPrototypeNotice('记录一次检查'),
        ),
        _CaseNarrativeSection(
          title: 'Next Action / 下一行动',
          content: '${learningCase.nextAction}（${learningCase.nextActionDue}）',
          actionLabel: '安排/改期',
          onAction: () => _showPrototypeNotice('安排/改期'),
          isPrimary: true,
        ),
        DesignSection(
          title: '历史 timeline',
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

  bool _isCaseStateCommand(PrototypeCase learningCase) {
    return switch (learningCase.status) {
      PrototypeCaseStatus.pendingVerification ||
      PrototypeCaseStatus.stable ||
      PrototypeCaseStatus.closed => true,
      _ => false,
    };
  }

  VoidCallback _casePrimaryAction(PrototypeCase learningCase) {
    if (_isCaseStateCommand(learningCase)) {
      return () => _showCaseCommandNotice(learningCase);
    }

    final action = learningCase.primaryAction;
    if (action != null) {
      return () => _completeAction(action);
    }

    return () => _showPrototypeNotice('处理下一步');
  }

  void _showCaseCommandNotice(PrototypeCase learningCase) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '设计预览：${_casePrimaryLabel(learningCase)}只展示命令入口，不改变领域状态。',
        ),
      ),
    );
  }

  void _showPrototypeNotice(String actionLabel) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$actionLabel 入口已定义；当前预览不会写入业务数据。')));
  }

  String _casePrimaryLabel(PrototypeCase learningCase) {
    return switch (learningCase.status) {
      PrototypeCaseStatus.pendingVerification => '确认稳定',
      PrototypeCaseStatus.stable => '安排下一次检查',
      PrototypeCaseStatus.closed => '重新打开',
      _ => '处理下一步',
    };
  }
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
    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyK, control: true):
              onFocusStudentSearch,
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
              onFocusStudentSearch,
        },
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
              indicatorColor: AppColors.surfaceAccent,
              selectedIconTheme: const IconThemeData(color: AppColors.accent),
              unselectedIconTheme: const IconThemeData(
                color: AppColors.textSecondary,
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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book_outlined, size: 21),
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

enum QuickCaptureResult { saved, draft }

class DesignQuickCaptureForm extends StatefulWidget {
  const DesignQuickCaptureForm({this.student, super.key});

  final PrototypeStudent? student;

  @override
  State<DesignQuickCaptureForm> createState() => _DesignQuickCaptureFormState();
}

class _DesignQuickCaptureFormState extends State<DesignQuickCaptureForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  PrototypeStudent? _selectedStudent;
  bool _saving = false;
  String? _studentError;
  String? _titleError;

  bool get _isDirty =>
      _titleController.text.trim().isNotEmpty ||
      _noteController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selectedStudent = widget.student;
    _titleController = TextEditingController();
    _noteController = TextEditingController();
    _titleController.addListener(_onTextChanged);
    _noteController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_onTextChanged)
      ..dispose();
    _noteController
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_titleError != null && _titleController.text.trim().isNotEmpty) {
      setState(() => _titleError = null);
      return;
    }
    setState(() {});
  }

  Future<void> _save() async {
    if (_selectedStudent == null) {
      setState(() => _studentError = '请选择学生');
      return;
    }
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = '请先写下问题标题');
      return;
    }
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    Navigator.of(context).pop(QuickCaptureResult.saved);
  }

  Future<void> _cancel() async {
    if (!_isDirty && !_saving) {
      Navigator.of(context).pop();
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('还没有保存'),
        content: const Text('还没有保存，要保留这段记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('放弃记录'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保留草稿'),
          ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    Navigator.of(context).pop(result ? QuickCaptureResult.draft : null);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope<void>(
      canPop: !_isDirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _cancel();
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
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<PrototypeStudent>(
                    initialValue: _selectedStudent,
                    decoration: InputDecoration(
                      labelText: '学生 *',
                      errorText: _studentError,
                    ),
                    hint: const Text('选择学生后开始'),
                    items: [
                      for (final student in DesignFixture.students)
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
                          },
                  ),
                  _ContextField(
                    label: '学科',
                    value: _selectedStudent?.subject ?? '尚未选择',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _titleController,
                    autofocus: _selectedStudent != null,
                    enabled: !_saving,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _save(),
                    decoration: InputDecoration(
                      labelText: '问题标题 *',
                      hintText: '用一句话记下刚发现的问题',
                      errorText: _titleError,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '看起来已有相近的 Case 时，这里只提示，不会阻止你先记录。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _noteController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: '补充说明（可选）',
                      hintText: '记下关键表现、题目或课堂语境',
                      alignLabelWithHint: true,
                    ),
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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: content,
    );
  }
}
