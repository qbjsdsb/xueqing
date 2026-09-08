from pathlib import Path


def replace_exact(text: str, old: str, new: str, expected: int, label: str) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f"{label}: expected {expected} matches, got {count}")
    return text.replace(old, new)


page = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
text = page.read_text()
replacements = [
    ("title: 'Next Action / 下一行动',", "title: '下一步',", 1, 'case next action heading'),
    ("Text('Evidence / 证据', style: Theme.of(context).textTheme.titleMedium),", "Text('观察与证据', style: Theme.of(context).textTheme.titleMedium),", 1, 'evidence heading'),
    ("title: 'Intervention / 教学动作',", "title: '已经做过什么',", 1, 'intervention heading'),
    ("title: 'Assessment / Verification',", "title: '验证结果',", 1, 'assessment heading'),
    ("labelText: '教学动作 / Intervention *',", "labelText: '这次怎么处理 *',", 1, 'intervention field'),
    ("labelText: '本次验证 / Evidence *',", "labelText: '本次验证表现 *',", 1, 'assessment evidence field'),
    ("title: '关闭 Case',", "title: '结束跟进',", 1, 'close section title'),
    ("buttonLabel: '关闭 Case',", "buttonLabel: '结束跟进',", 1, 'close button'),
    ("message: '确认问题已经收口后再关闭；关闭会保留历史，但不再列入当前待跟进事项。',", "message: '确认这个问题已经稳定、不再需要继续安排动作后再结束跟进；历史记录仍会完整保留。',", 1, 'close helper'),
    ("title: '记录复发并重新打开',", "title: '问题再次出现',", 1, 'reopen section title'),
    ("buttonLabel: '记录复发并重新打开',", "buttonLabel: '记录新表现并重新跟进',", 1, 'reopen section button'),
    ("message: '关闭后如果再次出现新的表现，可以记录后重新打开；原来的关闭历史会继续保留。',", "message: '如果已经结束跟进的问题再次出现，先记下这次的新表现，再重新开始跟进；之前的历史不会丢失。',", 1, 'reopen helper'),
    ("'把课堂中实际发生的教学动作记下来，系统会把下一步变成 verify action。'", "'把课堂中实际采用的方法记下来，并明确下一次如何验证效果。'", 1, 'intervention mode hint'),
    ("'Evidence 已保存，正在等待重新打开；请继续重试完成第二步。'", "'这条新表现已经保存，正在等待重新开始跟进；请继续重试完成第二步。'", 1, 'reopen saved status'),
    ("? '保存 Evidence'", "? '保存这条表现'", 1, 'reopen save evidence button'),
    (": '重新打开 Case',", ": '重新开始跟进',", 1, 'reopen submit button'),
    ("'这条 Evidence 还没有完成保存，不能用于重新打开 Case。'", "'这条新表现还没有完成保存，暂时不能重新开始跟进。'", 1, 'reopen finalize error'),
    ("'复发 Evidence 已经发生变化，请刷新 Case 后重新选择。'", "'这条新表现已经发生变化，请刷新问题详情后重新选择。'", 1, 'reopen version error'),
    ("'只有这条 Case 的负责教师可以执行这一步。'", "'只有这个问题的负责教师可以执行这一步。'", 1, 'owner permission error'),
    ("const Text('尚未记录 Evidence。')", "const Text('还没有记录可观察的表现。')", 1, 'empty evidence copy'),
]
for old, new, expected, label in replacements:
    text = replace_exact(text, old, new, expected, label)

# Teacher-facing row navigation: keep internal Case terminology out of everyday UI.
text = replace_exact(text, "const Text('查看 Case')", "const Text('查看问题')", 1, 'case row button')
page.write_text(text)

# Update visible-copy assertions only; keep behavioral assertions intact.
test = Path('test/features/teacher_workspace_test.dart')
t = test.read_text()
t = replace_exact(t, "find.text('Next Action / 下一行动')", "find.text('下一步')", 2, 'next action test assertions')
t = replace_exact(t, "find.text('查看 Case')", "find.text('查看问题')", 1, 'case button assertion')
t = replace_exact(t, "find.widgetWithText(OutlinedButton, '查看 Case')", "find.widgetWithText(OutlinedButton, '查看问题')", 1, 'case button finder')
test.write_text(t)
