import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ordinary sign-out only clears the current device session', () {
    final source = File('lib/cloud/auth_repository.dart').readAsStringSync();

    expect(
      RegExp(r'Future<void> signOut\(\{bool global = false\}\);')
          .hasMatch(source),
      isTrue,
      reason: 'AuthRepository must default ordinary sign-out to local scope.',
    );
    expect(
      RegExp(r'Future<void> signOut\(\{bool global = false\}\)')
          .allMatches(source)
          .length,
      2,
      reason:
          'Both the interface and Supabase implementation must keep the local default.',
    );
    expect(
      source,
      contains('scope: global ? SignOutScope.global : SignOutScope.local'),
      reason:
          'Explicit global sign-out must remain available for a future all-device action.',
    );
  });
}
