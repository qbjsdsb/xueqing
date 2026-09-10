from pathlib import Path

source = Path('tools/v032_student_profile_policy_patch.py')
text = source.read_text(encoding='utf-8')
old = '''replace_once(
    repo_path,
    "        'p_grade': _nullableText(grade),\\n",
    "        'p_grade': grade.trim(),\\n",
    'Supabase profile grade parameter',
)
'''
new = '''replace_once(
    repo_path,
    """    final response = await _call(
      'update_organization_student_profile',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_id': studentId,
        'p_expected_student_version': expectedStudentVersion,
        'p_name': name.trim(),
        'p_student_code': _nullableText(studentCode),
        'p_grade': _nullableText(grade),
        'p_class_name': _nullableText(className),
        'p_campus': _nullableText(campus),
      },
    );
""",
    """    final response = await _call(
      'update_organization_student_profile',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_id': studentId,
        'p_expected_student_version': expectedStudentVersion,
        'p_name': name.trim(),
        'p_student_code': _nullableText(studentCode),
        'p_grade': grade.trim(),
        'p_class_name': _nullableText(className),
        'p_campus': _nullableText(campus),
      },
    );
""",
    'Supabase profile grade parameter',
)
'''
count = text.count(old)
if count != 1:
    raise SystemExit(
        f'policy runner expected one broad grade-parameter matcher, found {count}'
    )
patched = text.replace(old, new, 1)
patched += r'''

# The existing widget fixture uses 初二 / 一班 / 本部. Keep the prefill
# assertion tied to the fixture instead of introducing unrelated sample data.
replace_once(
    feature_test,
    """      tester
          .widget<TextFormField>(
            find.byKey(const Key('student-edit-class-field')),
          )
          .controller
          ?.text,
      'A班',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('student-edit-campus-field')),
          )
          .controller
          ?.text,
      '思明校区',
""",
    """      tester
          .widget<TextFormField>(
            find.byKey(const Key('student-edit-class-field')),
          )
          .controller
          ?.text,
      '一班',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('student-edit-campus-field')),
          )
          .controller
          ?.text,
      '本部',
""",
    'student profile prefill fixture values',
)
'''
target = Path('/tmp/v032_student_profile_policy_patch.py')
target.write_text(patched, encoding='utf-8')
print(f'prepared RPC-scoped policy patch at {target}')
