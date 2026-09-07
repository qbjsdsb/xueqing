from pathlib import Path


def replace_exact(text: str, old: str, new: str, *, expected: int = 1, label: str) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{label} anchor drifted: expected {expected}, got {count}')
    return text.replace(old, new)


page_path = Path('lib/features/organization_management/presentation/organization_student_setup_dialog.dart')
page = page_path.read_text()
page = replace_exact(
    page,
    """        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
""",
    """        FilledButton(
          key: const Key('student-setup-submit'),
          onPressed: _busy ? null : _submit,
          child: _busy
""",
    label='student setup submit key',
)
page_path.write_text(page)


test_path = Path('test/features/organization_management_test.dart')
tests = test_path.read_text()
tests = replace_exact(
    tests,
    """    await tester.enterText(find.byType(TextFormField).first, '新学生');
    await tester.tap(find.widgetWithText(FilledButton, '添加学生'));
    await tester.pumpAndSettle();

    expect(repository.studentCreateCount, 1);
""",
    """    await tester.enterText(find.byType(TextFormField).first, '新学生');
    await tester.tap(find.byKey(const Key('student-setup-submit')));
    await tester.pumpAndSettle();

    expect(repository.studentCreateCount, 1);
""",
    label='student setup submit test identity',
)
test_path.write_text(tests)
