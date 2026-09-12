from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 anchor, found {count}")
    return text.replace(old, new, 1)


learning = Path(
    "lib/features/organization_management/presentation/organization_management_learning_actions.dart"
)
text = learning.read_text()

text = replace_once(
    text,
    """      if (!mounted || result == null) return;
      await _refresh();
      if (!mounted) return;
      widget.onChanged?.call();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已添加学科：${result.subjectName}。')));
""",
    """      if (!mounted || result == null) return;
      await _finishCommittedMutation(
        successMessage: '已添加学科：${result.subjectName}。',
      );
""",
    "add subject committed refresh",
)

text = replace_once(
    text,
    """        await _refresh();
        if (!mounted) return;
        widget.onChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已将 ${assignment.studentName} 的 ${assignment.subjectName} '
              '${_studentAssignmentRoleLabel(assignment.assignmentRole)}交接给 '
              '${result.replacementTeacherName}；同时迁移 '
              '${plan.affectedCases.length} 个问题、${plan.affectedActions.length} 个行动。',
            ),
          ),
        );
""",
    """        await _finishCommittedMutation(
          successMessage:
              '已将 ${assignment.studentName} 的 ${assignment.subjectName} '
              '${_studentAssignmentRoleLabel(assignment.assignmentRole)}交接给 '
              '${result.replacementTeacherName}；同时迁移 '
              '${plan.affectedCases.length} 个问题、${plan.affectedActions.length} 个行动。',
        );
""",
    "handoff committed refresh",
)

text = replace_once(
    text,
    """      if (!mounted || result == null) return;
      await _refresh();
      if (!mounted) return;
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已添加 ${result.studentName} · ${result.subjectName} · '
            '${result.teacherDisplayName}',
          ),
        ),
      );
""",
    """      if (!mounted || result == null) return;
      await _finishCommittedMutation(
        successMessage:
            '已添加 ${result.studentName} · ${result.subjectName} · '
            '${result.teacherDisplayName}',
      );
""",
    "add student committed refresh",
)

text = replace_once(
    text,
    """      if (!mounted || result == null) return;
      await _refresh();
      if (!mounted) return;
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已更新 ${result.studentName} 的基础资料。')),
      );
""",
    """      if (!mounted || result == null) return;
      await _finishCommittedMutation(
        successMessage: '已更新 ${result.studentName} 的基础资料。',
      );
""",
    "edit student committed refresh",
)
learning.write_text(text)

member = Path(
    "lib/features/organization_management/presentation/organization_management_member_actions.dart"
)
text = member.read_text()

text = replace_once(
    text,
    """      await _refresh();
      if (!mounted) return;
      widget.onChanged?.call();
      final displayName = member.displayName ?? member.email;
      final message = result.status == 'disabled'
          ? '已停用 $displayName；结束了 ${result.endedScopeCount + result.endedAssignmentCount} 条当前教学关系。'
          : '已恢复 $displayName 的机构访问；需要的教学关系请重新配置。';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
""",
    """      final displayName = member.displayName ?? member.email;
      final message = result.status == 'disabled'
          ? '已停用 $displayName；结束了 ${result.endedScopeCount + result.endedAssignmentCount} 条当前教学关系。'
          : '已恢复 $displayName 的机构访问；需要的教学关系请重新配置。';
      await _finishCommittedMutation(successMessage: message);
""",
    "member status committed refresh",
)

text = replace_once(
    text,
    """      if (mounted) await _refresh();
""",
    """      if (mounted) await _finishCommittedMutation();
""",
    "invite member committed refresh",
)

text = replace_once(
    text,
    """      await _refresh();
      if (!mounted) return;
      widget.onChanged?.call();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已更新成员姓名：${result.displayName}。')));
""",
    """      await _finishCommittedMutation(
        successMessage: '已更新成员姓名：${result.displayName}。',
      );
""",
    "member name committed refresh",
)

text = replace_once(
    text,
    """      if (mounted) {
        await _showProvisioningResult(result);
        await _refresh();
      }
""",
    """      if (mounted) {
        await _showProvisioningResult(result);
        await _finishCommittedMutation();
      }
""",
    "provision invitation committed refresh",
)

text = replace_once(
    text,
    """      if (mounted) {
        await _showTemporaryPassword(result);
        await _refresh();
      }
""",
    """      if (mounted) {
        await _showTemporaryPassword(result);
        await _finishCommittedMutation();
      }
""",
    "reissue credential committed refresh",
)
member.write_text(text)

test = Path("test/features/organization_management_test.dart")
text = test.read_text()

text = replace_once(
    text,
    """  int assignmentTransferCount = 0;
  int handoffPreviewCount = 0;
  int handoffCommitCount = 0;
  int studentSubjectAddCount = 0;
""",
    """  int assignmentTransferCount = 0;
  int handoffPreviewCount = 0;
  int handoffCommitCount = 0;
  int listStudentsCount = 0;
  bool failNextListStudents = false;
  int studentSubjectAddCount = 0;
""",
    "fake refresh controls",
)

text = replace_once(
    text,
    """  Future<List<OrganizationStudentRecord>> listStudents({
    required String organizationId,
  }) async {
    return students;
  }
""",
    """  Future<List<OrganizationStudentRecord>> listStudents({
    required String organizationId,
  }) async {
    listStudentsCount++;
    if (failNextListStudents) {
      failNextListStudents = false;
      throw StateError('simulated refresh failure');
    }
    return students;
  }
""",
    "fake listStudents failure",
)

approval_anchor = """  testWidgets('admin can view members but cannot disable them', (tester) async {
"""
approval_test = """  testWidgets(
    'committed mutation reports refresh failure without pretending the write failed',
    (tester) async {
      final repository = _FakeOrganizationManagementRepository(
        members: const [],
        invitations: [_ownerNomination()],
      );
      await _pumpManagement(tester, repository);

      repository.failNextListStudents = true;
      final approveFinder = find.text('通过负责人提名');
      await tester.ensureVisible(approveFinder);
      await tester.tap(approveFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(repository.approveCount, 1);
      expect(repository.listStudentsCount, greaterThanOrEqualTo(2));
      expect(find.textContaining('负责人提名已通过'), findsOneWidget);
      expect(find.textContaining('最新列表暂时没有刷新成功'), findsOneWidget);
      expect(find.textContaining('不要重复提交'), findsOneWidget);
      expect(find.textContaining('操作未完成'), findsNothing);
    },
  );

"""
if text.count(approval_anchor) != 1:
    raise SystemExit("approval test insertion anchor mismatch")
text = text.replace(approval_anchor, approval_test + approval_anchor, 1)

handoff_anchor = """  testWidgets('student subject shows lead and collaborator together', (
"""
handoff_test = """  testWidgets(
    'committed teaching handoff is not reported as failed when refresh fails',
    (tester) async {
      final repository = _FakeOrganizationManagementRepository(
        members: const [],
        invitations: const [],
        students: [_studentRecord()],
        studentTeacherAssignments: [_studentTeacherAssignment()],
        setupOptions: const OrganizationSetupOptions(
          subjects: [
            OrganizationSetupSubject(id: 'subject-1', displayName: '数学'),
          ],
          teachers: [
            OrganizationSetupTeacher(
              membershipId: 'membership-1',
              displayName: '原老师',
              email: 'old-teacher@example.com',
              organizationSubjectIds: ['subject-1'],
            ),
            OrganizationSetupTeacher(
              membershipId: 'membership-2',
              displayName: '新老师',
              email: 'new-teacher@example.com',
              organizationSubjectIds: ['subject-1'],
            ),
          ],
        ),
        teacherSubjectScopes: [
          OrganizationTeacherSubjectScope(
            scopeId: 'scope-1',
            membershipId: 'membership-1',
            organizationSubjectId: 'subject-1',
            teacherName: '原老师',
            teacherEmail: 'old-teacher@example.com',
            membershipStatus: 'active',
            subjectName: '数学',
            subjectCode: 'math',
            scopeKind: 'teaching',
            status: 'active',
            version: 1,
            activeFrom: DateTime(2026, 9, 1),
            activeTo: null,
          ),
          OrganizationTeacherSubjectScope(
            scopeId: 'scope-2',
            membershipId: 'membership-2',
            organizationSubjectId: 'subject-1',
            teacherName: '新老师',
            teacherEmail: 'new-teacher@example.com',
            membershipStatus: 'active',
            subjectName: '数学',
            subjectCode: 'math',
            scopeKind: 'teaching',
            status: 'active',
            version: 1,
            activeFrom: DateTime(2026, 9, 1),
            activeTo: null,
          ),
        ],
      );
      await _pumpManagement(tester, repository);

      final transferButton = find.byKey(
        const ValueKey<String>('student-assignment-transfer-assignment-1'),
      );
      await tester.ensureVisible(transferButton);
      await tester.tap(transferButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('继续核对'));
      await tester.pumpAndSettle();

      repository.failNextListStudents = true;
      await tester.tap(find.byKey(const ValueKey('handoff-confirm-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(repository.handoffCommitCount, 1);
      expect(repository.assignmentTransferCount, 1);
      expect(repository.updatedTeacherAssignment?.replacementTeacherName, '新老师');
      expect(
        find.textContaining('已将 原学生 的 数学 主责老师交接给 新老师'),
        findsOneWidget,
      );
      expect(find.textContaining('最新列表暂时没有刷新成功'), findsOneWidget);
      expect(find.textContaining('不要重复提交'), findsOneWidget);
      expect(find.textContaining('操作未完成'), findsNothing);
      // The visible list is intentionally allowed to remain stale until a
      // successful refresh; server truth must not be confused with UI freshness.
      expect(find.text('主责老师：原老师'), findsOneWidget);
    },
  );

"""
if text.count(handoff_anchor) != 1:
    raise SystemExit("handoff test insertion anchor mismatch")
text = text.replace(handoff_anchor, handoff_test + handoff_anchor, 1)
test.write_text(text)
