from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    assert count == 1, f"{path}: expected 1 match, found {count}"
    path.write_text(text.replace(old, new, 1))


test = Path("test/features/organization_management_test.dart")

# Keep the fake mutation atomic like the real database transaction: resolve
# the eligible teacher before changing the in-memory student service state.
old_restore = '''    final target = services.firstWhere(
      (service) => service.profileId == studentSubjectProfileId,
    );
    students[studentIndex] = OrganizationStudentRecord(
      studentId: previous.studentId,
      studentName: previous.studentName,
      studentCode: previous.studentCode,
      status: previous.status,
      version: previous.version,
      grade: previous.grade,
      className: previous.className,
      campus: previous.campus,
      startsOn: previous.startsOn,
      endsOn: previous.endsOn,
      subjectNames: [
        for (final service in services)
          if (service.isActive) service.subjectName,
      ],
      subjectServices: services,
    );
    final teacher = setupOptions.teachers.firstWhere(
      (item) => item.membershipId == teacherMembershipId,
    );
    studentTeacherAssignments.add(
'''
new_restore = '''    final target = services.firstWhere(
      (service) => service.profileId == studentSubjectProfileId,
    );
    final eligibleTeachers = setupOptions.teachersForSubject(
      target.organizationSubjectId,
    );
    if (eligibleTeachers.isEmpty) {
      throw StateError('No eligible teacher for restored subject service.');
    }
    final teacher = eligibleTeachers.firstWhere(
      (item) => item.membershipId == teacherMembershipId,
      orElse: () => eligibleTeachers.first,
    );
    students[studentIndex] = OrganizationStudentRecord(
      studentId: previous.studentId,
      studentName: previous.studentName,
      studentCode: previous.studentCode,
      status: previous.status,
      version: previous.version,
      grade: previous.grade,
      className: previous.className,
      campus: previous.campus,
      startsOn: previous.startsOn,
      endsOn: previous.endsOn,
      subjectNames: [
        for (final service in services)
          if (service.isActive) service.subjectName,
      ],
      subjectServices: services,
    );
    studentTeacherAssignments.add(
'''
replace_once(test, old_restore, new_restore)

# The assignment section legitimately moves lower when a student row exposes
# per-subject lifecycle status. Tests must scroll to the interactive section
# instead of assuming it is inside a fixed 600px viewport.
replace_once(
    test,
    "    await tester.tap(find.text('任课老师与交接'));\n"
    "    await tester.pumpAndSettle();\n",
    "    final assignmentSection = find.text('任课老师与交接');\n"
    "    await tester.ensureVisible(assignmentSection);\n"
    "    await tester.tap(assignmentSection);\n"
    "    await tester.pumpAndSettle();\n",
)

# This test exercises a successful restore, so its fake assignment collection
# must be growable just like the database table it stands in for.
replace_once(
    test,
    "      invitations: const [],\n"
    "      students: [student],\n"
    "    );\n"
    "    await _pumpManagement(tester, repository);\n"
    "    await _selectManagementArea(tester, '学生');\n\n"
    "    final restoreButton = find.byKey(\n",
    "      invitations: const [],\n"
    "      students: [student],\n"
    "      studentTeacherAssignments: <OrganizationStudentTeacherAssignment>[],\n"
    "    );\n"
    "    await _pumpManagement(tester, repository);\n"
    "    await _selectManagementArea(tester, '学生');\n\n"
    "    final restoreButton = find.byKey(\n",
)
