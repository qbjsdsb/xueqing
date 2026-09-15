from pathlib import Path

source_path = Path('lib/features/design_v2/v2_composers.dart')
source = source_path.read_text()

old_getter = '''  bool get _initialCompleteCurrentAction =>
      widget.canCompleteCurrentAction && widget.completeCurrentActionInitially;

  bool get _hasDraft =>'''
new_getter = '''  bool get _initialCompleteCurrentAction =>
      widget.canCompleteCurrentAction && widget.completeCurrentActionInitially;

  String get _currentActionEffectLabel => switch (_nextStep) {
    V2NextStep.continueTracking => _completeCurrentAction
        ? '当前提醒会标记完成，问题继续观察，不另设新提醒。'
        : '当前提醒会继续保留。',
    V2NextStep.remind => _completeCurrentAction
        ? '当前提醒会标记完成，并创建新的再次检查。'
        : '新的再次检查会替换当前提醒。',
    V2NextStep.close => '结束跟进后，当前提醒会一并取消。',
  };

  bool get _hasDraft =>'''
if old_getter not in source:
    raise SystemExit('progress current-action getter contract changed')
source = source.replace(old_getter, new_getter, 1)

old_next_step = '''            for (final step in V2NextStep.values)
              _QuietRadioRow(
                key: ValueKey('v2-next-step-${step.name}'),
                label: step.label,
                selected: _nextStep == step,
                onTap: () {
                  final previousStep = _nextStep;
                  setState(() {
                    _nextStep = step;
                    if (step == V2NextStep.close) {
                      _completeCurrentAction = false;
                    } else if (previousStep == V2NextStep.close &&
                        _initialCompleteCurrentAction) {
                      _completeCurrentAction = true;
                    }
                  });
                  unawaited(_persistDraftSilently());
                },
              ),
            AnimatedSize('''
new_next_step = '''            for (final step in V2NextStep.values)
              _QuietRadioRow(
                key: ValueKey('v2-next-step-${step.name}'),
                label: step.label,
                selected: _nextStep == step,
                onTap: () {
                  final previousStep = _nextStep;
                  setState(() {
                    _nextStep = step;
                    if (step == V2NextStep.close) {
                      _completeCurrentAction = false;
                    } else if (previousStep == V2NextStep.close &&
                        _initialCompleteCurrentAction) {
                      _completeCurrentAction = true;
                    }
                  });
                  unawaited(_persistDraftSilently());
                },
              ),
            if (widget.canCompleteCurrentAction) ...[
              const SizedBox(height: 6),
              Text(
                _currentActionEffectLabel,
                key: const Key('v2-current-action-effect'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            AnimatedSize('''
if old_next_step not in source:
    raise SystemExit('progress next-step contract changed')
source_path.write_text(source.replace(old_next_step, new_next_step, 1))

test_path = Path('test/features/design_v2_composers_test.dart')
tests = test_path.read_text()
anchor = '''  testWidgets('Progress Composer can open directly in verification mode', (
    tester,
  ) async {'''
new_test = r'''  testWidgets(
    'current reminder consequence stays explicit across next-step decisions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => showV2ProgressComposer(
                context,
                studentName: '林同学',
                subject: '语文',
                caseTitle: '阅读概括不完整',
                canCompleteCurrentAction: true,
                attachmentPicker: (_) async => null,
              ),
              child: const Text('打开提醒语义'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开提醒语义'));
      await tester.pumpAndSettle();

      final effect = find.byKey(const Key('v2-current-action-effect'));
      expect(effect, findsOneWidget);
      expect(find.text('当前提醒会继续保留。'), findsOneWidget);

      final remind = find.text('安排再次检查');
      await tester.ensureVisible(remind);
      await tester.tap(remind);
      await tester.pumpAndSettle();
      expect(find.text('新的再次检查会替换当前提醒。'), findsOneWidget);

      final completion = find.byKey(const Key('v2-complete-current-action'));
      await tester.ensureVisible(completion);
      await tester.tap(completion);
      await tester.pumpAndSettle();
      expect(
        find.text('当前提醒会标记完成，并创建新的再次检查。'),
        findsOneWidget,
      );

      final close = find.text('结束跟进');
      await tester.ensureVisible(close);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.text('结束跟进后，当前提醒会一并取消。'), findsOneWidget);

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
      expect(checkbox.onChanged, isNull);
      expect(tester.takeException(), isNull);
    },
  );

'''
if anchor not in tests:
    raise SystemExit('progress composer test insertion anchor changed')
test_path.write_text(tests.replace(anchor, new_test + anchor, 1))
