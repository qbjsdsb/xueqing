import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('supabase/functions/organization-member-credentials/index.ts')
        .readAsStringSync();
  });

  test('keeps hosted runtime failures public and actionable', () {
    for (final code in <String>[
      'credential_update_failed',
      'member_provisioning_failed',
      'member_provisioning_unavailable',
      'provision_cleanup_required',
      'provision_recovery_required',
      'role_not_allowed',
      'user_already_member_elsewhere',
    ]) {
      expect(source, contains('"$code"'));
    }
    expect(source, contains('candidate.details'));
    expect(source, contains('candidate.hint'));
    expect(source, contains('message.includes(code)'));
  });

  test('accepts canonical UUID shape without depending on version bits', () {
    expect(
      source,
      contains(
        r'/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i',
      ),
    );
    expect(source, isNot(contains(r'[1-5][0-9a-f]{3}')));
  });

  test('preserves safe uncertain-provisioning recovery contract', () {
    expect(source, contains('app_metadata'));
    expect(source, contains('reconcileCommittedProvisioning'));
    expect(source, contains('recoverMarkedProvisioningUser'));
    expect(source, contains('revoke_member_auth_sessions'));
    expect(source, isNot(contains('.deleteUser(')));
  });
}
