from pathlib import Path

SOURCE = Path('lib/features/design_v2/v2_workspace_preview.dart')
TEST = Path('test/features/v2_learning_desktop_composition_test.dart')
WORKFLOW = Path('.github/workflows/quiet-professional-learning-desktop-v7.yml')
SCRIPT = Path('.github/scripts/quiet_professional_learning_v7.py')

source = SOURCE.read_text()

# Keep the outer desktop breakpoint as the single source of truth.
desktop_start = source.index('class _DesktopWorkspace extends StatelessWidget')
desktop_end = source.index('class _MediumWorkspace extends StatefulWidget', desktop_start)
desktop = source[desktop_start:desktop_end]
needle = '''            ] else if (destination == V2WorkspaceDestination.learning) ...[\n              Expanded(child: _CaseIndexPane(onOpenCase: onOpenCase)),\n            ] else ...['''
replacement = '''            ] else if (destination == V2WorkspaceDestination.learning) ...[\n              Expanded(\n                child: _CaseIndexPane(\n                  onOpenCase: onOpenCase,\n                  wideDesktop: expandedRail,\n                ),\n              ),\n            ] else ...['''
assert desktop.count(needle) == 1, 'desktop learning call changed unexpectedly'
desktop = desktop.replace(needle, replacement, 1)
source = source[:desktop_start] + desktop + source[desktop_end:]

case_start = source.index('class _CaseIndexPane extends StatefulWidget')
case_end = source.index('class _V2OperationGuide extends StatelessWidget', case_start)
new_case = r'''class _CaseIndexPane extends StatefulWidget {
  const _CaseIndexPane({
    required this.onOpenCase,
    this.compact = false,
    this.wideDesktop = false,
    this.onOpenMore,
  });

  final ValueChanged<V2FocusItem> onOpenCase;
  final bool compact;
  final bool wideDesktop;
  final VoidCallback? onOpenMore;

  @override
  State<_CaseIndexPane> createState() => _CaseIndexPaneState();
}

class _CaseIndexPaneState extends State<_CaseIndexPane> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _showClosed = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<V2FocusItem> _visibleItems(V2WorkspaceData data) {
    final query = _query.trim().toLowerCase();
    final sourceItems = _showClosed ? data.closedItems : data.focusItems;
    final validItems = sourceItems
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

  Widget _filters(BuildContext context, List<V2FocusItem> visibleItems) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const Key('v2-learning-filters'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          key: const Key('v2-case-history-toggle'),
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(value: false, label: Text('跟进中')),
            ButtonSegment<bool>(value: true, label: Text('历史')),
          ],
          selected: <bool>{_showClosed},
          onSelectionChanged: (selection) {
            setState(() {
              _showClosed = selection.first;
              _query = '';
              _searchController.clear();
            });
          },
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 8),
        Text(
          _query.trim().isEmpty
              ? (_showClosed
                    ? '历史 ${visibleItems.length}'
                    : '进行中 ${visibleItems.length}')
              : '找到 ${visibleItems.length} 个问题',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _results(
    BuildContext context,
    V2WorkspaceData data,
    List<V2FocusItem> visibleItems,
  ) {
    return Column(
      key: const Key('v2-learning-results'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.wideDesktop) ...[
          _SectionTitle(
            title: _showClosed ? '历史问题' : '需要跟进',
            count: visibleItems.length,
          ),
          const SizedBox(height: 8),
        ],
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = V2WorkspaceDataScope.of(context);
    final visibleItems = _visibleItems(data);
    final scheme = Theme.of(context).colorScheme;
    final filters = _filters(context, visibleItems);
    final results = _results(context, data, visibleItems);

    return SingleChildScrollView(
      padding: EdgeInsets.all(
        widget.compact ? AppSpacing.mdPlus : AppSpacing.xl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.wideDesktop ? 1120 : 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              V2PageHeader(
                key: const Key('v2-learning-page-header'),
                title: '学情',
                description: _showClosed ? '回看已经结束的跟进记录' : '找到仍需要复盘的问题',
                actions: [
                  if (widget.compact && widget.onOpenMore != null)
                    IconButton(
                      key: const Key('v2-compact-more'),
                      tooltip: '更多操作',
                      onPressed: widget.onOpenMore,
                      icon: const Icon(Icons.more_vert),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (widget.wideDesktop)
                Row(
                  key: const Key('v2-learning-desktop-columns'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 292,
                      child: Container(
                        key: const Key('v2-learning-filter-column'),
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: scheme.outlineVariant),
                          ),
                        ),
                        child: filters,
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      key: const Key('v2-learning-primary-column'),
                      child: results,
                    ),
                  ],
                )
              else
                Column(
                  key: const Key('v2-learning-stacked-content'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    filters,
                    const SizedBox(height: 6),
                    results,
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

'''
source = source[:case_start] + new_case + source[case_end:]
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

  Future<void> openLearning(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
    bool dark = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(app(textScale: textScale, dark: dark));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('学情'));
    await tester.pumpAndSettle();
  }

  testWidgets('learning stays stacked below expanded desktop breakpoint', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openLearning(tester, const Size(1024, 720));

    expect(find.byKey(const Key('v2-learning-stacked-content')), findsOneWidget);
    expect(find.byKey(const Key('v2-learning-desktop-columns')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('learning separates filters from results on wide desktop', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openLearning(tester, const Size(1440, 800));

    final filters = find.byKey(const Key('v2-learning-filter-column'));
    final results = find.byKey(const Key('v2-learning-primary-column'));
    expect(find.byKey(const Key('v2-learning-desktop-columns')), findsOneWidget);
    expect(filters, findsOneWidget);
    expect(results, findsOneWidget);
    expect(tester.getTopLeft(results).dx, greaterThan(tester.getTopLeft(filters).dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('learning wide desktop survives dark mode and 200 percent text', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openLearning(
      tester,
      const Size(1440, 800),
      textScale: 2,
      dark: true,
    );

    expect(find.byKey(const Key('v2-learning-desktop-columns')), findsOneWidget);
    expect(find.byKey(const Key('v2-learning-filter-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
''')

# One-shot staging artifacts must not survive the verified product commit.
if WORKFLOW.exists():
    WORKFLOW.unlink()
if SCRIPT.exists():
    SCRIPT.unlink()
