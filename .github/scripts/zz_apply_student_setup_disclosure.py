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
    "  bool _busy = false;\n  String? _errorMessage;",
    "  bool _busy = false;\n  bool _showOptionalDetails = false;\n  String? _errorMessage;",
    label='optional disclosure state',
)

page = replace_exact(
    page,
    "'保存后会一次性创建学生档案、学科画像和主负责关系。请先确认负责老师已把该学科配置为可教学科。',",
    "'先填写学生姓名、服务学科和负责老师；保存后会一次完成建档和首个负责关系。其他资料需要时再展开填写。',",
    label='student setup intro copy',
)

old_early_optional = """                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _studentCodeController,
                        maxLength: 80,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '学生编号',
                          hintText: '可选',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        controller: _gradeController,
                        maxLength: 120,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '年级',
                          hintText: '可选',
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _classNameController,
                        maxLength: 120,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '班级',
                          hintText: '可选',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        controller: _campusController,
                        maxLength: 120,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '校区',
                          hintText: '可选',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
"""
page = replace_exact(
    page,
    old_early_optional,
    "                const SizedBox(height: AppSpacing.sm),\n",
    label='remove optional fields from primary path',
)

old_learning_optional = """                const SizedBox(height: AppSpacing.md),
                Text('学情定位（可选）', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _positioningController,
                  maxLength: 2000,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: '例如：函数基础需要持续巩固',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _strengthsController,
                  maxLength: 2000,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '已有优势',
                    hintText: '例如：愿意复盘错题',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _cadenceNoteController,
                  maxLength: 160,
                  maxLines: 1,
                  decoration: const InputDecoration(
                    labelText: '跟进节奏',
                    hintText: '例如：每周一次',
                    border: OutlineInputBorder(),
                  ),
                ),
"""
new_optional = """                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('student-setup-optional-toggle'),
                    onPressed: _busy
                        ? null
                        : () => setState(
                            () => _showOptionalDetails = !_showOptionalDetails,
                          ),
                    icon: Icon(
                      _showOptionalDetails
                          ? Icons.expand_less
                          : Icons.add_circle_outline,
                      size: 18,
                    ),
                    label: Text(
                      _showOptionalDetails ? '收起补充信息' : '补充信息（可选）',
                    ),
                  ),
                ),
                if (_showOptionalDetails) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '这些信息不是建档必填项；如果现在已知，可以一起保存。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    key: const Key('student-setup-code-field'),
                    controller: _studentCodeController,
                    maxLength: 80,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '学生编号',
                      hintText: '可选',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextFormField(
                    controller: _gradeController,
                    maxLength: 120,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '年级',
                      hintText: '可选',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextFormField(
                    controller: _classNameController,
                    maxLength: 120,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '班级',
                      hintText: '可选',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextFormField(
                    controller: _campusController,
                    maxLength: 120,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '校区',
                      hintText: '可选',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('学情背景（可选）', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  TextFormField(
                    controller: _positioningController,
                    maxLength: 2000,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '当前定位',
                      hintText: '例如：函数基础需要持续巩固',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _strengthsController,
                    maxLength: 2000,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '已有优势',
                      hintText: '例如：愿意复盘错题',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _cadenceNoteController,
                    maxLength: 160,
                    maxLines: 1,
                    decoration: const InputDecoration(
                      labelText: '跟进节奏',
                      hintText: '例如：每周一次',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
"""
page = replace_exact(
    page,
    old_learning_optional,
    new_optional,
    label='optional details disclosure',
)

page = replace_exact(
    page,
    ": const Text('保存并配置'),",
    ": const Text('添加学生'),",
    label='student setup primary action',
)

page_path.write_text(page)


test_path = Path('test/features/organization_management_test.dart')
tests = test_path.read_text()
tests = replace_exact(
    tests,
    """    expect(find.text('学生姓名 *'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '新学生');
    await tester.tap(find.text('保存并配置'));
""",
    """    expect(find.text('学生姓名 *'), findsOneWidget);
    expect(find.text('服务学科 *'), findsOneWidget);
    expect(find.text('负责老师 *'), findsOneWidget);
    expect(find.text('学生编号'), findsNothing);
    expect(find.text('年级'), findsNothing);
    expect(find.text('学情背景（可选）'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, '新学生');
    await tester.tap(find.widgetWithText(FilledButton, '添加学生'));
""",
    label='minimal student create regression',
)

anchor = """  testWidgets('rapid taps open only one add flow at a time', (tester) async {
"""
new_test = """  testWidgets('keeps optional student details behind one disclosure', (
    tester,
  ) async {
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
    );
    await _pumpManagement(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, '添加学生'));
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('student-setup-optional-toggle'));
    expect(toggle, findsOneWidget);
    expect(find.text('学生编号'), findsNothing);
    expect(find.text('年级'), findsNothing);
    expect(find.text('班级'), findsNothing);
    expect(find.text('校区'), findsNothing);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.text('学生编号'), findsOneWidget);
    expect(find.text('年级'), findsOneWidget);
    expect(find.text('班级'), findsOneWidget);
    expect(find.text('校区'), findsOneWidget);
    expect(find.text('学情背景（可选）'), findsOneWidget);
    final codeField = find.byKey(const Key('student-setup-code-field'));
    await tester.enterText(codeField, 'S-001');

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(codeField, findsNothing);
    expect(find.text('补充信息（可选）'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(codeField).controller?.text,
      'S-001',
    );
  });

  testWidgets('rapid taps open only one add flow at a time', (tester) async {
"""
tests = replace_exact(tests, anchor, new_test, label='optional disclosure regression')

test_path.write_text(tests)
