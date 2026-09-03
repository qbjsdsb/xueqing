import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/session_request_guard.dart';

void main() {
  group('SessionRequestGuard', () {
    test('accepts the latest request for the same user', () {
      final guard = SessionRequestGuard();
      final request = guard.begin();

      expect(
        guard.isCurrent(
          request,
          expectedUserId: 'user-a',
          currentUserId: 'user-a',
        ),
        isTrue,
      );
    });

    test('rejects a result when the active user id changes', () {
      final guard = SessionRequestGuard();
      final requestForA = guard.begin();

      expect(
        guard.isCurrent(
          requestForA,
          expectedUserId: 'user-a',
          currentUserId: 'user-b',
        ),
        isFalse,
      );
    });

    test('rejects an earlier request after an account switch', () {
      final guard = SessionRequestGuard();
      final requestForA = guard.begin();

      guard.begin();

      expect(
        guard.isCurrent(
          requestForA,
          expectedUserId: 'user-a',
          currentUserId: 'user-b',
        ),
        isFalse,
      );
    });

    test('rejects in-flight work after sign-out invalidates the session', () {
      final guard = SessionRequestGuard();
      final request = guard.begin();

      guard.invalidate();

      expect(
        guard.isCurrent(
          request,
          expectedUserId: 'user-a',
          currentUserId: 'user-a',
        ),
        isFalse,
      );
    });
  });
}
