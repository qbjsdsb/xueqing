from pathlib import Path

SOURCE = Path('lib/features/design_v2/v2_workspace_preview.dart')
TEST = Path('test/features/v2_student_desktop_composition_test.dart')
WORKFLOW = Path('.github/workflows/quiet-professional-student-desktop-v6.yml')
SCRIPT = Path('.github/scripts/quiet_professional_student_v6.py')

source = SOURCE.read_text()

# The outer desktop LayoutBuilder is the only authority for wide desktop state.
desktop_start = source.index('class _DesktopWorkspace extends StatelessWidget')
desktop_end = source.index('class _MediumWorkspace extends StatefulWidget', desktop_start)
desktop = source[desktop_start:desktop_end]
needle = '''                      : _StudentDetailPane(\n                          student: selectedStudent,\n                          onOpenCase: onOpenCase,\n                        ),'''
replacement = '''                      : _StudentDetailPane(\n                          student: selectedStudent,\n                          onOpenCase: onOpenCase,\n                          wideDesktop: expandedRail,\n                        ),'''
assert desktop.count(needle) == 1, 'desktop student detail call changed unexpectedly'
desktop = desktop.replace(needle, replacement, 1)
source = source[:desktop_start] + desktop + source[desktop_end:]

student_start = source.index('class _StudentDetailPane extends StatefulWidget')
student_end = source.index('class _StudentHeader extends StatelessWidget', student_start)
new_student = r'''class _StudentDetailPane extends StatefulWidget {
  const _StudentDetailPane({
    required this.student,
    required this.onOpenCase,
    this.compact = false,
    this.wideDesktop = false,
    this.onBack,
  });

  final V2Student student;
  final ValueChanged<V2FocusItem> onOpenCase;
  final bool compact;
  final bool wideDesktop;
  final VoidCallback? onBack;

  @override
  State<_StudentDetailPane> createState() => _StudentDetailPaneState();
}

class _StudentDetailPaneState extends State<_StudentDetailPane> {
  bool _showAllFocusItems = false;
  bool _showAllTimeline = false;
  bool _showClosedItems = false;

  @override
  void didUpdateWidget(covariant _StudentDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student.id != widget.student.id) {
      _showAllFocusItems = false;
      _showAllTimeline = false;
      _showClosedItems = false;
    }
  }

  Widget _focusSection(
    BuildContext context, {
    required List<V2FocusItem> focusItems,
    required List<V2FocusItem> visibleFocusItems,
    required bool hasAdditionalFocusItems,
    required List<V2FocusItem> closedItems,
  }) {
    return Column(
      key: const Key('v2-student-current-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: _showAllFocusItems ? '全部问题' : '现在最重要',
          count: visibleFocusItems.length,
        ),
        const SizedBox(height: 8),
        if (focusItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              '暂无进行中的问题',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else ...[
          for (final item in visibleFocusItems)
            _FocusRow(item: item, onTap: () => widget.onOpenCase(item)),
          if (hasAdditionalFocusItems) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              key: const Key('v2-student-focus-toggle'),
              onPressed: () => setState(
                () => _showAllFocusItems = !_showAllFocusItems,
              ),
              icon: Icon(
                _showAllFocusItems ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(
                _showAllFocusItems
                    ? '只看重点'
                    : '查看全部 ${focusItems.length} 个',
              ),
            ),
          ],
        ],
        if (closedItems.isNotEmpty) ...[
          const SizedBox(height: 26),
          TextButton.icon(
            key: const Key('v2-student-history-toggle'),
            onPressed: () => setState(() => _showClosedItems = !_showClosedItems),
            icon: Icon(
              _showClosedItems ? Icons.expand_less : Icons.history_outlined,
              size: 18,
            ),
            label: Text(
              _showClosedItems
                  ? '收起历史问题'
                  : '查看历史问题 ${closedItems.length} 个',
            ),
          ),
          if (_showClosedItems) ...[
            const SizedBox(height: 8),
            _SectionTitle(title: '历史问题', count: closedItems.length),
            const SizedBox(height: 8),
            for (final item in closedItems)
              _FocusRow(item: item, onTap: () => widget.onOpenCase(item)),
          ],
        ],
      ],
    );
  }

  Widget _growthSection(
    BuildContext context, {
    required List<V2TimelineEntry> timelineEntries,
    required List<V2TimelineEntry> visibleTimelineEntries,
    required int hiddenTimelineCount,
  }) {
    return Column(
      key: const Key('v2-student-growth-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: '最近成长', count: timelineEntries.length),
        const SizedBox(height: 14),
        _Timeline(entries: visibleTimelineEntries),
        if (hiddenTimelineCount > 0) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            key: const Key('v2-student-timeline-toggle'),
            onPressed: () => setState(() => _showAllTimeline = !_showAllTimeline),
            icon: Icon(
              _showAllTimeline ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(
              _showAllTimeline
                  ? '收起更早记录'
                  : '查看更早 $hiddenTimelineCount 条',
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = V2WorkspaceDataScope.of(context);
    final focusItems = data.focusItemsForStudent(widget.student);
    final visibleFocusItems = _showAllFocusItems
        ? focusItems
        : focusItems.take(_studentFocusPreviewLimit).toList(growable: false);
    final hasAdditionalFocusItems = focusItems.length > _studentFocusPreviewLimit;
    final closedItems = data.closedItemsForStudent(widget.student);
    final timelineEntries = data.timelineForStudent(widget.student);
    final visibleTimelineEntries = _showAllTimeline
        ? timelineEntries
        : timelineEntries.take(5).toList(growable: false);
    final hiddenTimelineCount = timelineEntries.length > 5
        ? timelineEntries.length - 5
        : 0;

    final current = _focusSection(
      context,
      focusItems: focusItems,
      visibleFocusItems: visibleFocusItems,
      hasAdditionalFocusItems: hasAdditionalFocusItems,
      closedItems: closedItems,
    );
    final growth = _growthSection(
      context,
      timelineEntries: timelineEntries,
      visibleTimelineEntries: visibleTimelineEntries,
      hiddenTimelineCount: hiddenTimelineCount,
    );

    return ColoredBox(
      color: scheme.surface,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: widget.wideDesktop ? 1080 : 900,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    widget.compact ? 18 : 32,
                    22,
                    widget.compact ? 18 : 32,
                    48,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StudentHeader(
                        student: widget.student,
                        compact: widget.compact,
                        onBack: widget.onBack,
                      ),
                      const SizedBox(height: 30),
                      if (widget.wideDesktop)
                        Row(
                          key: const Key('v2-student-desktop-columns'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              key: const Key('v2-student-primary-column'),
                              child: current,
                            ),
                            const SizedBox(width: 32),
                            SizedBox(
                              width: 296,
                              child: Container(
                                key: const Key('v2-student-growth-column'),
                                padding: const EdgeInsets.only(left: 24),
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(color: scheme.outlineVariant),
                                  ),
                                ),
                                child: growth,
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          key: const Key('v2-student-stacked-sections'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            current,
                            const SizedBox(height: 34),
                            Divider(color: scheme.outlineVariant),
                            const SizedBox(height: 20),
                            growth,
                          ],
                        ),
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

'''
source = source[:student_start] + new_student + source[student_end:]
SOURCE.write_text(source)

TEST.write_text(r'''import 'package:flutter/material.dart';
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

  Future<void> openFirstStudent(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
    bool dark = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(app(textScale: textScale, dark: dark));
    await tester.pumpAndSettle();
    await tester.tap(find.text('学生').first);
    await tester.pumpAndSettle();
  }

  testWidgets('student detail stays stacked below expanded desktop breakpoint', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openFirstStudent(tester, const Size(1024, 720));

    expect(find.byKey(const Key('v2-student-stacked-sections')), findsOneWidget);
    expect(find.byKey(const Key('v2-student-desktop-columns')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student detail separates current work and growth on wide desktop', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openFirstStudent(tester, const Size(1440, 800));

    final primary = find.byKey(const Key('v2-student-primary-column'));
    final growth = find.byKey(const Key('v2-student-growth-column'));
    expect(find.byKey(const Key('v2-student-desktop-columns')), findsOneWidget);
    expect(primary, findsOneWidget);
    expect(growth, findsOneWidget);
    expect(tester.getTopLeft(growth).dx, greaterThan(tester.getTopLeft(primary).dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('student wide desktop survives dark mode and 200 percent text', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openFirstStudent(
      tester,
      const Size(1440, 800),
      textScale: 2,
      dark: true,
    );

    expect(find.byKey(const Key('v2-student-desktop-columns')), findsOneWidget);
    expect(find.byKey(const Key('v2-student-growth-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
''')

# One-shot staging artifacts must not survive the verified product commit.
if WORKFLOW.exists():
    WORKFLOW.unlink()
if SCRIPT.exists():
    SCRIPT.unlink()
