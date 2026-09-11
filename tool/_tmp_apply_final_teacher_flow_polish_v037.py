from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


composers_path = Path('lib/features/design_v2/v2_composers.dart')
composers = composers_path.read_text()

old_row = """            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[index].title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _existingCaseMeta(items[index]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    key: ValueKey<String>(
                      'v2-quick-capture-existing-${items[index].id}',
                    ),
                    onPressed: canContinue
                        ? () => onContinue(items[index])
                        : null,
                    child: const Text('记到这个问题'),
                  ),
                ],
              ),
            ),
"""
new_row = """            _ExistingCaseContinuationRow(
              item: items[index],
              meta: _existingCaseMeta(items[index]),
              canContinue: canContinue,
              onContinue: onContinue,
            ),
"""
composers = replace_once(
    composers,
    old_row,
    new_row,
    'existing case continuation row',
)

insert_marker = "\nclass V2ProgressComposer extends StatefulWidget {\n"
new_class = r'''
class _ExistingCaseContinuationRow extends StatelessWidget {
  const _ExistingCaseContinuationRow({
    required this.item,
    required this.meta,
    required this.canContinue,
    required this.onContinue,
  });

  final V2ExistingCaseOption item;
  final String meta;
  final bool canContinue;
  final ValueChanged<V2ExistingCaseOption> onContinue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          meta,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
    final action = TextButton(
      key: ValueKey<String>('v2-quick-capture-existing-${item.id}'),
      onPressed: canContinue ? () => onContinue(item) : null,
      child: const Text('记到这个问题'),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: 4),
                action,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 8),
              action,
            ],
          );
        },
      ),
    );
  }
}
'''
composers = replace_once(
    composers,
    insert_marker,
    '\n' + new_class + insert_marker,
    'insert responsive existing case row',
)

old_scroll = """            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
"""
new_scroll = """            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
"""
composers = replace_once(
    composers,
    old_scroll,
    new_scroll,
    'composer drag-to-dismiss keyboard',
)
composers_path.write_text(composers)

workspace_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
workspace = workspace_path.read_text()

old_header = r'''              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今日',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _todayLabel(data.businessDate),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '先处理已经安排好的跟进。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    key: const Key('v2-today-quick-capture'),
                    onPressed: () => _showV2QuickCaptureStudentPicker(context),
                    icon: const Icon(Icons.note_add_outlined, size: 18),
                    label: const Text('记录问题'),
                  ),
                  if (compact && onOpenMore != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      key: const Key('v2-compact-more'),
                      tooltip: '更多操作',
                      onPressed: onOpenMore,
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
                ],
              ),
'''
new_header = r'''              LayoutBuilder(
                builder: (context, constraints) {
                  final copy = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '今日',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _todayLabel(data.businessDate),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '先处理已经安排好的跟进。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  );
                  final quickCapture = FilledButton.tonalIcon(
                    key: const Key('v2-today-quick-capture'),
                    onPressed: () => _showV2QuickCaptureStudentPicker(context),
                    icon: const Icon(Icons.note_add_outlined, size: 18),
                    label: const Text('记录问题'),
                  );
                  final more = compact && onOpenMore != null
                      ? IconButton(
                          key: const Key('v2-compact-more'),
                          tooltip: '更多操作',
                          onPressed: onOpenMore,
                          icon: const Icon(Icons.more_vert),
                        )
                      : null;
                  final stackActions = compact && constraints.maxWidth < 440;
                  if (stackActions) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: copy),
                            if (more != null) ...[
                              const SizedBox(width: 4),
                              more,
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                        quickCapture,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: copy),
                      const SizedBox(width: 12),
                      quickCapture,
                      if (more != null) ...[
                        const SizedBox(width: 4),
                        more,
                      ],
                    ],
                  );
                },
              ),
'''
workspace = replace_once(
    workspace,
    old_header,
    new_header,
    'responsive Today header',
)

start = workspace.index('class _TodayAction extends StatelessWidget {')
end = workspace.index('\nString _todayActionStatus', start)
old_today_action = workspace[start:end]
new_today_action = r'''class _TodayAction extends StatelessWidget {
  const _TodayAction({required this.item, required this.onOpenCase});

  final V2FocusItem item;
  final ValueChanged<V2FocusItem> onOpenCase;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final student = V2WorkspaceDataScope.of(context)
        .studentForFocusItemOrNull(item);
    if (student == null) return const SizedBox.shrink();
    final controller = _V2RuntimeScope.maybeOf(context)?.workflowController;
    final pendingAction = controller?.pendingActionFor(item.id);
    final actionTitle = pendingAction?.title.trim().isNotEmpty == true
        ? pendingAction!.title.trim()
        : _displayNextStep(item.nextStep);
    final status = _todayActionStatus(item);
    return LayoutBuilder(
      builder: (context, constraints) {
        final showStatusInline = constraints.maxWidth < 520;
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onOpenCase(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 2,
                  height: 62,
                  color: item.actionTiming == V2ActionTiming.overdue
                      ? const Color(0xFFB77728)
                      : scheme.primary,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actionTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${student.name} · ${item.subject}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.pendingVerification
                            ? '${item.title} · 待复检'
                            : item.title,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (showStatusInline && status.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          status,
                          key: ValueKey<String>(
                            'v2-today-inline-status-${item.id}',
                          ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (pendingAction != null) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (pendingAction.canComplete)
                              TextButton.icon(
                                key: ValueKey<String>(
                                  'v2-today-complete-${item.id}',
                                ),
                                onPressed: () => _showV2CompleteCurrentAction(
                                  context,
                                  student,
                                  item,
                                ),
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 17,
                                ),
                                label: const Text('处理'),
                              )
                            else
                              TextButton.icon(
                                key: ValueKey<String>(
                                  'v2-today-review-${item.id}',
                                ),
                                onPressed: () => onOpenCase(item),
                                icon: const Icon(Icons.open_in_new, size: 17),
                                label: const Text('查看问题'),
                              ),
                            TextButton.icon(
                              key: ValueKey<String>(
                                'v2-today-reschedule-${item.id}',
                              ),
                              onPressed: () => _showV2RescheduleCurrentAction(
                                context,
                                student,
                                item,
                              ),
                              icon: const Icon(
                                Icons.event_repeat_outlined,
                                size: 17,
                              ),
                              label: Text(
                                pendingAction.dueOn == null ? '安排日期' : '改期',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (!showStatusInline && status.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Text(status, style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
'''
workspace = workspace[:start] + new_today_action + workspace[end:]

workspace_path.write_text(workspace)


test_path = Path('test/features/v037_final_teacher_flow_resilience_test.dart')
test_path.write_text(r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_fixture.dart';
import 'package:xueqing/features/design_v2/v2_workspace_data.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

Widget _app(V2WorkspaceData data, {double textScale = 1.0}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: V2WorkspacePreview(data: data, onSignOut: () {}),
);

void main() {
  testWidgets('compact Today stays readable with large Chinese text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const student = V2Student(
      id: 's-final',
      name: '一位名字比较长的同学',
      grade: '初三',
      subjects: <String>['语文'],
      openCaseCount: 1,
      updatedLabel: '今天',
      teacherSummary: '',
    );
    final item = V2FocusItem(
      id: 'case-overdue',
      studentId: student.id,
      title: '现代文阅读概括题仍然容易遗漏关键结果信息',
      summary: '测试',
      nextStep: '再次检查同类阅读概括题',
      dueLabel: '9 月 1 日',
      subject: '语文',
      actionTiming: V2ActionTiming.overdue,
      dueOn: DateTime(2026, 9, 1),
    );
    final data = V2WorkspaceData(
      students: const <V2Student>[student],
      focusItems: <V2FocusItem>[item],
      timeline: const <V2TimelineEntry>[],
      businessDate: DateTime(2026, 9, 12),
    );

    await tester.pumpWidget(_app(data, textScale: 1.35));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('v2-today-quick-capture')), findsOneWidget);
    expect(find.byKey(const Key('v2-compact-more')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('v2-today-inline-status-case-overdue')),
      findsOneWidget,
    );
    expect(find.text('已逾期 · 9 月 1 日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing-case continuation stacks cleanly on narrow phones', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const student = V2Student(
      id: 's-existing',
      name: '林同学',
      grade: '初三',
      subjects: <String>['语文'],
      openCaseCount: 1,
      updatedLabel: '今天',
      teacherSummary: '',
    );
    const item = V2FocusItem(
      id: 'case-existing',
      studentId: student.id,
      title: '已有的阅读概括问题标题比较长用于窄屏测试',
      summary: '仍会遗漏结果信息。',
      nextStep: '再检查一篇同类阅读题',
      dueLabel: '待安排',
      subject: '语文',
      caseStatus: V2CaseStatus.intervening,
    );
    const data = V2WorkspaceData(
      students: <V2Student>[student],
      focusItems: <V2FocusItem>[item],
      timeline: <V2TimelineEntry>[],
    );

    await tester.pumpWidget(_app(data, textScale: 1.2));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-today-quick-capture')));
    await tester.pumpAndSettle();

    final body = find.byKey(const Key('v2-quick-capture-body'));
    await tester.enterText(body, '今天再次出现概括遗漏结果的情况。');
    await tester.pump();

    final title = find.text('已有的阅读概括问题标题比较长用于窄屏测试');
    final action = find.byKey(
      const ValueKey<String>('v2-quick-capture-existing-case-existing'),
    );
    expect(title, findsOneWidget);
    expect(action, findsOneWidget);
    expect(
      tester.getTopLeft(action).dy,
      greaterThan(tester.getBottomLeft(title).dy),
    );

    final scrollViews = tester.widgetList<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(
      scrollViews.any(
        (view) =>
            view.keyboardDismissBehavior ==
            ScrollViewKeyboardDismissBehavior.onDrag,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
''')
