from pathlib import Path
from textwrap import dedent

SOURCE = Path("lib/features/design_v2/v2_workspace_preview.dart")
TEST = Path("test/features/v2_today_desktop_composition_test.dart")

source = SOURCE.read_text()

# The expanded desktop decision already belongs to the outer workspace.
# Pass that authoritative state down instead of inventing another width gate.
desktop_start = source.index("class _DesktopWorkspace")
desktop_today = source.index("child: _TodayPane(", desktop_start)
insert_at = source.index("\n", desktop_today) + 1
nearby = source[desktop_today : desktop_today + 500]
assert "wideDesktop:" not in nearby
source = (
    source[:insert_at]
    + "                  wideDesktop: expandedRail,\n"
    + source[insert_at:]
)

today_start = source.index("class _TodayPane")
return_start = source.index("    return SingleChildScrollView(", today_start)
label_start = source.index("String _todayLabel", return_start)
prefix = source[today_start:return_start]

old_constructor = """    this.compact = false,
    this.onOpenMore,"""
new_constructor = """    this.compact = false,
    this.wideDesktop = false,
    this.onOpenMore,"""
assert prefix.count(old_constructor) == 1
prefix = prefix.replace(old_constructor, new_constructor, 1)

old_fields = """  final bool compact;
  final VoidCallback? onOpenMore;"""
new_fields = """  final bool compact;
  final bool wideDesktop;
  final VoidCallback? onOpenMore;"""
assert prefix.count(old_fields) == 1
prefix = prefix.replace(old_fields, new_fields, 1)

replacement = r'''    final recentStudentSelection = (recentStudents.isEmpty
        ? data.students.take(5)
        : recentStudents.take(5)).toList(growable: false);
    final primary = _TodayPrimarySections(
      currentItems: currentItems,
      undatedItems: undatedItems,
      futureItems: futureItems,
      onOpenCase: onOpenCase,
    );
    final recent = _TodayRecentStudentsSection(
      students: recentStudentSelection,
      showRecentActivity: recentStudents.isNotEmpty,
      businessDate: data.businessDate,
      onOpenStudent: onOpenStudent,
    );
    final useDesktopColumns = wideDesktop && data.students.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? AppSpacing.mdPlus : AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 900 : 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              V2PageHeader(
                key: const Key('v2-today-page-header'),
                title: '今日',
                meta: _todayLabel(data.businessDate),
                actions: [
                  TextButton.icon(
                    key: const Key('v2-today-quick-capture'),
                    onPressed: () => _showV2QuickCaptureStudentPicker(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('记录问题'),
                  ),
                  if (compact && onOpenMore != null)
                    IconButton(
                      key: const Key('v2-compact-more'),
                      tooltip: '更多操作',
                      onPressed: onOpenMore,
                      icon: const Icon(Icons.more_vert),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (useDesktopColumns)
                Row(
                  key: const Key('v2-today-desktop-columns'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      key: const Key('v2-today-primary-column'),
                      child: primary,
                    ),
                    const SizedBox(width: 32),
                    SizedBox(
                      width: 296,
                      child: Container(
                        key: const Key('v2-today-recent-column'),
                        padding: const EdgeInsets.only(left: 24),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        child: recent,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  key: const Key('v2-today-stacked-content'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    primary,
                    if (data.students.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Divider(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 14),
                      KeyedSubtree(
                        key: const Key('v2-today-recent-stacked'),
                        child: recent,
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayPrimarySections extends StatelessWidget {
  const _TodayPrimarySections({
    required this.currentItems,
    required this.undatedItems,
    required this.futureItems,
    required this.onOpenCase,
  });

  final List<V2FocusItem> currentItems;
  final List<V2FocusItem> undatedItems;
  final List<V2FocusItem> futureItems;
  final ValueChanged<V2FocusItem> onOpenCase;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentItems.isEmpty && undatedItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '今天没有待处理事项',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '已经安排的跟进都处理好了。需要时可以继续查看学生或记录新问题。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (currentItems.isNotEmpty) ...[
          _SectionTitle(title: '现在要做', count: currentItems.length),
          const SizedBox(height: 8),
          for (final item in currentItems)
            _TodayAction(item: item, onOpenCase: onOpenCase),
        ],
        if (currentItems.isNotEmpty && undatedItems.isNotEmpty)
          const SizedBox(height: 24),
        if (undatedItems.isNotEmpty) ...[
          _SectionTitle(title: '待安排', count: undatedItems.length),
          const SizedBox(height: 6),
          Text(
            '这些提醒已经明确，只差安排日期。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          for (final item in undatedItems)
            _TodayAction(item: item, onOpenCase: onOpenCase),
        ],
        if (futureItems.isNotEmpty) ...[
          const SizedBox(height: 24),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          ExpansionTile(
            key: const Key('v2-today-future-section'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('之后'),
            subtitle: Text('${futureItems.length} 项已安排的后续行动'),
            children: [
              for (final item in futureItems)
                _TodayAction(item: item, onOpenCase: onOpenCase),
            ],
          ),
        ],
      ],
    );
  }
}

class _TodayRecentStudentsSection extends StatelessWidget {
  const _TodayRecentStudentsSection({
    required this.students,
    required this.showRecentActivity,
    required this.businessDate,
    required this.onOpenStudent,
  });

  final List<V2Student> students;
  final bool showRecentActivity;
  final DateTime? businessDate;
  final ValueChanged<V2Student> onOpenStudent;

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: showRecentActivity ? '最近学生' : '我的学生'),
        const SizedBox(height: 8),
        for (final student in students)
          _TodayRecentStudentRow(
            student: student,
            businessDate: businessDate,
            onTap: () => onOpenStudent(student),
          ),
      ],
    );
  }
}

'''

source = source[:today_start] + prefix + replacement + source[label_start:]
assert source.count("wideDesktop: expandedRail,") == 1
assert source.count("final bool wideDesktop;") == 1
assert source.count("wideDesktop && data.students.isNotEmpty") == 1
assert "constraints.maxWidth >= 960" not in source[today_start:label_start]
SOURCE.write_text(source)

TEST.write_text(
    dedent(
        r'''
        import 'package:flutter/material.dart';
        import 'package:flutter_test/flutter_test.dart';
        import 'package:xueqing/features/design_v2/v2_theme.dart';
        import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

        void main() {
          Widget app({double textScale = 1, bool dark = false}) => MaterialApp(
            theme: dark ? V2Theme.dark() : V2Theme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: const V2WorkspacePreview(),
          );

          Future<void> pumpAt(
            WidgetTester tester,
            Size size, {
            double textScale = 1,
            bool dark = false,
          }) async {
            await tester.binding.setSurfaceSize(size);
            await tester.pumpWidget(app(textScale: textScale, dark: dark));
            await tester.pumpAndSettle();
          }

          testWidgets('Today stays stacked below the expanded desktop breakpoint', (
            tester,
          ) async {
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await pumpAt(tester, const Size(1024, 720));

            expect(find.byKey(const Key('v2-today-stacked-content')), findsOneWidget);
            expect(find.byKey(const Key('v2-today-desktop-columns')), findsNothing);
            expect(find.byKey(const Key('v2-today-recent-stacked')), findsOneWidget);
            expect(tester.takeException(), isNull);
          });

          testWidgets('Today promotes recent students to a wide desktop side column', (
            tester,
          ) async {
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await pumpAt(tester, const Size(1440, 800));

            final primary = find.byKey(const Key('v2-today-primary-column'));
            final recent = find.byKey(const Key('v2-today-recent-column'));
            expect(find.byKey(const Key('v2-today-desktop-columns')), findsOneWidget);
            expect(primary, findsOneWidget);
            expect(recent, findsOneWidget);
            expect(find.byKey(const Key('v2-today-recent-stacked')), findsNothing);
            expect(
              tester.getTopLeft(recent).dx,
              greaterThan(tester.getTopLeft(primary).dx),
            );
            expect(tester.takeException(), isNull);
          });

          testWidgets('Today wide desktop remains stable in dark mode at 200 percent text', (
            tester,
          ) async {
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await pumpAt(
              tester,
              const Size(1440, 800),
              textScale: 2,
              dark: true,
            );

            expect(find.byKey(const Key('v2-today-desktop-columns')), findsOneWidget);
            expect(find.byKey(const Key('v2-today-recent-column')), findsOneWidget);
            expect(tester.takeException(), isNull);
          });
        }
        '''
    ).lstrip()
)
