from pathlib import Path
import re


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)

# Product copy consistency.
path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
text = path.read_text(encoding='utf-8')
text = replace_once(text, "SnackBar(content: Text('已记录为待整理问题。'))", "SnackBar(content: Text('已记录到学生成长记录。'))", 'saved copy')
text = replace_once(text, "            title: '待整理问题',", "            title: '新记录',", 'new record notice')
text = replace_once(text, "            title: '另外待验证',", "            title: '另外需要关注',", 'student pending heading')
path.write_text(text, encoding='utf-8')

# Teacher workspace tests: preserve coverage while moving to record-not-task behavior.
path = Path('test/features/teacher_workspace_test.dart')
text = path.read_text(encoding='utf-8')

text = replace_once(
    text,
    "    expect(find.text('待整理问题'), findsOneWidget);\n    expect(find.text('待整理'), findsOneWidget);",
    "    expect(find.text('新记录'), findsWidgets);\n    expect(find.text('待整理问题'), findsNothing);",
    'new record detail copy',
)

old = """  testWidgets('pending verification is treated as real Today work', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(status: LearningCaseStatus.pendingVerification),
    );
    await _pumpWorkspace(tester, repository);

    expect(find.text('今天暂时没有需要处理的事项'), findsNothing);
    expect(find.text('今天没有已安排的行动'), findsNothing);
    expect(
      find.byKey(const Key('workspace-pending-verification-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('workspace-undated-actions-section')),
      findsNothing,
    );
    expect(find.text('分数步骤需要继续观察'), findsOneWidget);
  });
"""
new = """  testWidgets('a completed check without an Action is not a second Today task', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(
        status: LearningCaseStatus.pendingVerification,
        includeAction: false,
      ),
    );
    await _pumpWorkspace(tester, repository);

    expect(find.text('今天暂时没有需要处理的事项'), findsOneWidget);
    expect(
      find.byKey(const Key('workspace-pending-verification-section')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('workspace-undated-actions-section')),
      findsNothing,
    );
  });
"""
text = replace_once(text, old, new, 'pending verification Today contract')

old = """  testWidgets(
    'new Quick Capture Case without an Action remains visible in Today',
    (tester) async {
      final repository = _FakeLearningRepository(
        _fixtureWorkspace(
          status: LearningCaseStatus.newCase,
          includeAction: false,
        ),
      );
      await _pumpWorkspace(tester, repository);

      expect(find.text('今天暂时没有需要处理的事项'), findsNothing);
      expect(
        find.byKey(const Key('workspace-new-cases-section')),
        findsOneWidget,
      );
      expect(find.text('待整理'), findsWidgets);
      expect(find.text('分数步骤需要继续观察'), findsOneWidget);
      expect(
        find.byKey(const Key('workspace-undated-actions-section')),
        findsNothing,
      );
    },
  );
"""
new = """  testWidgets(
    'new Quick Capture fact without an Action stays out of Today',
    (tester) async {
      final repository = _FakeLearningRepository(
        _fixtureWorkspace(
          status: LearningCaseStatus.newCase,
          includeAction: false,
        ),
      );
      await _pumpWorkspace(tester, repository);

      expect(find.text('今天暂时没有需要处理的事项'), findsOneWidget);
      expect(find.byKey(const Key('workspace-new-cases-section')), findsNothing);
      expect(
        find.byKey(const Key('workspace-undated-actions-section')),
        findsNothing,
      );
    },
  );
"""
text = replace_once(text, old, new, 'new fact Today contract')

text = text.replace(
    "expect(find.text('可以回看最近学生，或在课堂中先记录一句问题。'), findsOneWidget);",
    "expect(find.text('可以回看最近学生，或在课堂中随手记下一条新情况。'), findsOneWidget);",
    1,
)

pattern = re.compile(
    r"  testWidgets\(\n    'bounds lower-priority Today sections until explicitly expanded',.*?\n  \);\n\n  testWidgets\(\n    'student detail keeps priorities concise and removes duplicate problem lists',",
    re.S,
)
replacement = """  testWidgets(
    'bounds explicit future and undated reminders until expanded',
    (tester) async {
      final cases = <WorkspaceCase>[
        for (var index = 1; index <= 4; index++)
          _caseFixture(
            id: 'future-$index',
            title: '未来问题 $index',
            status: LearningCaseStatus.confirmed,
            actionBucket: WorkspaceActionBucket.future,
            actionDueAt: DateTime(2026, 9, 5 + index),
          ),
        for (var index = 1; index <= 4; index++)
          _caseFixture(
            id: 'undated-$index',
            title: '待安排问题 $index',
            status: LearningCaseStatus.confirmed,
            actionBucket: WorkspaceActionBucket.undated,
            actionDueAt: null,
          ),
      ];
      final repository = _FakeLearningRepository(
        _workspaceWithStudents([
          _studentFixture(id: 'preview', name: '预览学生', cases: cases),
        ]),
      );
      await _pumpWorkspace(tester, repository);

      expect(find.byKey(const Key('workspace-pending-verification-section')), findsNothing);
      expect(find.text('之后要处理'), findsOneWidget);
      expect(find.text('未来问题 4 的下一步'), findsNothing);
      expect(find.text('待安排问题 4 的下一步'), findsNothing);

      await tester.ensureVisible(
        find.byKey(const Key('workspace-future-actions-toggle')),
      );
      await tester.tap(find.byKey(const Key('workspace-future-actions-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('未来问题 4 的下一步'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('workspace-undated-actions-toggle')),
      );
      await tester.tap(find.byKey(const Key('workspace-undated-actions-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('待安排问题 4 的下一步'), findsOneWidget);
    },
  );

  testWidgets(
    'student detail keeps priorities concise and removes duplicate problem lists',"""
text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise RuntimeError(f'bounded Today test: expected 1 match, found {count}')

text = text.replace("expect(find.text('另外待验证'), findsOneWidget);", "expect(find.text('另外需要关注'), findsOneWidget);", 1)
text = text.replace("expect(find.text('另外待验证'), findsNothing);", "expect(find.text('另外需要关注'), findsNothing);", 1)

pattern = re.compile(
    r"  testWidgets\(\n    'keeps Quick Capture input and reuses operation id after failure',.*?\n  \);\n\n  testWidgets\('focuses the problem title after choosing a student',",
    re.S,
)
replacement = """  testWidgets(
    'keeps the single Quick Capture note and reuses operation id after failure',
    (tester) async {
      final repository = _FakeLearningRepository(_fixtureWorkspace())
        ..failFirstSave = true;
      await _pumpWorkspace(tester, repository);

      await tester.tap(find.text('记录问题').first);
      await tester.pumpAndSettle();
      expect(find.text('今天发现什么？ *'), findsOneWidget);
      expect(find.byKey(const Key('quick-capture-evidence-field')), findsNothing);

      final noteField = find.byKey(const Key('quick-capture-title-field'));
      await tester.enterText(
        noteField,
        '通分步骤容易跳过。课堂练习中连续两次直接写结果。',
      );
      final saveButton = find.byKey(const Key('workspace-quick-capture-save'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('网络暂时不可用'), findsOneWidget);
      expect(find.text('通分步骤容易跳过。课堂练习中连续两次直接写结果。'), findsOneWidget);

      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('已记录到学生成长记录。'), findsOneWidget);
      expect(repository.saveCount, 2);
      expect(repository.commands[0].operationId, repository.commands[1].operationId);
      expect(repository.commands[1].profileId, 'profile-1');
      expect(repository.commands[1].title, '通分步骤容易跳过');
      expect(
        repository.commands[1].evidenceSummary,
        '通分步骤容易跳过。课堂练习中连续两次直接写结果。',
      );
      expect(repository.commands[1].description, repository.commands[1].evidenceSummary);
      expect(repository.commands[1].nextActionTitle, isNull);
    },
  );

  testWidgets('focuses the problem title after choosing a student',"""
text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise RuntimeError(f'Quick Capture retry test: expected 1 match, found {count}')

pattern = re.compile(
    r"  testWidgets\('keeps Quick Capture facts before classification', \(\n    tester,\n  \) async \{.*?\n  \}\);",
    re.S,
)
replacement = """  testWidgets('keeps optional Quick Capture classification behind disclosure', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(_fixtureWorkspace());
    await _pumpWorkspace(tester, repository);

    await tester.tap(find.text('记录问题').first);
    await tester.pumpAndSettle();

    final noteField = find.byKey(const Key('quick-capture-title-field'));
    final typePicker = find.byKey(
      const Key('quick-capture-case-type-dropdown'),
    );

    expect(noteField, findsOneWidget);
    expect(find.byKey(const Key('quick-capture-evidence-field')), findsNothing);
    expect(typePicker, findsNothing);
    expect(find.text('问题类型（可调整）'), findsNothing);
    expect(find.text('更多选项'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick-capture-more-options')));
    await tester.pumpAndSettle();
    expect(typePicker, findsOneWidget);
    expect(find.text('问题类型（可调整）'), findsOneWidget);
  });"""
text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise RuntimeError(f'Quick Capture disclosure test: expected 1 match, found {count}')

# Custom type requires opening optional controls and only one note field.
needle = """    await tester.tap(find.text('记录问题').first);
    await tester.pumpAndSettle();

    final studentPicker = find.byType(
      DropdownButtonFormField<WorkspaceStudent>,
    );
"""
replacement = """    await tester.tap(find.text('记录问题').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-capture-more-options')));
    await tester.pumpAndSettle();

    final studentPicker = find.byType(
      DropdownButtonFormField<WorkspaceStudent>,
    );
"""
# Apply only to selected-custom-type test: use location after its test title.
custom_pos = text.index("testWidgets('sends a selected custom type")
match_pos = text.index(needle, custom_pos)
text = text[:match_pos] + replacement + text[match_pos + len(needle):]
old_fields = """    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '新题审题策略不稳定');
    await tester.enterText(textFields.at(1), '面对综合题时没有先识别已知条件。');
"""
new_fields = """    await tester.enterText(
      find.byKey(const Key('quick-capture-title-field')),
      '新题审题策略不稳定。面对综合题时没有先识别已知条件。',
    );
"""
segment_end = text.index("testWidgets('uses bottom sheets for compact", custom_pos)
segment = text[custom_pos:segment_end]
if old_fields not in segment:
    raise RuntimeError('custom type old two-field input not found')
segment = segment.replace(old_fields, new_fields, 1)
text = text[:custom_pos] + segment + text[segment_end:]

# Compact type selector is also optional and must be explicitly revealed.
compact_pos = text.index("testWidgets('uses bottom sheets for compact")
type_pos = text.index("    final typePicker = find.byKey(", compact_pos)
text = text[:type_pos] + "    await tester.tap(find.byKey(const Key('quick-capture-more-options')));\n    await tester.pumpAndSettle();\n\n" + text[type_pos:]

path.write_text(text, encoding='utf-8')

print('Updated product copy and teacher-friction tests.')
