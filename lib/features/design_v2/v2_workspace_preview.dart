import 'package:flutter/material.dart';

import 'v2_composers.dart';
import 'v2_fixture.dart';

Future<void> _showV2ProgressCasePicker(
  BuildContext context,
  V2Student student,
) async {
  final items = v2FocusItemsForStudent(student);
  if (items.isEmpty) {
    return;
  }

  Widget choices(BuildContext sheetContext) => ListView.separated(
    shrinkWrap: true,
    itemCount: items.length,
    separatorBuilder: (_, _) => Divider(
      height: 1,
      color: Theme.of(sheetContext).colorScheme.outlineVariant,
    ),
    itemBuilder: (_, index) {
      final item = items[index];
      return ListTile(
        title: Text(item.title),
        subtitle: Text(item.subject),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(sheetContext).pop(item),
      );
    },
  );

  final compact = MediaQuery.sizeOf(context).width < 720;
  final selected = compact
      ? await showModalBottomSheet<V2FocusItem>(
          context: context,
          useSafeArea: true,
          builder: (sheetContext) => Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择要记录进展的问题',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                choices(sheetContext),
              ],
            ),
          ),
        )
      : await showDialog<V2FocusItem>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('选择要记录进展的问题'),
            content: SizedBox(width: 420, child: choices(dialogContext)),
          ),
        );
  if (selected == null || !context.mounted) {
    return;
  }
  await showV2ProgressComposer(
    context,
    studentName: student.name,
    subject: selected.subject,
    caseTitle: selected.title,
  );
}

class V2WorkspacePreview extends StatefulWidget {
  const V2WorkspacePreview({super.key});

  @override
  State<V2WorkspacePreview> createState() => _V2WorkspacePreviewState();
}

class _V2WorkspacePreviewState extends State<V2WorkspacePreview> {
  int _destination = 1;
  V2Student _selectedStudent = v2Students.first;
  V2FocusItem _selectedCase = v2FocusItems.first;
  bool _showCase = false;

  void _openStudent(V2Student student) {
    setState(() {
      _selectedStudent = student;
      _showCase = false;
    });
  }

  void _openCase(V2FocusItem item) {
    setState(() {
      _destination = 1;
      _selectedStudent = v2StudentForFocusItem(item);
      _selectedCase = item;
      _showCase = true;
    });
  }

  void _closeCase() => setState(() => _showCase = false);

  void _changeDestination(int value) {
    setState(() {
      _destination = value;
      _showCase = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return _CompactWorkspace(
            destination: _destination,
            selectedStudent: _selectedStudent,
            selectedCase: _selectedCase,
            showCase: _showCase,
            onDestinationChanged: _changeDestination,
            onStudentSelected: _openStudent,
            onOpenCase: _openCase,
            onBackFromCase: _closeCase,
          );
        }
        return _DesktopWorkspace(
          destination: _destination,
          selectedStudent: _selectedStudent,
          selectedCase: _selectedCase,
          showCase: _showCase,
          onDestinationChanged: _changeDestination,
          onStudentSelected: _openStudent,
          onOpenCase: _openCase,
          onBackFromCase: _closeCase,
        );
      },
    );
  }
}

class _DesktopWorkspace extends StatelessWidget {
  const _DesktopWorkspace({
    required this.destination,
    required this.selectedStudent,
    required this.selectedCase,
    required this.showCase,
    required this.onDestinationChanged,
    required this.onStudentSelected,
    required this.onOpenCase,
    required this.onBackFromCase,
  });

  final int destination;
  final V2Student selectedStudent;
  final V2FocusItem selectedCase;
  final bool showCase;
  final ValueChanged<int> onDestinationChanged;
  final ValueChanged<V2Student> onStudentSelected;
  final ValueChanged<V2FocusItem> onOpenCase;
  final VoidCallback onBackFromCase;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).colorScheme.outlineVariant;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: _NavigationRail(
                selectedIndex: destination,
                onSelected: onDestinationChanged,
              ),
            ),
            VerticalDivider(width: 1, color: border),
            if (destination == 1) ...[
              SizedBox(
                width: 336,
                child: _StudentListPane(
                  selectedStudent: selectedStudent,
                  onSelected: onStudentSelected,
                ),
              ),
              VerticalDivider(width: 1, color: border),
              Expanded(
                child: showCase
                    ? _CaseDetailPane(
                        student: selectedStudent,
                        item: selectedCase,
                        onBack: onBackFromCase,
                      )
                    : _StudentDetailPane(
                        student: selectedStudent,
                        onOpenCase: onOpenCase,
                      ),
              ),
            ] else if (destination == 0) ...[
              Expanded(child: _TodayPane(onOpenCase: onOpenCase)),
            ] else if (destination == 3) ...[
              Expanded(child: _CaseIndexPane(onOpenCase: onOpenCase)),
            ] else ...[
              const Expanded(
                child: _QuietPlaceholder(
                  title: '课程',
                  message: 'V2 第一阶段先确定教师高频工作流。课程入口将在 Shell 稳定后接入。',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactWorkspace extends StatefulWidget {
  const _CompactWorkspace({
    required this.destination,
    required this.selectedStudent,
    required this.selectedCase,
    required this.showCase,
    required this.onDestinationChanged,
    required this.onStudentSelected,
    required this.onOpenCase,
    required this.onBackFromCase,
  });

  final int destination;
  final V2Student selectedStudent;
  final V2FocusItem selectedCase;
  final bool showCase;
  final ValueChanged<int> onDestinationChanged;
  final ValueChanged<V2Student> onStudentSelected;
  final ValueChanged<V2FocusItem> onOpenCase;
  final VoidCallback onBackFromCase;

  @override
  State<_CompactWorkspace> createState() => _CompactWorkspaceState();
}

class _CompactWorkspaceState extends State<_CompactWorkspace> {
  bool _studentOpen = false;

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (widget.showCase) {
      body = _CaseDetailPane(
        student: widget.selectedStudent,
        item: widget.selectedCase,
        onBack: widget.onBackFromCase,
        compact: true,
      );
    } else if (widget.destination == 1 && _studentOpen) {
      body = _StudentDetailPane(
        student: widget.selectedStudent,
        onOpenCase: widget.onOpenCase,
        compact: true,
        onBack: () => setState(() => _studentOpen = false),
      );
    } else if (widget.destination == 1) {
      body = _StudentListPane(
        selectedStudent: widget.selectedStudent,
        compact: true,
        onSelected: (student) {
          widget.onStudentSelected(student);
          setState(() => _studentOpen = true);
        },
      );
    } else if (widget.destination == 0) {
      body = _TodayPane(onOpenCase: widget.onOpenCase, compact: true);
    } else if (widget.destination == 3) {
      body = _CaseIndexPane(onOpenCase: widget.onOpenCase, compact: true);
    } else {
      body = const _QuietPlaceholder(title: '课程', message: '课程入口将在下一阶段接入 V2。');
    }

    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: widget.showCase || _studentOpen
          ? null
          : NavigationBar(
              selectedIndex: widget.destination,
              onDestinationSelected: (value) {
                setState(() => _studentOpen = false);
                widget.onDestinationChanged(value);
              },
              destinations: const [
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
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: '学情',
                ),
              ],
            ),
    );
  }
}

class _NavigationRail extends StatelessWidget {
  const _NavigationRail({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: Column(
        children: [
          const SizedBox(height: 18),
          Icon(Icons.eco_outlined, color: scheme.primary, size: 27),
          const SizedBox(height: 22),
          for (final item in const [
            (Icons.today_outlined, '今日'),
            (Icons.people_outline, '学生'),
            (Icons.menu_book_outlined, '课程'),
            (Icons.fact_check_outlined, '学情'),
          ].indexed)
            _RailItem(
              icon: item.$2.$1,
              tooltip: item.$2.$2,
              selected: selectedIndex == item.$1,
              onTap: () => onSelected(item.$1),
            ),
          const Spacer(),
          const _RailItem(
            icon: Icons.admin_panel_settings_outlined,
            tooltip: '管理',
          ),
          const _RailItem(icon: Icons.settings_outlined, tooltip: '设置'),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.tooltip,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 44,
              child: Icon(
                icon,
                size: 20,
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentListPane extends StatefulWidget {
  const _StudentListPane({
    required this.selectedStudent,
    required this.onSelected,
    this.compact = false,
  });

  final V2Student selectedStudent;
  final ValueChanged<V2Student> onSelected;
  final bool compact;

  @override
  State<_StudentListPane> createState() => _StudentListPaneState();
}

class _StudentListPaneState extends State<_StudentListPane> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<V2Student> get _visibleStudents {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return v2Students;
    }
    return v2Students
        .where((student) {
          final haystack = [
            student.name,
            student.grade,
            ...student.subjects,
            student.teacherSummary,
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final visibleStudents = _visibleStudents;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.compact ? 18 : 24,
              24,
              widget.compact ? 18 : 20,
              12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('学生', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 18),
                TextField(
                  key: const Key('v2-student-search'),
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: '搜索姓名、年级、学科或老师…',
                    prefixIcon: const Icon(Icons.search, size: 19),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除搜索',
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close, size: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _query.trim().isEmpty
                      ? '全部 ${v2Students.length}'
                      : '找到 ${visibleStudents.length} 位',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            child: visibleStudents.isEmpty
                ? Center(
                    child: Text(
                      '没有找到匹配的学生',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: visibleStudents.length,
                    itemBuilder: (context, index) {
                      final student = visibleStudents[index];
                      return _StudentRow(
                        student: student,
                        selected: student.id == widget.selectedStudent.id,
                        onTap: () => widget.onSelected(student),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.selected,
    required this.onTap,
  });

  final V2Student student;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.07)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _InitialMark(name: student.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${student.grade} · ${student.subjects.join(' / ')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      student.openCaseCount == 0
                          ? '暂无进行中'
                          : '${student.openCaseCount} 个问题',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      student.updatedLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InitialMark extends StatelessWidget {
  const _InitialMark({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        name.characters.first,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _StudentDetailPane extends StatelessWidget {
  const _StudentDetailPane({
    required this.student,
    required this.onOpenCase,
    this.compact = false,
    this.onBack,
  });

  final V2Student student;
  final ValueChanged<V2FocusItem> onOpenCase;
  final bool compact;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focusItems = v2FocusItemsForStudent(student);
    final timelineEntries = v2TimelineForStudent(student);
    return ColoredBox(
      color: scheme.surface,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 32,
                    22,
                    compact ? 18 : 32,
                    48,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (onBack != null) ...[
                        IconButton(
                          tooltip: '返回学生列表',
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(height: 4),
                      ],
                      _StudentHeader(student: student, compact: compact),
                      const SizedBox(height: 30),
                      _SectionTitle(title: '现在最重要', count: focusItems.length),
                      const SizedBox(height: 8),
                      if (focusItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            '暂无进行中的问题',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      else
                        for (var i = 0; i < focusItems.length; i++) ...[
                          _FocusRow(
                            item: focusItems[i],
                            onTap: () => onOpenCase(focusItems[i]),
                          ),
                          if (i < focusItems.length - 1)
                            Divider(height: 1, color: scheme.outlineVariant),
                        ],
                      const SizedBox(height: 34),
                      const _SectionTitle(title: '最近成长'),
                      const SizedBox(height: 14),
                      _Timeline(entries: timelineEntries),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentHeader extends StatelessWidget {
  const _StudentHeader({required this.student, required this.compact});

  final V2Student student;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final focusItems = v2FocusItemsForStudent(student);
    final buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => showV2QuickCapture(
            context,
            studentName: student.name,
            subjects: student.subjects,
          ),
          icon: const Icon(Icons.note_add_outlined, size: 18),
          label: const Text('记录问题'),
        ),
        FilledButton.icon(
          onPressed: focusItems.isEmpty
              ? null
              : () => _showV2ProgressCasePicker(context, student),
          icon: const Icon(Icons.edit_note_outlined, size: 18),
          label: const Text('记进展'),
        ),
        IconButton(
          onPressed: () {},
          tooltip: '更多',
          icon: const Icon(Icons.more_horiz),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '学生  /  ${student.name}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        if (compact) ...[
          Text(student.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 5),
          Text(
            '${student.grade} · ${student.subjects.join(' / ')}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 5),
          Text(
            student.teacherSummary,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          buttons,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${student.grade} · ${student.subjects.join(' / ')}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      student.teacherSummary,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              buttons,
            ],
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text('$count', style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _FocusRow extends StatelessWidget {
  const _FocusRow({required this.item, required this.onTap, this.studentName});

  final V2FocusItem item;
  final VoidCallback onTap;
  final String? studentName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 2,
              height: 58,
              color: scheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.summary,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '下一步  ${item.nextStep}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  studentName == null
                      ? item.subject
                      : '$studentName · ${item.subject}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 17),
                Text(
                  item.dueLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries});

  final List<V2TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text('暂时还没有成长记录', style: Theme.of(context).textTheme.bodyMedium);
    }
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          _TimelineRow(entry: entries[i], last: i == entries.length - 1),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.last});

  final V2TimelineEntry entry;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 74,
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              entry.date,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 7),
                decoration: BoxDecoration(
                  color: entry.kind == '新表现' ? scheme.primary : scheme.outline,
                  shape: BoxShape.circle,
                ),
              ),
              if (!last)
                Container(
                  width: 1,
                  height: entry.photoCount > 0 ? 144 : 96,
                  color: scheme.outlineVariant,
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.kind,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(entry.body, style: Theme.of(context).textTheme.bodyMedium),
                if (entry.photoCount > 0) ...[
                  const SizedBox(height: 12),
                  _PhotoStrip(count: entry.photoCount),
                ],
                const SizedBox(height: 9),
                Text(
                  '${entry.teacher} · ${entry.time}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < count.clamp(0, 3); i++)
          Container(
            width: 86,
            height: 66,
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              Icons.description_outlined,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
      ],
    );
  }
}

class _CaseDetailPane extends StatelessWidget {
  const _CaseDetailPane({
    required this.student,
    required this.item,
    required this.onBack,
    this.compact = false,
  });

  final V2Student student;
  final V2FocusItem item;
  final VoidCallback onBack;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timelineEntries = v2TimelineForCase(item);
    return ColoredBox(
      color: scheme.surface,
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 32,
                20,
                compact ? 18 : 32,
                48,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: '返回',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${student.name} · ${item.subject}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: () => showV2ProgressComposer(
                          context,
                          studentName: student.name,
                          subject: item.subject,
                          caseTitle: item.title,
                        ),
                        icon: const Icon(Icons.edit_note_outlined, size: 18),
                        label: const Text('记进展'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.summary,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  Text('下一步', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_forward,
                        size: 17,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.nextStep,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        item.dueLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Divider(color: scheme.outlineVariant),
                  const SizedBox(height: 28),
                  const _SectionTitle(title: '成长过程'),
                  const SizedBox(height: 16),
                  _Timeline(entries: timelineEntries),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayPane extends StatelessWidget {
  const _TodayPane({required this.onOpenCase, this.compact = false});

  final ValueChanged<V2FocusItem> onOpenCase;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 18 : 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('今日', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 5),
              Text(
                '9 月 9 日 · 周三',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 28),
              const _SectionTitle(title: '需要处理'),
              const SizedBox(height: 8),
              for (final item in v2FocusItems.take(4))
                _TodayAction(item: item, onOpenCase: onOpenCase),
              const SizedBox(height: 28),
              const _SectionTitle(title: '待验证'),
              const SizedBox(height: 10),
              _TodayAction(
                item: v2FocusItems[4],
                onOpenCase: onOpenCase,
                verification: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayAction extends StatelessWidget {
  const _TodayAction({
    required this.item,
    required this.onOpenCase,
    this.verification = false,
  });

  final V2FocusItem item;
  final ValueChanged<V2FocusItem> onOpenCase;
  final bool verification;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final student = v2StudentForFocusItem(item);
    return InkWell(
      onTap: () => onOpenCase(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 2,
              height: 56,
              color: verification ? scheme.primary : const Color(0xFFB77728),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${student.name} · ${item.subject}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    verification ? '等待确认是否已经稳定' : '下一步 · ${item.nextStep}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              verification ? '待验证' : item.dueLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CaseIndexPane extends StatefulWidget {
  const _CaseIndexPane({required this.onOpenCase, this.compact = false});

  final ValueChanged<V2FocusItem> onOpenCase;
  final bool compact;

  @override
  State<_CaseIndexPane> createState() => _CaseIndexPaneState();
}

class _CaseIndexPaneState extends State<_CaseIndexPane> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<V2FocusItem> get _visibleItems {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return v2FocusItems;
    }
    return v2FocusItems
        .where((item) {
          final student = v2StudentForFocusItem(item);
          final haystack = [
            student.name,
            student.grade,
            item.subject,
            item.title,
            item.summary,
            item.nextStep,
            student.teacherSummary,
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;
    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.compact ? 18 : 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('学情', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 5),
              Text('找到仍需要复盘的问题', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 22),
              TextField(
                key: const Key('v2-case-search'),
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: '搜索学生、学科或问题…',
                  prefixIcon: const Icon(Icons.search, size: 19),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除搜索',
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close, size: 18),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _query.trim().isEmpty
                    ? '进行中 ${v2FocusItems.length}'
                    : '找到 ${visibleItems.length} 个问题',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              if (visibleItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      '没有找到匹配的问题',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                for (final item in visibleItems)
                  _FocusRow(
                    item: item,
                    studentName: v2StudentForFocusItem(item).name,
                    onTap: () => widget.onOpenCase(item),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuietPlaceholder extends StatelessWidget {
  const _QuietPlaceholder({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
