from pathlib import Path


def once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)


rows_path = Path('lib/features/organization_management/presentation/organization_management_rows.dart')
rows = rows_path.read_text()
rows = once(
    rows,
    'class _OrganizationStudentTile extends StatelessWidget {\n',
    'enum _StudentMoreAction { edit, toggleTeaching, toggleArchive }\n\nclass _OrganizationStudentTile extends StatelessWidget {\n',
    'student more action enum',
)
old_actions = r'''          if (onAddSubject != null ||
              onToggleTeaching != null ||
              onToggleArchive != null ||
              onEdit != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (onAddSubject != null)
                  TextButton.icon(
                    onPressed: busy ? null : onAddSubject,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('添加学科'),
                  ),
                if (onToggleTeaching != null)
                  TextButton.icon(
                    key: ValueKey<String>(
                      'student-teaching-toggle-${student.studentId}',
                    ),
                    onPressed: busy ? null : onToggleTeaching,
                    icon: Icon(
                      student.isActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 18,
                    ),
                    label: Text(student.isActive ? '暂停教学' : '恢复教学'),
                  ),
                if (onToggleArchive != null)
                  TextButton.icon(
                    key: ValueKey<String>(
                      'student-archive-toggle-${student.studentId}',
                    ),
                    onPressed: busy ? null : onToggleArchive,
                    icon: Icon(
                      student.status == 'archived'
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      size: 18,
                    ),
                    label: Text(student.status == 'archived' ? '取消归档' : '归档学生'),
                  ),
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('编辑'),
                  ),
              ],
            ),
          ],
'''
new_actions = r'''          if (onAddSubject != null ||
              onToggleTeaching != null ||
              onToggleArchive != null ||
              onEdit != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (onAddSubject != null)
                  TextButton.icon(
                    onPressed: busy ? null : onAddSubject,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('添加学科'),
                  ),
                if (onToggleTeaching != null ||
                    onToggleArchive != null ||
                    onEdit != null)
                  PopupMenuButton<_StudentMoreAction>(
                    key: ValueKey<String>(
                      'student-more-actions-${student.studentId}',
                    ),
                    tooltip: '更多操作',
                    enabled: !busy,
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (action) {
                      switch (action) {
                        case _StudentMoreAction.edit:
                          onEdit?.call();
                        case _StudentMoreAction.toggleTeaching:
                          onToggleTeaching?.call();
                        case _StudentMoreAction.toggleArchive:
                          onToggleArchive?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      if (onEdit != null)
                        PopupMenuItem<_StudentMoreAction>(
                          key: ValueKey<String>(
                            'student-edit-${student.studentId}',
                          ),
                          value: _StudentMoreAction.edit,
                          child: const Text('编辑资料'),
                        ),
                      if (onToggleTeaching != null)
                        PopupMenuItem<_StudentMoreAction>(
                          key: ValueKey<String>(
                            'student-teaching-toggle-${student.studentId}',
                          ),
                          value: _StudentMoreAction.toggleTeaching,
                          child: Text(
                            student.isActive ? '暂停教学' : '恢复教学',
                          ),
                        ),
                      if (onToggleArchive != null)
                        PopupMenuItem<_StudentMoreAction>(
                          key: ValueKey<String>(
                            'student-archive-toggle-${student.studentId}',
                          ),
                          value: _StudentMoreAction.toggleArchive,
                          child: Text(
                            student.status == 'archived'
                                ? '取消归档'
                                : '归档学生',
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ],
'''
rows = once(rows, old_actions, new_actions, 'student low-frequency action disclosure')
rows_path.write_text(rows)


actions_path = Path('lib/features/organization_management/presentation/organization_management_learning_actions.dart')
actions = actions_path.read_text()
actions = once(
    actions,
    '暂停后，这位学生会暂时从老师工作台和今日事项中隐藏；学科档案、当前任课、Case、证据和待办都会原样保留，恢复后继续原来的教学上下文。',
    '暂停后，这位学生会暂时从老师工作台和今日事项中隐藏；学科档案、当前任课、跟进问题、证据和待办都会原样保留，恢复后继续原来的教学上下文。',
    'pause teacher-facing case wording',
)
actions = once(
    actions,
    '恢复后，这位学生会重新出现在有当前任课关系的老师工作台中；原学科、Case、证据和待办继续有效，不会重新建档。',
    '恢复后，这位学生会重新出现在有当前任课关系的老师工作台中；原学科、跟进问题、证据和待办继续有效，不会重新建档。',
    'resume teacher-facing case wording',
)
actions = once(
    actions,
    '归档用于学生长期结束服务或离开机构后的历史保留。已有学科、Case、证据和历史记录不会删除；若只是暂时停课，请不要归档。',
    '归档用于学生长期结束服务或离开机构后的历史保留。已有学科、跟进问题、证据和历史记录不会删除；若只是暂时停课，请不要归档。',
    'archive teacher-facing case wording',
)
actions_path.write_text(actions)


test_path = Path('test/features/organization_management_test.dart')
test = test_path.read_text()
helper_anchor = r'''Future<void> _selectManagementArea(WidgetTester tester, String label) async {
  final key = switch (label) {
    '成员' => const Key('management-area-people'),
    '学生' => const Key('management-area-students'),
    '设置' => const Key('management-area-settings'),
    _ => throw ArgumentError.value(label, 'label', 'Unknown management area'),
  };
  final target = find.byKey(key);
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}
'''
helper_new = helper_anchor + r'''
Future<void> _openStudentMoreActions(
  WidgetTester tester, {
  String studentId = 'student-1',
}) async {
  final more = find.byKey(
    ValueKey<String>('student-more-actions-$studentId'),
  );
  expect(more, findsOneWidget);
  await tester.ensureVisible(more);
  await tester.tap(more);
  await tester.pumpAndSettle();
}
'''
test = once(test, helper_anchor, helper_new, 'student more actions test helper')

pause_anchor = r'''      await _pumpManagement(tester, repository);
      await _selectManagementArea(tester, '学生');

      final pause = find.byKey(
        const ValueKey<String>('student-teaching-toggle-student-1'),
      );
'''
pause_new = r'''      await _pumpManagement(tester, repository);
      await _selectManagementArea(tester, '学生');
      expect(find.text('暂停教学'), findsNothing);
      await _openStudentMoreActions(tester);

      final pause = find.byKey(
        const ValueKey<String>('student-teaching-toggle-student-1'),
      );
'''
test = once(test, pause_anchor, pause_new, 'pause opens more menu')
test = once(
    test,
    '暂停后，这位学生会暂时从老师工作台和今日事项中隐藏；学科档案、当前任课、Case、证据和待办都会原样保留，恢复后继续原来的教学上下文。',
    '暂停后，这位学生会暂时从老师工作台和今日事项中隐藏；学科档案、当前任课、跟进问题、证据和待办都会原样保留，恢复后继续原来的教学上下文。',
    'pause test wording',
)
resume_anchor = r'''      expect(repository.studentTeacherAssignments.single.status, 'active');
      expect(find.text('暂不教学'), findsOneWidget);

      final resume = find.byKey(
        const ValueKey<String>('student-teaching-toggle-student-1'),
      );
'''
resume_new = r'''      expect(repository.studentTeacherAssignments.single.status, 'active');
      expect(find.text('暂不教学'), findsOneWidget);
      expect(find.text('恢复教学'), findsNothing);
      await _openStudentMoreActions(tester);

      final resume = find.byKey(
        const ValueKey<String>('student-teaching-toggle-student-1'),
      );
'''
test = once(test, resume_anchor, resume_new, 'resume opens more menu')

temporary_anchor = r'''      await _pumpManagement(tester, repository);
      await _selectManagementArea(tester, '学生');

      expect(find.text('暂不教学'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('student-archive-toggle-student-1')),
        findsNothing,
      );
      expect(find.text('恢复教学'), findsOneWidget);
'''
temporary_new = r'''      await _pumpManagement(tester, repository);
      await _selectManagementArea(tester, '学生');

      expect(find.text('暂不教学'), findsOneWidget);
      expect(find.text('恢复教学'), findsNothing);
      await _openStudentMoreActions(tester);
      expect(
        find.byKey(const ValueKey<String>('student-archive-toggle-student-1')),
        findsNothing,
      );
      expect(find.text('恢复教学'), findsOneWidget);
'''
test = once(test, temporary_anchor, temporary_new, 'paused student menu test')

archive_anchor = r'''      await _pumpManagement(tester, repository);
      await _selectManagementArea(tester, '学生');

      final archive = find.byKey(
        const ValueKey<String>('student-archive-toggle-student-1'),
      );
'''
archive_new = r'''      await _pumpManagement(tester, repository);
      await _selectManagementArea(tester, '学生');
      expect(find.text('归档学生'), findsNothing);
      await _openStudentMoreActions(tester);

      final archive = find.byKey(
        const ValueKey<String>('student-archive-toggle-student-1'),
      );
'''
test = once(test, archive_anchor, archive_new, 'archive opens more menu')
test = once(
    test,
    '归档用于学生长期结束服务或离开机构后的历史保留。已有学科、Case、证据和历史记录不会删除；若只是暂时停课，请不要归档。',
    '归档用于学生长期结束服务或离开机构后的历史保留。已有学科、跟进问题、证据和历史记录不会删除；若只是暂时停课，请不要归档。',
    'archive test wording',
)
unarchive_anchor = r'''      expect(find.text('已归档'), findsOneWidget);
      expect(find.text('恢复教学'), findsNothing);
      expect(find.text('取消归档'), findsOneWidget);

      final unarchive = find.byKey(
        const ValueKey<String>('student-archive-toggle-student-1'),
      );
'''
unarchive_new = r'''      expect(find.text('已归档'), findsOneWidget);
      expect(find.text('恢复教学'), findsNothing);
      expect(find.text('取消归档'), findsNothing);
      await _openStudentMoreActions(tester);
      expect(find.text('取消归档'), findsOneWidget);

      final unarchive = find.byKey(
        const ValueKey<String>('student-archive-toggle-student-1'),
      );
'''
test = once(test, unarchive_anchor, unarchive_new, 'unarchive opens more menu')
after_unarchive_anchor = r'''      expect(find.text('暂不教学'), findsOneWidget);
      expect(find.text('恢复教学'), findsOneWidget);
      expect(find.text('归档学生'), findsOneWidget);
'''
after_unarchive_new = r'''      expect(find.text('暂不教学'), findsOneWidget);
      expect(find.text('恢复教学'), findsNothing);
      expect(find.text('归档学生'), findsNothing);
      await _openStudentMoreActions(tester);
      expect(find.text('恢复教学'), findsOneWidget);
      expect(find.text('归档学生'), findsOneWidget);
'''
test = once(test, after_unarchive_anchor, after_unarchive_new, 'post unarchive menu labels')

edit_anchor = r'''    expect(find.text('原学生'), findsOneWidget);
    final editButton = find.text('编辑');
    await tester.ensureVisible(editButton);
    await tester.tap(editButton);
'''
edit_new = r'''    expect(find.text('原学生'), findsOneWidget);
    expect(find.text('编辑资料'), findsNothing);
    await _openStudentMoreActions(tester);
    final editButton = find.byKey(
      const ValueKey<String>('student-edit-student-1'),
    );
    await tester.tap(editButton);
'''
test = once(test, edit_anchor, edit_new, 'edit opens more menu')

narrow_anchor = r'''  testWidgets(
    'manager pauses and resumes teaching without rewriting subject context',
'''
narrow_test = r'''  testWidgets('student management stays focused on narrow Android width', (
    tester,
  ) async {
    final originalPhysicalSize = tester.view.physicalSize;
    final originalDevicePixelRatio = tester.view.devicePixelRatio;
    addTearDown(() {
      tester.view.physicalSize = originalPhysicalSize;
      tester.view.devicePixelRatio = originalDevicePixelRatio;
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);

    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
      students: [_studentRecord()],
      studentTeacherAssignments: [_studentTeacherAssignment()],
    );
    await _pumpManagement(tester, repository);
    await _selectManagementArea(tester, '学生');

    final addSubject = find.widgetWithText(TextButton, '添加学科');
    await tester.ensureVisible(addSubject);
    expect(addSubject, findsOneWidget);
    final transfer = find.byKey(
      const ValueKey<String>('student-assignment-transfer-assignment-1'),
    );
    await tester.ensureVisible(transfer);
    expect(transfer, findsOneWidget);
    expect(find.text('暂停教学'), findsNothing);
    expect(find.text('编辑资料'), findsNothing);
    expect(tester.takeException(), isNull);

    await _openStudentMoreActions(tester);
    expect(find.text('暂停教学'), findsOneWidget);
    expect(find.text('编辑资料'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

'''
test = once(test, narrow_anchor, narrow_test + narrow_anchor, 'narrow Android management regression')
test_path.write_text(test)
