from pathlib import Path


def replace_exact(text: str, old: str, new: str, *, expected: int = 1, label: str) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{label} anchor drifted: expected {expected}, got {count}')
    return text.replace(old, new)


subject_path = Path('lib/features/organization_management/presentation/organization_subject_setup_dialog.dart')
subject = subject_path.read_text()
subject_replacements = [
    (
        "    return '保存未完成；可以检查网络后重试。';",
        "    return '添加未完成；可以检查网络后重试。';",
        'subject fallback error',
    ),
    (
        "              '从全局活跃学科目录中选择一个加入本机构。全局目录不会被修改。',",
        "              '选择机构要使用的学科。添加后，就可以为老师配置可教学科，并为学生安排对应老师。',",
        'subject intro copy',
    ),
    (
        "                    child: Text(\n                      '${subject.displayName} · ${subject.code}',\n                      overflow: TextOverflow.ellipsis,\n                    ),",
        "                    child: Text(\n                      subject.displayName,\n                      overflow: TextOverflow.ellipsis,\n                    ),",
        'subject option label',
    ),
    (
        "        FilledButton(\n          onPressed: _busy ? null : _submit,",
        "        FilledButton(\n          key: const Key('subject-setup-submit'),\n          onPressed: _busy ? null : _submit,",
        'subject submit key',
    ),
    (
        "              : const Text('保存学科'),",
        "              : const Text('添加学科'),",
        'subject submit copy',
    ),
]
for old, new, label in subject_replacements:
    subject = replace_exact(subject, old, new, label=label)
subject_path.write_text(subject)


dialogs_path = Path('lib/features/organization_management/presentation/organization_management_dialogs.dart')
dialogs = dialogs_path.read_text()
dialog_replacements = [
    (
        "                const Text('姓名用于机构内显示，邮箱用于登录。新账号会使用这里的姓名；已有账号接受邀请时会再次确认姓名。'),",
        "                const Text('填写姓名、登录邮箱和身份。姓名会显示在机构内，邮箱用于登录；系统会根据账号状态完成开通或邀请。'),",
        'invite intro copy',
    ),
    (
        "                  decoration: const InputDecoration(labelText: '身份'),",
        "                  decoration: const InputDecoration(labelText: '身份 *'),",
        'invite role label',
    ),
    (
        "                Text(\n                  _selectedRole == OrganizationInvitationRole.owner\n                      ? '管理员提名负责人后，需要现有负责人审批。'\n                      : '身份决定管理边界；老师能看到哪些学生仍由可教学科和任课关系决定。',\n                  style: Theme.of(context).textTheme.bodySmall,\n                ),",
        "                Text(\n                  switch (_selectedRole) {\n                    OrganizationInvitationRole.owner =>\n                      '负责人拥有成员账号和机构设置权限，请只授予确实需要承担机构责任的人。',\n                    OrganizationInvitationRole.admin =>\n                      '管理员可以管理机构教学与学生信息，但不能邀请、停用或恢复成员账号。',\n                    OrganizationInvitationRole.teacher =>\n                      '老师只处理教学工作；能看到哪些学生仍由可教学科和任课关系决定。',\n                  },\n                  style: Theme.of(context).textTheme.bodySmall,\n                ),",
        'invite role helper',
    ),
    (
        "        FilledButton(onPressed: _submit, child: const Text('创建邀请')),",
        "        FilledButton(\n          key: const Key('invite-member-submit'),\n          onPressed: _submit,\n          child: const Text('继续'),\n        ),",
        'invite submit copy',
    ),
]
for old, new, label in dialog_replacements:
    dialogs = replace_exact(dialogs, old, new, label=label)
dialogs_path.write_text(dialogs)


test_path = Path('test/features/organization_management_test.dart')
tests = test_path.read_text()
test_replacements = [
    (
        "    expect(find.text('保存学科'), findsOneWidget);",
        "    expect(find.text('添加学科'), findsWidgets);",
        'subject dialog action expectation',
    ),
    (
        "    expect(find.text('从全局活跃学科目录中选择一个加入本机构。全局目录不会被修改。'), findsOneWidget);\n    await tester.tap(find.text('保存学科'));",
        "    expect(find.text('选择机构要使用的学科。添加后，就可以为老师配置可教学科，并为学生安排对应老师。'), findsOneWidget);\n    await tester.tap(find.byKey(const Key('subject-setup-submit')));",
        'subject submit flow test',
    ),
]
for old, new, label in test_replacements:
    tests = replace_exact(tests, old, new, label=label)
test_path.write_text(tests)
