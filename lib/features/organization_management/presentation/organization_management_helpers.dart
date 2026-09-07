part of 'organization_management_page.dart';

String _teacherScopeKey(String membershipId, String subjectId) =>
    '$membershipId|$subjectId';

Set<String> _latestEndedTeacherScopeIds(
  List<OrganizationTeacherSubjectScope> scopes,
) {
  final latestByKey = <String, OrganizationTeacherSubjectScope>{};
  for (final scope in scopes) {
    if (!scope.isEnded || scope.membershipStatus != 'active') continue;
    final key = _teacherScopeKey(
      scope.membershipId,
      scope.organizationSubjectId,
    );
    final current = latestByKey[key];
    if (current == null ||
        (scope.activeTo != null &&
            (current.activeTo == null ||
                !scope.activeTo!.isBefore(current.activeTo!))) ||
        (scope.activeTo == current.activeTo &&
            scope.scopeId.compareTo(current.scopeId) > 0)) {
      latestByKey[key] = scope;
    }
  }
  return latestByKey.values.map((scope) => scope.scopeId).toSet();
}

String _studentAssignmentRoleLabel(String role) {
  return switch (role) {
    'lead' => '主责老师',
    'collaborator' => '协作老师',
    _ => '任课老师',
  };
}

String _formatDateOnly(DateTime? value) {
  if (value == null) return '—';
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _roleSummary(List<String> roles) {
  final labels = <String>[
    for (final role in roles)
      if (_roleLabel(role) != role) _roleLabel(role),
  ];
  return labels.isEmpty ? '机构成员' : labels.join('、');
}

String _roleLabel(String role) {
  return switch (role) {
    'org_owner' => '负责人',
    'org_admin' => '管理员',
    'academic_admin' => '管理员（旧角色）',
    'subject_lead' => '学科负责人（旧角色已停用）',
    'teacher' => '老师',
    'student_advisor' => '学生导师（旧角色已停用）',
    _ => role,
  };
}

String _studentStatusLabel(String status) {
  return switch (status) {
    'active' => '正常教学',
    'inactive' => '暂不教学',
    'archived' => '已归档',
    'merged' => '已合并',
    _ => '状态未知',
  };
}

String _membershipStatusLabel(String status) {
  return switch (status) {
    'active' => '正常',
    'onboarding' => '待完成接管',
    'disabled' => '已停用',
    _ => '状态未知',
  };
}

String _invitationStatusLabel(String status) {
  return switch (status) {
    'pending_owner_approval' => '待负责人审批',
    'pending' => '待开通',
    'expired' => '已过期',
    'revoked' => '已撤销',
    'accepted' => '已接受',
    _ => '状态未知',
  };
}

String _formatDateTime(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  String pad(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${pad(local.month)}-${pad(local.day)} '
      '${pad(local.hour)}:${pad(local.minute)}';
}
