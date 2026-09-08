import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/learning_repository.dart';

void main() {
  group('QuickCaptureCommand', () {
    test('allows recording a classroom fact without manufacturing an Action', () {
      final command = _command();

      expect(command.nextActionTitle, isNull);
      expect(command.nextActionDueAt, isNull);
      expect(command.validate, returnsNormally);
    });

    test('rejects an explicit blank Action title', () {
      final command = _command(nextActionTitle: '   ');

      expect(command.validate, throwsArgumentError);
    });

    test('rejects an Action date without an explicit Action title', () {
      final command = _command(nextActionDueAt: DateTime(2026, 9, 15));

      expect(command.validate, throwsArgumentError);
    });

    test('keeps explicit reminders compatible', () {
      final command = _command(
        nextActionTitle: '下周抽查一次同类阅读题',
        nextActionDueAt: DateTime(2026, 9, 15),
      );

      expect(command.validate, returnsNormally);
    });
  });

  group('QuickCaptureReceipt', () {
    test('parses a server receipt without action_id', () {
      final receipt = QuickCaptureReceipt.fromJson(<String, dynamic>{
        'operation_id': 'operation-1',
        'case_id': 'case-1',
        'evidence_id': 'evidence-1',
        'action_id': null,
        'status': 'new',
        'case_version': 1,
      });

      expect(receipt.actionId, isNull);
      expect(receipt.caseId, 'case-1');
      expect(receipt.evidenceId, 'evidence-1');
    });
  });
}

QuickCaptureCommand _command({
  String? nextActionTitle,
  DateTime? nextActionDueAt,
}) {
  return QuickCaptureCommand(
    operationId: 'operation-1',
    profileId: 'profile-1',
    expectedProfileVersion: 1,
    caseType: LearningCaseType.knowledge,
    title: '阅读题漏看限制词',
    description: '课堂快速记录',
    observedAt: DateTime(2026, 9, 8, 15),
    evidenceSummary: '学生今天读题时两次漏看限制词。',
    nextActionTitle: nextActionTitle,
    nextActionDueAt: nextActionDueAt,
  );
}
