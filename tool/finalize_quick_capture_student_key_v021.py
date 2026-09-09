from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


page = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
replace_once(
    page,
    "'quick-capture-student-option-${group.first.profileId}'",
    "'quick-capture-student-option-${group.first.id}'",
    'student option key',
)

test = Path('test/features/teacher_workspace_test.dart')
replace_once(
    test,
    "quick-capture-student-option-profile-1",
    "quick-capture-student-option-student-1",
    'compact Quick Capture student option test key',
)

contract = Path('test/features/workflow_clarity_contract_test.dart')
text = contract.read_text(encoding='utf-8')
old = r'''    expect(
      source,
      contains("'quick-capture-student-option-\${group.first.profileId}'"),
    );
    expect(
      source,
      contains("'quick-capture-subject-option-\${profile.profileId}'"),
    );
    expect(
      source,
      isNot(contains("'quick-capture-student-option-\${student.profileId}'")),
    );
    expect(
      source,
      isNot(contains("'quick-capture-student-option-\${student.id}'")),
    );
'''
new = r'''    expect(
      source,
      contains("'quick-capture-student-option-\${group.first.id}'"),
    );
    expect(
      source,
      contains("'quick-capture-subject-option-\${profile.profileId}'"),
    );
    expect(
      source,
      isNot(
        contains("'quick-capture-student-option-\${group.first.profileId}'"),
      ),
    );
'''
count = text.count(old)
if count != 1:
    raise SystemExit(
        f'workflow clarity student-key contract: expected exactly one match, found {count}'
    )
contract.write_text(text.replace(old, new, 1), encoding='utf-8')
