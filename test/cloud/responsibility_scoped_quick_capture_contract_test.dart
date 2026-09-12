import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('client scoped Quick Capture matches the v0.3.8 backend contract', () {
    final source = File(
      'lib/cloud/responsibility_scoped_learning_repository.dart',
    ).readAsStringSync();

    expect(source, contains("'quick_capture_case_in_scope'"));
    expect(source, contains("'p_workspace_scope': workspaceScope.wireValue"));
    expect(
      source,
      contains(
        "'p_expected_responsibility_membership_id': responsibilityMembershipId",
      ),
    );
    expect(source, contains("'p_organization_case_type_id': command.organizationCaseTypeId"));
    expect(source, contains("WorkspaceWriteScope.personal => 'personal'"));
    expect(source, contains("WorkspaceWriteScope.organization => 'organization'"));
    expect(source, contains('personal_responsibility_context_required'));
    expect(source, contains('personal_profile_responsibility_required'));
  });
}
