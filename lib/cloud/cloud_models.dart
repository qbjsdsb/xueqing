class CloudUserContext {
  const CloudUserContext({
    required this.userDisplayName,
    required this.userEmail,
    required this.organizationName,
    required this.role,
    required this.accessibleStudentCount,
  });

  final String userDisplayName;
  final String userEmail;
  final String organizationName;
  final String role;
  final int accessibleStudentCount;
}
