from pathlib import Path


def replace_all(text: str, old: str, new: str, label: str, minimum: int = 1) -> str:
    count = text.count(old)
    if count < minimum:
        raise SystemExit(f"{label}: expected at least {minimum} matches, got {count}")
    print(f"{label}: {count}")
    return text.replace(old, new)


workspace_path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
text = workspace_path.read_text()

replacements = [
    ("'可访问的学生'", "'学生列表'", 'student list heading'),
    ("'查看 Case'", "'查看问题'", 'view case buttons'),
    ("'Next Action / 下一行动'", "'下一步'", 'next action heading'),
    ("'Intervention / 教学动作'", "'已采取的方法'", 'intervention heading'),
    ("'Assessment / Verification'", "'验证记录'", 'assessment heading'),
    ("'Evidence / 证据'", "'观察与证据'", 'evidence heading'),
    ("'尚未记录 Evidence。'", "'还没有记录证据。'", 'evidence empty state'),
    ("'教学动作 / Intervention *'", "'这次怎么处理 *'", 'intervention field label'),
    ("'本次验证 / Evidence *'", "'本次验证表现 *'", 'assessment evidence field label'),
    ("'拍照 / 选择'", "'拍照或选图'", 'attachment action'),
    ("'问题标题 *'", "'一句话问题 *'", 'quick capture title label'),
    ("'用一句话记下刚发现的问题'", "'例如：阅读题总漏掉题干里的限制词'", 'quick capture title hint'),
    ("'确认 Case'", "'整理并确认问题'", 'confirm case label'),
    ("'确认 Case 已稳定'", "'确认已经稳定'", 'stabilize label'),
    ("'关闭 Case'", "'结束跟进'", 'close case label'),
    ("'记录复发并重新打开'", "'记录复发并继续跟进'", 'reopen label'),
    ("'重新打开后的行动类型'", "'下一步类型'", 'reopen action type label'),
    ("'重新打开后的下一行动 *'", "'接下来的行动 *'", 'reopen next action label'),
    ("'保存 Evidence'", "'保存证据'", 'save evidence label'),
    ("'重新打开 Case'", "'继续跟进'", 'reopen button label'),
    ("'当前 Case'", "'当前问题'", 'current case context label'),
    ("'系统类型始终保留。自定义类型只负责分类，仍沿用同一套 Case、证据、行动和验证流程。'", "'系统类型始终保留。自定义类型只负责分类，所有问题仍沿用同一套证据、行动和验证流程。'", 'case type explanation'),
    ("'归档后仍会保留历史名称，不会改变已有 Case。'", "'归档后仍会保留历史名称，不会改变已有问题。'", 'archived type explanation'),
    ("'保存失败。输入仍保留在这里，请重试；未确认成功前不会生成重复 Case。'", "'保存失败。输入仍保留在这里，请重试；未确认成功前不会生成重复问题。'", 'quick capture save error'),
    ("'完成“${widget.action.title}”后安排下一步。正式 Case 不会因为勾选完成就失去后续跟进。'", "'完成“${widget.action.title}”后安排下一步。这个问题不会因为勾选完成就失去后续跟进。'", 'complete action explanation'),
    ("'当前输入还没有保存。放弃后不会产生新的 Evidence。'", "'当前输入还没有保存。放弃后不会产生新的证据。'", 'reopen discard copy'),
    ("'Evidence 已保存，正在等待重新打开；请继续重试完成第二步。'", "'证据已保存，正在等待继续跟进；请重试完成第二步。'", 'reopen committed evidence copy'),
    ("'Evidence 已保存，但恢复记录暂时无法保存。请保持页面打开并重试。'", "'证据已保存，但恢复记录暂时无法保存。请保持页面打开并重试。'", 'reopen draft storage error'),
    ("'图片暂时无法读取，请重新打开 Case。'", "'图片暂时无法读取，请关闭预览后重试。'", 'image preview error'),
    ("'这条 Evidence 还没有完成保存，不能用于重新打开 Case。'", "'这条证据还没有完成保存，暂时不能继续跟进。'", 'evidence not finalized error'),
    ("'复发 Evidence 已经发生变化，请刷新 Case 后重新选择。'", "'复发证据已经发生变化，请刷新问题后重新选择。'", 'evidence conflict error'),
    ("'只有这条 Case 的负责教师可以执行这一步。'", "'只有这条问题的负责教师可以执行这一步。'", 'owner permission error'),
    ("'Case 状态已经变化，请刷新后再试。'", "'问题状态已经变化，请刷新后再试。'", 'case state error'),
    ("'这个 Case 已经关闭，不能再完成其中的行动。请刷新后查看最新状态。'", "'这个问题已经结束跟进，不能再完成其中的行动。请刷新后查看最新状态。'", 'closed case error'),
    ("'这个 Case 已经被更新。输入仍保留，请先刷新后确认最新状态再重试。'", "'这个问题已经被更新。输入仍保留，请先刷新后确认最新状态再重试。'", 'case version error'),
    ("'当前账号已经不能执行这一步，可能是权限或 Case 状态发生了变化。请刷新后再试。'", "'当前账号已经不能执行这一步，可能是权限或问题状态发生了变化。请刷新后再试。'", 'permission case error'),
    ("'最新验证结果为通过。确认稳定后会安排一次复查，Case 仍可继续保留历史。'", "'最新验证结果为通过。确认稳定后会安排一次复查，问题历史会继续保留。'", 'stabilize explanation'),
    ("'确认问题已经收口后再关闭；关闭会保留历史，但不再列入当前待跟进事项。'", "'确认这个问题已经稳定收口后再结束跟进；历史记录会完整保留。'", 'close explanation'),
    ("'关闭后如果再次出现新的表现，可以记录后重新打开；原来的关闭历史会继续保留。'", "'结束跟进后如果再次出现新的表现，可以记录复发并继续跟进；之前的历史会完整保留。'", 'reopen explanation'),
    ("'记录这次实际做了什么；保存后系统会生成 verify action。'", "'记录这次实际做了什么，并明确下一次要检查什么。'", 'intervention subtitle'),
]

for old, new, label in replacements:
    text = replace_all(text, old, new, label)

old_context = """    final caseContext =
        '${widget.learningCase.typeLabel} · ${widget.learningCase.status.label} · version ${widget.learningCase.version}';"""
new_context = """    final caseContext =
        '${widget.learningCase.typeLabel} · ${widget.learningCase.status.label}';"""
text = replace_all(text, old_context, new_context, 'case command context version', 1)

old_complete_context = """    final caseContext =
        '${widget.learningCase.title} · ${widget.learningCase.status.label} · '
        'version ${widget.learningCase.version}';"""
new_complete_context = """    final caseContext =
        '${widget.learningCase.title} · ${widget.learningCase.status.label}';"""
text = replace_all(text, old_complete_context, new_complete_context, 'complete action context version', 1)

old_default = "  String _selectedCaseTypeKey = WorkspaceCaseType.builtInTypes.first.key;"
new_default = "  String _selectedCaseTypeKey = WorkspaceCaseType.builtInTypes.last.key;"
text = replace_all(text, old_default, new_default, 'quick capture neutral default', 1)
old_fallback = "    return WorkspaceCaseType.builtInTypes.first;"
new_fallback = "    return WorkspaceCaseType.builtInTypes.last;"
text = replace_all(text, old_fallback, new_fallback, 'quick capture neutral fallback', 1)

workspace_path.write_text(text)

test_path = Path('test/features/teacher_workspace_test.dart')
test_text = test_path.read_text()
for old, new, label in [
    ("'查看 Case'", "'查看问题'", 'tests view case'),
    ("'Next Action / 下一行动'", "'下一步'", 'tests next action heading'),
    ("'确认 Case'", "'整理并确认问题'", 'tests confirm case'),
    ("'关闭 Case'", "'结束跟进'", 'tests close case'),
    ("'记录复发并重新打开'", "'记录复发并继续跟进'", 'tests reopen case'),
    ("'保存 Evidence'", "'保存证据'", 'tests save evidence'),
    ("'重新打开 Case'", "'继续跟进'", 'tests continue tracking'),
    ("'完成“补充一次课堂证据”后安排下一步。正式 Case 不会因为勾选完成就失去后续跟进。'", "'完成“补充一次课堂证据”后安排下一步。这个问题不会因为勾选完成就失去后续跟进。'", 'tests completion explanation'),
]:
    test_text = replace_all(test_text, old, new, label)

test_path.write_text(test_text)
