from pathlib import Path

preview_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
data_path = Path('lib/features/design_v2/v2_workspace_data.dart')
adapter_path = Path('lib/features/design_v2/v2_read_model_adapter.dart')
adapter_test_path = Path('test/features/design_v2_read_model_adapter_test.dart')
injection_test_path = Path('test/features/design_v2_workspace_data_injection_test.dart')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    return text.replace(old, new, 1)


def replace_exact_count(
    text: str,
    old: str,
    new: str,
    expected: int,
    label: str,
) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{label}: expected {expected} matches, found {count}')
    return text.replace(old, new)


preview = preview_path.read_text()
preview = replace_once(
    preview,
    "import 'v2_fixture.dart';\n",
    "import 'v2_fixture.dart';\nimport 'v2_workspace_data.dart';\n",
    'workspace data import',
)
preview = replace_once(
    preview,
    '  final items = v2FocusItemsForStudent(student);',
    '  final items = V2WorkspaceDataScope.of(context).focusItemsForStudent(student);',
    'progress picker data source',
)
preview = replace_once(
    preview,
    "class V2WorkspacePreview extends StatefulWidget {\n  const V2WorkspacePreview({super.key});\n\n  @override\n  State<V2WorkspacePreview> createState() => _V2WorkspacePreviewState();\n}\n",
    "class V2WorkspacePreview extends StatefulWidget {\n  const V2WorkspacePreview({\n    super.key,\n    this.data = v2FixtureWorkspaceData,\n  });\n\n  final V2WorkspaceData data;\n\n  @override\n  State<V2WorkspacePreview> createState() => _V2WorkspacePreviewState();\n}\n",
    'preview constructor',
)

state_start = preview.index(
    'class _V2WorkspacePreviewState extends State<V2WorkspacePreview> {'
)
state_end = preview.index(
    '\nclass _DesktopWorkspace extends StatelessWidget {',
    state_start,
)
new_state = r'''class _V2WorkspacePreviewState extends State<V2WorkspacePreview> {
  int _destination = 1;
  V2Student? _selectedStudent;
  V2FocusItem? _selectedCase;
  bool _showCase = false;

  @override
  void initState() {
    super.initState();
    _reconcileSelection();
  }

  @override
  void didUpdateWidget(covariant V2WorkspacePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      _reconcileSelection();
    }
  }

  void _reconcileSelection() {
    final students = widget.data.students;
    if (students.isEmpty) {
      _selectedStudent = null;
      _selectedCase = null;
      _showCase = false;
      return;
    }

    final currentStudentId = _selectedStudent?.id;
    _selectedStudent = students.firstWhere(
      (student) => student.id == currentStudentId,
      orElse: () => students.first,
    );

    final currentCaseId = _selectedCase?.id;
    if (currentCaseId == null) {
      return;
    }
    final matchingCases = widget.data.focusItems
        .where((item) => item.id == currentCaseId)
        .toList(growable: false);
    if (matchingCases.isEmpty ||
        matchingCases.first.studentId != _selectedStudent!.id) {
      _selectedCase = null;
      _showCase = false;
    } else {
      _selectedCase = matchingCases.first;
    }
  }

  void _openStudent(V2Student student) {
    setState(() {
      _selectedStudent = student;
      _selectedCase = null;
      _showCase = false;
    });
  }

  void _openCase(V2FocusItem item) {
    final student = widget.data.studentForFocusItemOrNull(item);
    if (student == null) {
      return;
    }
    setState(() {
      _destination = 1;
      _selectedStudent = student;
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
    return V2WorkspaceDataScope(
      data: widget.data,
      child: Builder(
        builder: (context) {
          if (widget.data.students.isEmpty) {
            return const _EmptyWorkspacePreview();
          }
          final selectedStudent = _selectedStudent ?? widget.data.students.first;
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 720) {
                return _CompactWorkspace(
                  destination: _destination,
                  selectedStudent: selectedStudent,
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
                selectedStudent: selectedStudent,
                selectedCase: _selectedCase,
                showCase: _showCase,
                onDestinationChanged: _changeDestination,
                onStudentSelected: _openStudent,
                onOpenCase: _openCase,
                onBackFromCase: _closeCase,
              );
            },
          );
        },
      ),
    );
  }
}'''
preview = preview[:state_start] + new_state + preview[state_end:]

preview = replace_exact_count(
    preview,
    '  final V2FocusItem selectedCase;',
    '  final V2FocusItem? selectedCase;',
    2,
    'nullable selected case fields',
)
preview = replace_once(
    preview,
    '                child: showCase\n                    ? _CaseDetailPane(',
    '                child: showCase && selectedCase != null\n                    ? _CaseDetailPane(',
    'desktop case guard',
)
preview = replace_once(
    preview,
    '                        item: selectedCase,',
    '                        item: selectedCase!,',
    'desktop nullable case',
)
preview = replace_once(
    preview,
    '    if (widget.showCase) {',
    '    if (widget.showCase && widget.selectedCase != null) {',
    'compact case guard',
)
preview = replace_once(
    preview,
    '        item: widget.selectedCase,',
    '        item: widget.selectedCase!,',
    'compact nullable case',
)

student_state_start = preview.index(
    'class _StudentListPaneState extends State<_StudentListPane> {'
)
student_state_end = preview.index(
    '\nclass _StudentRow extends StatelessWidget {',
    student_state_start,
)
new_student_state = r'''class _StudentListPaneState extends State<_StudentListPane> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<V2Student> _visibleStudents(V2WorkspaceData data) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return data.students;
    }
    return data.students
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
    final data = V2WorkspaceDataScope.of(context);
    final visibleStudents = _visibleStudents(data);
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
                      ? '全部 ${data.students.length}'
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
}'''
preview = (
    preview[:student_state_start]
    + new_student_state
    + preview[student_state_end:]
)

preview = replace_exact_count(
    preview,
    '    final focusItems = v2FocusItemsForStudent(student);',
    "    final data = V2WorkspaceDataScope.of(context);\n    final focusItems = data.focusItemsForStudent(student);",
    2,
    'student focus item lookups',
)
preview = replace_once(
    preview,
    '    final timelineEntries = v2TimelineForStudent(student);',
    '    final timelineEntries = data.timelineForStudent(student);',
    'student timeline lookup',
)
preview = replace_once(
    preview,
    '    final timelineEntries = v2TimelineForCase(item);',
    '    final timelineEntries = V2WorkspaceDataScope.of(context).timelineForCase(item);',
    'case timeline lookup',
)
preview = replace_once(
    preview,
    "                  '${entry.teacher} · ${entry.time}',",
    "                  entry.teacher.trim().isEmpty\n                      ? entry.time\n                      : '${entry.teacher} · ${entry.time}',",
    'timeline provenance rendering',
)

today_start = preview.index('class _TodayPane extends StatelessWidget {')
today_end = preview.index(
    '\nclass _TodayAction extends StatelessWidget {',
    today_start,
)
new_today = r'''class _TodayPane extends StatelessWidget {
  const _TodayPane({required this.onOpenCase, this.compact = false});

  final ValueChanged<V2FocusItem> onOpenCase;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final data = V2WorkspaceDataScope.of(context);
    final validItems = data.focusItems
        .where((item) => data.studentForFocusItemOrNull(item) != null)
        .toList(growable: false);
    final actionItems = validItems
        .where((item) => !item.pendingVerification)
        .take(4)
        .toList(growable: false);
    final verificationItems = validItems
        .where((item) => item.pendingVerification)
        .take(4)
        .toList(growable: false);

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
              Text(_todayLabel(), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 28),
              if (actionItems.isEmpty && verificationItems.isEmpty)
                Text(
                  '今天没有需要处理的学情事项',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              if (actionItems.isNotEmpty) ...[
                const _SectionTitle(title: '需要处理'),
                const SizedBox(height: 8),
                for (final item in actionItems)
                  _TodayAction(item: item, onOpenCase: onOpenCase),
              ],
              if (actionItems.isNotEmpty && verificationItems.isNotEmpty)
                const SizedBox(height: 28),
              if (verificationItems.isNotEmpty) ...[
                const _SectionTitle(title: '待验证'),
                const SizedBox(height: 10),
                for (final item in verificationItems)
                  _TodayAction(
                    item: item,
                    onOpenCase: onOpenCase,
                    verification: true,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _todayLabel() {
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  final now = DateTime.now();
  return '${now.month} 月 ${now.day} 日 · ${weekdays[now.weekday - 1]}';
}'''
preview = preview[:today_start] + new_today + preview[today_end:]

preview = replace_once(
    preview,
    '    final student = v2StudentForFocusItem(item);',
    "    final student = V2WorkspaceDataScope.of(context).studentForFocusItemOrNull(item);\n    if (student == null) {\n      return const SizedBox.shrink();\n    }",
    'today student lookup',
)

case_index_start = preview.index(
    'class _CaseIndexPaneState extends State<_CaseIndexPane> {'
)
case_index_end = preview.index(
    '\nclass _QuietPlaceholder extends StatelessWidget {',
    case_index_start,
)
new_case_index = r'''class _CaseIndexPaneState extends State<_CaseIndexPane> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<V2FocusItem> _visibleItems(V2WorkspaceData data) {
    final query = _query.trim().toLowerCase();
    final validItems = data.focusItems
        .where((item) => data.studentForFocusItemOrNull(item) != null)
        .toList(growable: false);
    if (query.isEmpty) {
      return validItems;
    }
    return validItems
        .where((item) {
          final student = data.studentForFocusItem(item);
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
    final data = V2WorkspaceDataScope.of(context);
    final visibleItems = _visibleItems(data);
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
                    ? '进行中 ${visibleItems.length}'
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
                    studentName: data.studentForFocusItem(item).name,
                    onTap: () => widget.onOpenCase(item),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyWorkspacePreview extends StatelessWidget {
  const _EmptyWorkspacePreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 34,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂时还没有可查看的学生',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '当你获得任课学生后，这里会自动出现。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}'''
preview = preview[:case_index_start] + new_case_index + preview[case_index_end:]

forbidden = [
    'v2Students',
    'v2FocusItemsForStudent',
    'v2StudentForFocusItem',
    'v2TimelineForStudent',
    'v2TimelineForCase',
    'v2FocusItems.take',
    'v2FocusItems[',
]
leftovers = [name for name in forbidden if name in preview]
if leftovers:
    raise SystemExit(f'global fixture dependencies remain in preview: {leftovers}')
preview_path.write_text(preview)

data = data_path.read_text()
data = replace_once(
    data,
    "  V2Student studentForFocusItem(V2FocusItem item) => students.firstWhere(\n    (student) => student.id == item.studentId,\n  );",
    "  V2Student? studentForFocusItemOrNull(V2FocusItem item) {\n    for (final student in students) {\n      if (student.id == item.studentId) {\n        return student;\n      }\n    }\n    return null;\n  }\n\n  V2Student studentForFocusItem(V2FocusItem item) {\n    final student = studentForFocusItemOrNull(item);\n    if (student == null) {\n      throw StateError('Focus item ${item.id} has no matching student.');\n    }\n    return student;\n  }",
    'safe student lookup',
)
data_path.write_text(data)

adapter = adapter_path.read_text()
adapter = replace_once(
    adapter,
    "            dueLabel: _dueLabel(primaryAction),\n            subject: profile.subject,",
    "            dueLabel: _dueLabel(primaryAction),\n            subject: profile.subject,\n            pendingVerification:\n                learningCase.status == LearningCaseStatus.pendingVerification,",
    'pending verification mapping',
)
adapter_path.write_text(adapter)

adapter_test = adapter_test_path.read_text()
adapter_test = replace_once(
    adapter_test,
    '            status: LearningCaseStatus.confirmed,',
    '            status: LearningCaseStatus.pendingVerification,',
    'pending verification fixture',
)
adapter_test = replace_once(
    adapter_test,
    "      expect(math.dueLabel, '待安排');",
    "      expect(math.dueLabel, '待安排');\n      expect(math.pendingVerification, isTrue);",
    'pending verification assertion',
)
adapter_test_path.write_text(adapter_test)

injection_test_path.write_text(r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_fixture.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_data.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  Widget app(V2WorkspaceData data) => MaterialApp(
    theme: V2Theme.light(),
    home: V2WorkspacePreview(data: data),
  );

  testWidgets('workspace renders injected data instead of global fixture', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(_injectedData));
    await tester.pumpAndSettle();

    expect(find.text('真实学生'), findsWidgets);
    expect(find.text('真实问题'), findsOneWidget);
    expect(find.text('林同学'), findsNothing);
    expect(find.text('全部 1'), findsOneWidget);
  });

  testWidgets('Today uses pending verification semantics from injected data', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(_injectedData));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('今日'));
    await tester.pumpAndSettle();

    expect(find.text('需要处理'), findsNothing);
    expect(find.text('待验证'), findsWidgets);
    expect(find.text('真实学生 · 语文'), findsOneWidget);

    await tester.tap(find.text('真实学生 · 语文'));
    await tester.pumpAndSettle();
    expect(find.text('成长过程'), findsOneWidget);
    expect(find.text('真实问题'), findsOneWidget);
  });

  testWidgets('empty workspace is a first-class state on desktop', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(_emptyData));
    await tester.pumpAndSettle();

    expect(find.text('暂时还没有可查看的学生'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty workspace is safe on compact layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(_emptyData));
    await tester.pumpAndSettle();

    expect(find.text('暂时还没有可查看的学生'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student without active Case keeps progress action disabled', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(_studentWithoutCases));
    await tester.pumpAndSettle();

    expect(find.text('暂无进行中的问题'), findsOneWidget);
    final progressButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '记进展'),
    );
    expect(progressButton.onPressed, isNull);
  });

  testWidgets('unknown historical author renders time without fake separator', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(_injectedData));
    await tester.pumpAndSettle();
    await tester.tap(find.text('真实问题'));
    await tester.pumpAndSettle();

    expect(find.text('18:31'), findsOneWidget);
    expect(find.text(' · 18:31'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

const _injectedData = V2WorkspaceData(
  students: [
    V2Student(
      id: 'real-student',
      name: '真实学生',
      grade: '初三',
      subjects: ['语文'],
      openCaseCount: 1,
      updatedLabel: '已有更新',
      teacherSummary: '当前工作区 · 语文',
    ),
  ],
  focusItems: [
    V2FocusItem(
      id: 'real-case',
      studentId: 'real-student',
      title: '真实问题',
      summary: '这是由注入数据提供的问题摘要。',
      nextStep: '下次课验证',
      dueLabel: '9 月 12 日',
      subject: '语文',
      pendingVerification: true,
    ),
  ],
  timeline: [
    V2TimelineEntry(
      caseId: 'real-case',
      date: '今天',
      kind: '检查结果',
      body: '真实时间线内容。',
      teacher: '',
      time: '18:31',
    ),
  ],
);

const _emptyData = V2WorkspaceData(
  students: [],
  focusItems: [],
  timeline: [],
);

const _studentWithoutCases = V2WorkspaceData(
  students: [
    V2Student(
      id: 'quiet-student',
      name: '暂无问题学生',
      grade: '初一',
      subjects: ['数学'],
      openCaseCount: 0,
      updatedLabel: '暂无记录',
      teacherSummary: '当前工作区 · 数学',
    ),
  ],
  focusItems: [],
  timeline: [],
);
''')
