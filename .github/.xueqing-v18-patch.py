from pathlib import Path

source_path = Path('lib/features/design_v2/v2_composers.dart')
source = source_path.read_text()

old_call = '''              _ExistingCaseContinuationPanel(
                totalCount: matchingExistingCases.length,
                items: matchingExistingCases.take(3).toList(growable: false),
                canContinue:
                    widget.onContinueExisting != null &&
                    _controller.text.trim().isNotEmpty &&
                    !_saving,
                onContinue: _continueExisting,
              ),'''
new_call = '''              _ExistingCaseContinuationPanel(
                items: matchingExistingCases,
                canContinue:
                    widget.onContinueExisting != null &&
                    _controller.text.trim().isNotEmpty &&
                    !_saving,
                onContinue: _continueExisting,
              ),'''
if old_call not in source:
    raise SystemExit('quick-capture panel call contract changed')
source = source.replace(old_call, new_call, 1)

old_panel = '''class _ExistingCaseContinuationPanel extends StatelessWidget {
  const _ExistingCaseContinuationPanel({
    required this.totalCount,
    required this.items,
    required this.canContinue,
    required this.onContinue,
  });

  final int totalCount;
  final List<V2ExistingCaseOption> items;
  final bool canContinue;
  final ValueChanged<V2ExistingCaseOption> onContinue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '这个学科还有 $totalCount 个问题正在跟进',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '如果刚才的情况属于已有问题，可以直接记到原问题；确实是新问题仍可继续记录。',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) Divider(height: 1, color: scheme.outlineVariant),
            _ExistingCaseContinuationRow(
              item: items[index],
              meta: _existingCaseMeta(items[index]),
              canContinue: canContinue,
              onContinue: onContinue,
            ),
          ],
          if (totalCount > items.length) ...[
            const SizedBox(height: 3),
            Text(
              '这里先显示最需要关注的 ${items.length} 个，其余可在学生详情中查看。',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  String _existingCaseMeta(V2ExistingCaseOption item) {
    if (item.nextStepLabel == '待安排' && item.dueLabel == '待安排') {
      return '${item.statusLabel} · 下一步待安排';
    }
    return '${item.statusLabel} · 下一步 ${item.nextStepLabel} · ${item.dueLabel}';
  }
}
'''
new_panel = '''class _ExistingCaseContinuationPanel extends StatefulWidget {
  const _ExistingCaseContinuationPanel({
    required this.items,
    required this.canContinue,
    required this.onContinue,
  });

  final List<V2ExistingCaseOption> items;
  final bool canContinue;
  final ValueChanged<V2ExistingCaseOption> onContinue;

  @override
  State<_ExistingCaseContinuationPanel> createState() =>
      _ExistingCaseContinuationPanelState();
}

class _ExistingCaseContinuationPanelState
    extends State<_ExistingCaseContinuationPanel> {
  static const int _previewLimit = 3;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visibleItems = _showAll
        ? widget.items
        : widget.items.take(_previewLimit).toList(growable: false);
    final hiddenCount = widget.items.length - _previewLimit;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '这个学科还有 ${widget.items.length} 个问题正在跟进',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '如果刚才的情况属于已有问题，可以直接记到原问题；确实是新问题仍可继续记录。',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < visibleItems.length; index++) ...[
            if (index > 0) Divider(height: 1, color: scheme.outlineVariant),
            _ExistingCaseContinuationRow(
              item: visibleItems[index],
              meta: _existingCaseMeta(visibleItems[index]),
              canContinue: widget.canContinue,
              onContinue: widget.onContinue,
            ),
          ],
          if (widget.items.length > _previewLimit) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              key: const Key('v2-quick-capture-existing-toggle-all'),
              onPressed: () => setState(() => _showAll = !_showAll),
              icon: Icon(
                _showAll ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(
                _showAll ? '收起其余问题' : '查看其余 $hiddenCount 个问题',
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _existingCaseMeta(V2ExistingCaseOption item) {
    if (item.nextStepLabel == '待安排' && item.dueLabel == '待安排') {
      return '${item.statusLabel} · 下一步待安排';
    }
    return '${item.statusLabel} · 下一步 ${item.nextStepLabel} · ${item.dueLabel}';
  }
}
'''
if old_panel not in source:
    raise SystemExit('quick-capture existing-case panel contract changed')
source_path.write_text(source.replace(old_panel, new_panel, 1))

test_path = Path('test/features/v037_existing_case_continuation_test.dart')
tests = test_path.read_text()

old_cases = '''              existingCases: const <V2ExistingCaseOption>[
                V2ExistingCaseOption(
                  id: 'case-reading',
                  title: '阅读题容易漏看限制词',
                  subject: '语文',
                  statusLabel: '跟进中',
                  nextStepLabel: '周五再检查',
                  dueLabel: '周五',
                ),
                V2ExistingCaseOption(
                  id: 'case-math',
                  title: '函数题思路不清',
                  subject: '数学',
                  statusLabel: '跟进中',
                  nextStepLabel: '再练两题',
                  dueLabel: '明天',
                ),
              ],'''
new_cases = '''              existingCases: const <V2ExistingCaseOption>[
                V2ExistingCaseOption(
                  id: 'case-reading-1',
                  title: '阅读题容易漏看限制词',
                  subject: '语文',
                  statusLabel: '跟进中',
                  nextStepLabel: '周五再检查',
                  dueLabel: '周五',
                ),
                V2ExistingCaseOption(
                  id: 'case-reading-2',
                  title: '概括题信息筛选不全',
                  subject: '语文',
                  statusLabel: '跟进中',
                  nextStepLabel: '继续观察',
                  dueLabel: '待安排',
                ),
                V2ExistingCaseOption(
                  id: 'case-reading-3',
                  title: '说明文术语辨析不稳',
                  subject: '语文',
                  statusLabel: '跟进中',
                  nextStepLabel: '下次课复查',
                  dueLabel: '下周',
                ),
                V2ExistingCaseOption(
                  id: 'case-reading-4',
                  title: '论证思路容易漏掉层次',
                  subject: '语文',
                  statusLabel: '跟进中',
                  nextStepLabel: '待安排',
                  dueLabel: '待安排',
                ),
                V2ExistingCaseOption(
                  id: 'case-math',
                  title: '函数题思路不清',
                  subject: '数学',
                  statusLabel: '跟进中',
                  nextStepLabel: '再练两题',
                  dueLabel: '明天',
                ),
              ],'''
if old_cases not in tests:
    raise SystemExit('existing-case fixture contract changed')
tests = tests.replace(old_cases, new_cases, 1)

old_assertions = '''    expect(find.text('阅读题容易漏看限制词'), findsOneWidget);
    expect(find.text('函数题思路不清'), findsNothing);
    expect(find.textContaining('已有问题'), findsWidgets);

    await tester.enterText('''
new_assertions = '''    expect(find.text('阅读题容易漏看限制词'), findsOneWidget);
    expect(find.text('论证思路容易漏掉层次'), findsNothing);
    expect(find.text('函数题思路不清'), findsNothing);
    expect(find.textContaining('已有问题'), findsWidgets);
    expect(find.text('查看其余 1 个问题'), findsOneWidget);

    await tester.enterText('''
if old_assertions not in tests:
    raise SystemExit('existing-case initial assertion contract changed')
tests = tests.replace(old_assertions, new_assertions, 1)

old_tap = '''    await tester.tap(
      find.byKey(const Key('v2-quick-capture-existing-case-reading')),
    );
    await tester.pumpAndSettle();

    expect(newCaseSaves, 0);
    expect(continuedCase?.id, 'case-reading');'''
new_tap = '''    await tester.tap(
      find.byKey(const Key('v2-quick-capture-existing-toggle-all')),
    );
    await tester.pumpAndSettle();
    expect(find.text('论证思路容易漏掉层次'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('v2-quick-capture-existing-case-reading-4')),
    );
    await tester.pumpAndSettle();

    expect(newCaseSaves, 0);
    expect(continuedCase?.id, 'case-reading-4');'''
if old_tap not in tests:
    raise SystemExit('existing-case selection assertion contract changed')
test_path.write_text(tests.replace(old_tap, new_tap, 1))
