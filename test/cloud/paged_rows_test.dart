import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/paged_rows.dart';

void main() {
  test('collects every row beyond a one-thousand-row API limit', () async {
    final source = List<Map<String, dynamic>>.generate(
      1203,
      (index) => <String, dynamic>{'id': index},
    );
    final requestedRanges = <(int, int)>[];
    var sessionChecks = 0;

    final rows = await collectPagedRows(
      pageSize: 500,
      loadPage: (from, to) async {
        requestedRanges.add((from, to));
        if (from >= source.length) {
          return <Map<String, dynamic>>[];
        }
        final end = to + 1 < source.length ? to + 1 : source.length;
        return source.sublist(from, end);
      },
      assertSession: () => sessionChecks++,
      invalidResponseMessage: 'invalid rows',
    );

    expect(rows, hasLength(1203));
    expect(rows.first['id'], 0);
    expect(rows.last['id'], 1202);
    expect(requestedRanges, const [(0, 499), (500, 999), (1000, 1499)]);
    expect(sessionChecks, 3);
  });

  test('checks the active session after every page', () async {
    var pageLoads = 0;
    var sessionChecks = 0;

    await expectLater(
      collectPagedRows(
        pageSize: 2,
        loadPage: (from, to) async {
          pageLoads++;
          return <Map<String, dynamic>>[
            {'id': from},
            {'id': to},
          ];
        },
        assertSession: () {
          sessionChecks++;
          if (sessionChecks == 2) {
            throw StateError('session changed');
          }
        },
        invalidResponseMessage: 'invalid rows',
      ),
      throwsA(isA<StateError>()),
    );

    expect(pageLoads, 2);
    expect(sessionChecks, 2);
  });

  test('rejects malformed pages without returning partial data', () async {
    await expectLater(
      collectPagedRows(
        loadPage: (from, to) async => <Object>[
          {'id': 1},
          'invalid',
        ],
        assertSession: () {},
        invalidResponseMessage: 'invalid rows',
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'invalid rows',
        ),
      ),
    );
  });
}
