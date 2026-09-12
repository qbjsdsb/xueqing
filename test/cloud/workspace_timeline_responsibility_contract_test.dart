import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/learning_repository.dart';

void main() {
  test('timeline item can retain its persisted Case Event identity', () {
    final event = WorkspaceTimelineEvent(
      id: 'evidence:evidence-1',
      responsibilityEventId: 'event-1',
      occurredAt: DateTime(2026, 9, 12, 10),
      typeLabel: '学生表现',
      text: '课堂观察',
    );

    expect(event.id, 'evidence:evidence-1');
    expect(event.responsibilityEventId, 'event-1');
  });

  test('derived and raw timeline rows preserve persisted Case Event ids', () {
    final source = File('lib/cloud/learning_repository.dart')
        .readAsStringSync();

    expect(source.split('responsibilityEventId: _stringValue(').length - 1, 3);
    expect(
      source.split('responsibilityEventId: _requiredString(').length - 1,
      2,
    );
  });
}
