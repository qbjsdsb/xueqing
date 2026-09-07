from pathlib import Path


def replace_exact(text: str, old: str, new: str, *, expected: int = 1, label: str) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{label} anchor drifted: expected {expected}, got {count}')
    return text.replace(old, new)


page_path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
page = page_path.read_text()

old_block = """                  _buildStudentField(context),
                  const SizedBox(height: AppSpacing.md),
                  _buildCaseTypeField(context),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _titleController,
                    autofocus: _selectedStudent != null,
                    enabled: !_saving,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: '问题标题 *',
                      hintText: '用一句话记下刚发现的问题',
                      errorText: _titleError,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _evidenceController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: '具体表现 *',
                      hintText: '写下题目、行为或课堂里实际看到的表现',
                      errorText: _evidenceError,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '这段记录会作为问题依据保留；之后可以继续补充，不会覆盖原记录。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (widget.evidenceAttachmentRepository != null) ...[
"""
new_block = """                  _buildStudentField(context),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('quick-capture-title-field'),
                    controller: _titleController,
                    autofocus: _selectedStudent != null,
                    enabled: !_saving,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: '问题标题 *',
                      hintText: '用一句话记下刚发现的问题',
                      errorText: _titleError,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('quick-capture-evidence-field'),
                    controller: _evidenceController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: '具体表现 *',
                      hintText: '写下题目、行为或课堂里实际看到的表现',
                      errorText: _evidenceError,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '这段记录会作为问题依据保留；之后可以继续补充，不会覆盖原记录。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildCaseTypeField(context),
                  if (widget.evidenceAttachmentRepository != null) ...[
"""
page = replace_exact(page, old_block, new_block, label='Quick Capture field order')
page = replace_exact(
    page,
    "decoration: const InputDecoration(labelText: '问题类型'),",
    "decoration: const InputDecoration(labelText: '问题类型（可调整）'),",
    label='desktop case type label',
)
page = replace_exact(
    page,
    "      label: '问题类型',\n      value: _selectedCaseType.label,",
    "      label: '问题类型（可调整）',\n      value: _selectedCaseType.label,",
    label='compact case type label',
)
page_path.write_text(page)


test_path = Path('test/features/teacher_workspace_test.dart')
tests = test_path.read_text()
anchor = """  testWidgets('shows custom type settings to an organization manager', (
    tester,
  ) async {
"""
new_test = """  testWidgets('keeps Quick Capture facts before classification', (tester) async {
    final repository = _FakeLearningRepository(_fixtureWorkspace());
    await _pumpWorkspace(tester, repository);

    await tester.tap(find.text('记录问题').first);
    await tester.pumpAndSettle();

    final titleField = find.byKey(const Key('quick-capture-title-field'));
    final evidenceField = find.byKey(const Key('quick-capture-evidence-field'));
    final typePicker = find.byKey(
      const Key('quick-capture-case-type-dropdown'),
    );

    expect(titleField, findsOneWidget);
    expect(evidenceField, findsOneWidget);
    expect(typePicker, findsOneWidget);
    expect(
      tester.getTopLeft(titleField).dy,
      lessThan(tester.getTopLeft(typePicker).dy),
    );
    expect(
      tester.getTopLeft(evidenceField).dy,
      lessThan(tester.getTopLeft(typePicker).dy),
    );
    expect(find.text('问题类型（可调整）'), findsOneWidget);
  });

  testWidgets('shows custom type settings to an organization manager', (
    tester,
  ) async {
"""
tests = replace_exact(tests, anchor, new_test, label='Quick Capture order regression')
test_path.write_text(tests)


spec_path = Path('docs/design/SCREEN_SPECS.md')
spec = spec_path.read_text()
spec = replace_exact(
    spec,
    """1. 学生 + 学科上下文（可确认、可更改）。
2. 必填单行 `问题标题`。
3. 必填一句 `具体表现`，只记录题目、行为或课堂中实际看到的事实。
4. 非阻塞相近 Case 提示。
5. `记录问题` 保存；取消/稍后整理为次要动作。

不在最短路径强制要求 taxonomy、根因、正式 owner、长篇 Evidence、手工填写 Next Action、due date 或附件。""",
    """1. 学生 + 学科上下文（可确认、可更改）。
2. 必填单行 `问题标题`。
3. 必填一句 `具体表现`，只记录题目、行为或课堂中实际看到的事实。
4. `问题类型` 使用已有默认值，只有教师当下确定时才调整；分类不得排在事实输入之前。
5. 非阻塞相近 Case 提示。
6. `记录问题` 保存；取消/稍后整理为次要动作。

不在最短路径强制要求 taxonomy、根因、正式 owner、长篇 Evidence、手工填写 Next Action、due date 或附件。""",
    label='screen spec information priority',
)
spec = replace_exact(
    spec,
    """具体表现 *
[题目、行为或课堂里实际看到的表现 ]

[取消]                         [记录问题]""",
    """具体表现 *
[题目、行为或课堂里实际看到的表现 ]

问题类型（可调整）  [当前默认类型      v]

[取消]                         [记录问题]""",
    label='screen spec recommended layout',
)
spec = replace_exact(
    spec,
    "Tab 顺序为 Student/Subject → title → note → 保存 → 取消。",
    "Tab 顺序为 Student/Subject → title → note → type → 保存 → 取消。",
    label='screen spec keyboard order',
)
spec = replace_exact(
    spec,
    "不做完整 Case 表单、强制 taxonomy/根因/owner/action/date/附件、不强行合并重复 Case、不在课堂显示 AI 建议、不用大面积浮层/渐变/卡片堆砌，不因失败关闭 sheet 并丢掉文字。",
    "不做完整 Case 表单、把 taxonomy/分类放在事实输入之前、强制根因/owner/action/date/附件、不强行合并重复 Case、不在课堂显示 AI 建议、不用大面积浮层/渐变/卡片堆砌，不因失败关闭 sheet 并丢掉文字。",
    label='screen spec anti-pattern',
)
spec_path.write_text(spec)
