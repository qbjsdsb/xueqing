from pathlib import Path

workspace_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
text = workspace_path.read_text(encoding='utf-8')

helper_marker = "typedef V2WorkspaceRefresh = Future<void> Function();\n"
helper = r'''

const int _studentFocusPreviewLimit = 3;

String _visualContentKey(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(
      RegExp('[\\s，。！？、；：,.!?;:"“”‘’（）()\\[\\]【】《》—–\\-·…]+'),
      '',
    );

bool _shouldShowCaseSummary(V2FocusItem item) {
  final summary = item.summary.trim();
  if (summary.isEmpty) return false;
  return _visualContentKey(summary) != _visualContentKey(item.title);
}

String _displayNextStep(String value) {
  final trimmed = value.trim();
  if (_visualContentKey(trimmed) == _visualContentKey('待安排下一步')) {
    return '待安排';
  }
  return trimmed;
}
'''
if '_studentFocusPreviewLimit' not in text:
    if helper_marker not in text:
        raise SystemExit('workspace helper marker not found')
    text = text.replace(helper_marker, helper_marker + helper, 1)

start = text.index('class _StudentDetailPane extends StatelessWidget {')
end = text.index('\nclass _StudentHeader extends StatelessWidget {', start)
new_student_detail = r'''class _StudentDetailPane extends StatefulWidget {
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
  State<_StudentDetailPane> createState() => _StudentDetailPaneState();
}

class _StudentDetailPaneState extends State<_StudentDetailPane> {
  bool _showAllFocusItems = false;

  @override
  void didUpdateWidget(covariant _StudentDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student.id != widget.student.id) {
      _showAllFocusItems = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = V2WorkspaceDataScope.of(context);
    final focusItems = data.focusItemsForStudent(widget.student);
    final visibleFocusItems = _showAllFocusItems
        ? focusItems
        : focusItems.take(_studentFocusPreviewLimit).toList(growable: false);
    final hasAdditionalFocusItems =
        focusItems.length > _studentFocusPreviewLimit;
    final closedItems = data.closedItemsForStudent(widget.student);
    final timelineEntries = data.timelineForStudent(widget.student);
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
                    widget.compact ? 18 : 32,
                    22,
                    widget.compact ? 18 : 32,
                    48,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.onBack != null) ...[
                        IconButton(
                          tooltip: '返回学生列表',
                          onPressed: widget.onBack,
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(height: 4),
                      ],
                      _StudentHeader(
                        student: widget.student,
                        compact: widget.compact,
                      ),
                      const SizedBox(height: 30),
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
                        for (var i = 0; i < visibleFocusItems.length; i++) ...[
                          _FocusRow(
                            item: visibleFocusItems[i],
                            onTap: () =>
                                widget.onOpenCase(visibleFocusItems[i]),
                          ),
                          if (i < visibleFocusItems.length - 1)
                            Divider(height: 1, color: scheme.outlineVariant),
                        ],
                        if (hasAdditionalFocusItems) ...[
                          const SizedBox(height: 6),
                          TextButton.icon(
                            key: const Key('v2-student-focus-toggle'),
                            onPressed: () => setState(
                              () => _showAllFocusItems = !_showAllFocusItems,
                            ),
                            icon: Icon(
                              _showAllFocusItems
                                  ? Icons.expand_less
                                  : Icons.expand_more,
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
                        const SizedBox(height: 34),
                        _SectionTitle(title: '历史问题', count: closedItems.length),
                        const SizedBox(height: 8),
                        for (var i = 0; i < closedItems.length; i++) ...[
                          _FocusRow(
                            item: closedItems[i],
                            onTap: () => widget.onOpenCase(closedItems[i]),
                          ),
                          if (i < closedItems.length - 1)
                            Divider(height: 1, color: scheme.outlineVariant),
                        ],
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
'''
text = text[:start] + new_student_detail + text[end:]

old_focus = r'''                  Text(
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
                    item.closed ? item.nextStep : '下一步  ${item.nextStep}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),'''
new_focus = r'''                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_shouldShowCaseSummary(item)) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.summary,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    item.closed
                        ? _displayNextStep(item.nextStep)
                        : '下一步  ${_displayNextStep(item.nextStep)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),'''
if old_focus not in text:
    raise SystemExit('focus row summary block not found')
text = text.replace(old_focus, new_focus, 1)

old_detail = r'''                  const SizedBox(height: 8),
                  Text(
                    item.summary,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),'''
new_detail = r'''                  if (_shouldShowCaseSummary(item)) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.summary,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                  const SizedBox(height: 28),'''
if old_detail not in text:
    raise SystemExit('case detail summary block not found')
text = text.replace(old_detail, new_detail, 1)

old_detail_next = r'''                        child: Text(
                          item.nextStep,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),'''
new_detail_next = r'''                        child: Text(
                          _displayNextStep(item.nextStep),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),'''
if old_detail_next not in text:
    raise SystemExit('case detail next-step block not found')
text = text.replace(old_detail_next, new_detail_next, 1)

workspace_path.write_text(text, encoding='utf-8')

test_path = Path('test/features/v2_student_focus_presentation_test.dart')
test_path.write_text(r'''import 'package:flutter/material.dart';
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

  V2WorkspaceData dataWith(List<V2FocusItem> items) => V2WorkspaceData(
    students: [
      V2Student(
        id: 'student-1',
        name: '测试学生',
        grade: '初三',
        subjects: const ['语文'],
        openCaseCount: items.length,
        updatedLabel: '已有更新',
        teacherSummary: '当前工作区 · 语文',
      ),
    ],
    focusItems: items,
    timeline: const [],
  );

  testWidgets('student focus hides visually duplicated summary and concise next step', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final data = dataWith(const [
      V2FocusItem(
        id: 'duplicate-case',
        studentId: 'student-1',
        title: '文言文翻译还得加强，测试不过关',
        summary: '  文言文翻译还得加强，测试不过关。 ',
        nextStep: '待安排下一步',
        dueLabel: '待安排',
        subject: '语文',
      ),
    ]);

    await tester.pumpWidget(app(data));
    await tester.pumpAndSettle();

    expect(find.text('文言文翻译还得加强，测试不过关'), findsOneWidget);
    expect(find.text('  文言文翻译还得加强，测试不过关。 '), findsNothing);
    expect(find.text('下一步  待安排'), findsOneWidget);
    expect(find.text('下一步  待安排下一步'), findsNothing);
  });

  testWidgets('student focus keeps a genuinely different summary', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final data = dataWith(const [
      V2FocusItem(
        id: 'distinct-case',
        studentId: 'student-1',
        title: '不太会',
        summary: '还行，但独立完成时不稳定',
        nextStep: '再次测试',
        dueLabel: '待安排',
        subject: '语文',
      ),
    ]);

    await tester.pumpWidget(app(data));
    await tester.pumpAndSettle();

    expect(find.text('不太会'), findsOneWidget);
    expect(find.text('还行，但独立完成时不稳定'), findsOneWidget);
  });

  testWidgets('student detail shows three priorities before expanding all', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final data = dataWith([
      for (var index = 1; index <= 4; index++)
        V2FocusItem(
          id: 'case-$index',
          studentId: 'student-1',
          title: '当前问题 $index',
          summary: '补充说明 $index',
          nextStep: '跟进 $index',
          dueLabel: '待安排',
          subject: '语文',
        ),
    ]);

    await tester.pumpWidget(app(data));
    await tester.pumpAndSettle();

    expect(find.text('现在最重要'), findsOneWidget);
    expect(find.text('当前问题 1'), findsOneWidget);
    expect(find.text('当前问题 2'), findsOneWidget);
    expect(find.text('当前问题 3'), findsOneWidget);
    expect(find.text('当前问题 4'), findsNothing);
    expect(find.text('查看全部 4 个'), findsOneWidget);

    await tester.tap(find.text('查看全部 4 个'));
    await tester.pumpAndSettle();

    expect(find.text('全部问题'), findsOneWidget);
    expect(find.text('当前问题 4'), findsOneWidget);
    expect(find.text('只看重点'), findsOneWidget);

    await tester.tap(find.text('只看重点'));
    await tester.pumpAndSettle();
    expect(find.text('当前问题 4'), findsNothing);
    expect(find.text('现在最重要'), findsOneWidget);
  });
}
''', encoding='utf-8')
