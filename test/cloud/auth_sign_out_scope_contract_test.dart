import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ordinary sign-out only clears the current device session', () {
    final source = File('lib/cloud/auth_repository.dart').readAsStringSync();
    const localDefault = 'Future<void> signOut({bool global = false})';
    const oldGlobalDefault = 'Future<void> signOut({bool global = true})';

    expect(
      localDefault.allMatches(source).length,
      2,
      reason: 'Both the interface and Supabase implementation must default ordinary sign-out to local scope.',
    );
    expect(
      source,
      isNot(contains(oldGlobalDefault)),
      reason: 'Ordinary sign-out must never silently revoke other devices.',
    );
    expect(
      source,
      contains('scope: global ? SignOutScope.global : SignOutScope.local'),
      reason: 'Explicit global sign-out must remain available for a future all-device action.',
    );
  });
}
