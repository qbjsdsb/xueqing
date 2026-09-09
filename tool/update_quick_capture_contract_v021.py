from pathlib import Path

# Keep the static workflow contract aligned with the student-first UI:
# a person is unique at the student picker, while the chosen subject still
# resolves to one concrete profile before anything is saved.
path = Path('test/features/workflow_clarity_contract_test.dart')
text = path.read_text(encoding='utf-8')

old = r'''    expect(
      source,
      contains("'quick-capture-student-option-\${student.profileId}'"),
    );
    expect(
      source,
      isNot(contains("'quick-capture-student-option-\${student.id}'")),
    );
'''

new = r'''    expect(
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

if text.count(old) != 1:
    raise SystemExit(
        f'workflow clarity Quick Capture contract: expected 1 match, found {text.count(old)}'
    )

path.write_text(text.replace(old, new, 1), encoding='utf-8')
