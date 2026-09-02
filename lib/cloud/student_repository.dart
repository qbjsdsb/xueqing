import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_models.dart';

abstract interface class StudentRepository {
  Future<CloudUserContext> loadContext();
}

class SupabaseStudentRepository implements StudentRepository {
  SupabaseStudentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CloudUserContext> loadContext() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }

    final appUser = await _client
        .from('app_users')
        .select('display_name')
        .maybeSingle();

    final displayName =
        appUser?['display_name'] as String? ?? authUser.email ?? 'Unknown user';

    final membership = await _client
        .from('memberships')
        .select('organization_id,role')
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();

    if (membership == null) {
      return CloudUserContext(
        userDisplayName: displayName,
        userEmail: authUser.email ?? '—',
        organizationName: '无活动机构',
        role: '—',
        accessibleStudentCount: 0,
      );
    }

    final organizationId = membership['organization_id'] as String?;
    if (organizationId == null) {
      throw const FormatException(
        'Membership did not include an organization.',
      );
    }

    final organization = await _client
        .from('organizations')
        .select('name')
        .eq('id', organizationId)
        .maybeSingle();

    final students = await _client
        .from('students')
        .select('id')
        .eq('status', 'active');

    return CloudUserContext(
      userDisplayName: displayName,
      userEmail: authUser.email ?? '—',
      organizationName:
          organization?['name'] as String? ?? 'Unknown organization',
      role: membership['role'] as String? ?? 'unknown',
      accessibleStudentCount: students.length,
    );
  }
}
