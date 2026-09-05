import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_models.dart';

abstract interface class StudentRepository {
  Future<CloudUserContext> loadContext();
}

/// Loads the small context summary used by the Cloud Spike page.
///
/// The Teacher Workspace uses [SupabaseLearningRepository]. This compatibility
/// summary deliberately keeps the old interface while reading the canonical
/// identity and access tables.
class SupabaseStudentRepository implements StudentRepository {
  SupabaseStudentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CloudUserContext> loadContext() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }

    final expectedUserId = authUser.id;
    final appUser = await _client
        .from('app_users')
        .select('id,display_name')
        .eq('auth_provider', 'supabase')
        .eq('auth_subject_id', expectedUserId)
        .eq('status', 'active')
        .maybeSingle();
    _assertSameSession(expectedUserId);

    final displayName =
        appUser?['display_name'] as String? ?? authUser.email ?? 'Unknown user';
    final appUserId = appUser?['id'] as String?;
    if (appUserId == null) {
      return _contextWithoutActiveMembership(
        displayName: displayName,
        email: authUser.email,
      );
    }

    final membership = await _client
        .from('organization_memberships')
        .select('id,organization_id')
        .eq('app_user_id', appUserId)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();
    _assertSameSession(expectedUserId);

    if (membership == null) {
      return _contextWithoutActiveMembership(
        displayName: displayName,
        email: authUser.email,
      );
    }

    final membershipId = membership['id'] as String?;
    final organizationId = membership['organization_id'] as String?;
    if (membershipId == null || organizationId == null) {
      throw const FormatException(
        'Membership did not include an organization.',
      );
    }

    final role = await _client
        .from('membership_roles')
        .select('role')
        .eq('membership_id', membershipId)
        .limit(1)
        .maybeSingle();
    _assertSameSession(expectedUserId);

    final organization = await _client
        .from('organizations')
        .select('name')
        .eq('id', organizationId)
        .maybeSingle();
    _assertSameSession(expectedUserId);

    final students = await _client
        .from('students')
        .select('id')
        .eq('organization_id', organizationId)
        .eq('status', 'active');
    _assertSameSession(expectedUserId);

    return CloudUserContext(
      userDisplayName: displayName,
      userEmail: authUser.email ?? '—',
      organizationName:
          organization?['name'] as String? ?? 'Unknown organization',
      role: role?['role'] as String? ?? 'unknown',
      accessibleStudentCount: students.length,
    );
  }

  CloudUserContext _contextWithoutActiveMembership({
    required String displayName,
    required String? email,
  }) {
    return CloudUserContext(
      userDisplayName: displayName,
      userEmail: email ?? '—',
      organizationName: '无活动机构',
      role: '—',
      accessibleStudentCount: 0,
    );
  }

  void _assertSameSession(String expectedUserId) {
    if (_client.auth.currentUser?.id != expectedUserId) {
      throw const AuthException(
        'The active session changed while loading user context.',
      );
    }
  }
}
