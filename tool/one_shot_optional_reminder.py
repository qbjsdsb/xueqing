from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected 1 match, found {count}')
    file_path.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once(
    'lib/cloud/progressive_case_repository.dart',
    """    if (nextStep == CaseProgressNextStep.remind) {
      if (nextActionTitle == null || nextActionTitle!.trim().isEmpty) {
        throw ArgumentError('nextActionTitle is required for reminder.');
      }
      if (closeReason != null || closeNote != null) {
        throw ArgumentError('closure fields are not valid for reminder.');
      }
""",
    """    if (nextStep == CaseProgressNextStep.remind) {
      if (nextActionTitle != null && nextActionTitle!.trim().isEmpty) {
        throw ArgumentError('nextActionTitle cannot be blank.');
      }
      if (closeReason != null || closeNote != null) {
        throw ArgumentError('closure fields are not valid for reminder.');
      }
""",
)

replace_once(
    'lib/features/teacher_workspace/presentation/progressive_case_forms.dart',
    """    if (_nextStep == CaseProgressNextStep.remind && reminder.isEmpty) {
      _reminderError = '请写下需要提醒自己做什么';
      valid = false;
    }
""",
    '',
)

replace_once(
    'lib/features/teacher_workspace/presentation/progressive_case_forms.dart',
    """      nextActionTitle: _nextStep == CaseProgressNextStep.remind
          ? reminder
          : null,
""",
    """      nextActionTitle: _nextStep == CaseProgressNextStep.remind && reminder.isNotEmpty
          ? reminder
          : null,
""",
)

replace_once(
    'lib/features/teacher_workspace/presentation/progressive_case_forms.dart',
    """                      decoration: InputDecoration(
                        labelText: '提醒自己做什么？ *',
                        hintText: '例如：下周抽查一次同类阅读题',
                        errorText: _reminderError,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
""",
    """                      decoration: const InputDecoration(
                        labelText: '提醒内容（可选）',
                        hintText: '例如：下周抽查一次同类阅读题',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '不写也可以，系统会生成一条中性提醒。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
""",
)

marker = "  testWidgets('assessment requires the teacher to choose a result explicitly', (\n"
new_test = """  testWidgets('reminder can be saved without repeating a reminder title', (
    tester,
  ) async {
    final repository = _FakeProgressiveCaseRepository();
    await tester.pumpWidget(
      _host(CaseProgressForm(repository: repository, learningCase: _case())),
    );

    await tester.enterText(
      find.byKey(const Key('progress-summary')),
      '今天已经能主动圈出题干限制词',
    );
    await tester.tap(find.byKey(const Key('progress-next-options-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('progress-next-remind')));
    await tester.pumpAndSettle();

    expect(find.text('提醒内容（可选）'), findsOneWidget);
    expect(find.text('不写也可以，系统会生成一条中性提醒。'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('progress-save')));
    await tester.pumpAndSettle();

    final command = repository.progressCommands.single;
    expect(command.nextStep, CaseProgressNextStep.remind);
    expect(command.nextActionTitle, isNull);
    command.validate();
  });

"""
replace_once(
    'test/features/progressive_case_forms_test.dart',
    marker,
    new_test + marker,
)
