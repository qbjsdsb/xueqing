from pathlib import Path


def replace_exact(path: str, old: str, new: str, expected: int = 1) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding='utf-8')
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{path}: expected {expected} matches, found {count}')
    file_path.write_text(text.replace(old, new), encoding='utf-8')


natural_retry = '刚才填写的内容已保留；可以直接重试，不会重复保存。'
replace_exact(
    'lib/features/teacher_workspace/presentation/progressive_case_forms.dart',
    '本次提交内容已锁定；重试会沿用同一 operation ID，不会重复记录。',
    natural_retry,
)
replace_exact(
    'lib/features/teacher_workspace/presentation/progressive_case_forms.dart',
    '本次提交内容已锁定；重试会沿用同一 operation ID。',
    natural_retry,
)
replace_exact(
    'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart',
    '本次提交内容已锁定；重试会沿用同一 operation ID。',
    natural_retry,
)
replace_exact(
    'lib/features/teacher_workspace/presentation/evidence_attachment_picker.dart',
    '当前 Case 已关闭或你已不再负责该学生，无法上传图片。',
    '当前问题已结束跟进或你已不再负责该学生，无法上传图片。',
)

# Existing Today retry regressions should assert teacher language, not implementation detail.
replace_exact(
    'test/features/teacher_workspace_test.dart',
    "expect(find.textContaining('本次提交内容已锁定'), findsOneWidget);",
    "expect(find.textContaining('刚才填写的内容已保留'), findsOneWidget);\n    expect(find.textContaining('operation ID'), findsNothing);",
)
replace_exact(
    'test/features/teacher_workspace_test.dart',
    "expect(find.textContaining('提交内容已锁定'), findsOneWidget);",
    "expect(find.textContaining('刚才填写的内容已保留'), findsOneWidget);\n    expect(find.textContaining('operation ID'), findsNothing);",
)

# Lock the attachment permission/closed-target copy independently.
test_file = Path('test/features/evidence_attachment_picker_test.dart')
text = test_file.read_text(encoding='utf-8')
marker = "  test('keeps a picked image retryable when the network is unavailable', () {\n"
if text.count(marker) != 1:
    raise SystemExit('evidence attachment test marker mismatch')
new_test = """  test('uses teacher language when the problem no longer accepts images', () {
    expect(
      describeEvidenceAttachmentError(
        StateError('attachment_target_not_writable: learning_case_closed'),
        duringUpload: true,
      ),
      '当前问题已结束跟进或你已不再负责该学生，无法上传图片。',
    );
  });

"""
test_file.write_text(text.replace(marker, new_test + marker, 1), encoding='utf-8')
