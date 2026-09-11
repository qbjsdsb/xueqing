from pathlib import Path

preview_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
preview = preview_path.read_text(encoding='utf-8')
preview = preview.replace(
    'DropdownButtonFormField<CaseVoidReason>(\n                      key: const Key(\'v2-void-reason\'),\n                      value: selectedReason,',
    'DropdownButtonFormField<CaseVoidReason>(\n                      key: const Key(\'v2-void-reason\'),\n                      initialValue: selectedReason,',
)
if 'initialValue: selectedReason' not in preview:
    raise SystemExit('void reason dropdown patch did not apply')
preview_path.write_text(preview, encoding='utf-8')

path = Path('test/features/design_v2_workflow_controller_test.dart')
source = path.read_text(encoding='utf-8')
old_test = '''    test('teacher case delete is an audited not-issue closure', () async {
      final progress = _FakeProgressiveCaseRepository();
      final controller = V2WorkflowController(
        workspace: _workspace(),
        learningRepository: _FakeLearningRepository(),
        progressiveCaseRepository: progress,
      );

      await controller.voidCase(
        operationId: 'operation-void-case',
        caseId: 'case-existing',
      );

      expect(progress.endCalls, hasLength(1));
      final command = progress.endCalls.single;
      expect(command.operationId, 'operation-void-case');
      expect(command.caseId, 'case-existing');
      expect(command.expectedCaseVersion, 3);
      expect(command.reason, CaseClosureReason.notIssue);
      expect(command.note, contains('删除/作废'));
    });
'''
new_test = '''    test('teacher case invalidation uses the dedicated record command', () async {
      final progress = _FakeProgressiveCaseRepository();
      final controller = V2WorkflowController(
        workspace: _workspace(),
        learningRepository: _FakeLearningRepository(),
        progressiveCaseRepository: progress,
      );

      await controller.voidCase(
        operationId: 'operation-void-case',
        caseId: 'case-existing',
        reason: CaseVoidReason.duplicate,
        note: '重复记录',
      );

      expect(progress.voidCalls, hasLength(1));
      final command = progress.voidCalls.single;
      expect(command.operationId, 'operation-void-case');
      expect(command.caseId, 'case-existing');
      expect(command.expectedCaseVersion, 3);
      expect(command.reason, CaseVoidReason.duplicate);
      expect(command.note, '重复记录');
      expect(progress.endCalls, isEmpty);
    });
'''
if old_test not in source:
    raise SystemExit('old controller void test not found')
source = source.replace(old_test, new_test)

old_decl = '''class _FakeProgressiveCaseRepository extends Fake
    implements ProgressiveCaseRepository {
'''
new_decl = '''class _FakeProgressiveCaseRepository extends Fake
    implements ProgressiveCaseRepository, LearningCaseRecordRepository {
'''
if old_decl not in source:
    raise SystemExit('fake progressive repository declaration not found')
source = source.replace(old_decl, new_decl)
source = source.replace(
    '''  final endCalls = <EndCaseFollowUpCommand>[];
  ProgressiveCaseReceipt receipt = const ProgressiveCaseReceipt(''',
    '''  final endCalls = <EndCaseFollowUpCommand>[];
  final voidCalls = <VoidLearningCaseCommand>[];
  final restoreCalls = <RestoreLearningCaseCommand>[];
  ProgressiveCaseReceipt receipt = const ProgressiveCaseReceipt(''',
)
insert_marker = '''  @override
  Future<ProgressiveCaseReceipt> endFollowUp(
    EndCaseFollowUpCommand command,
  ) async {
    endCalls.add(command);
    log?.add('end-follow-up');
    return ProgressiveCaseReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      status: 'closed',
      caseVersion: command.expectedCaseVersion + 1,
      eventId: 'event-void',
    );
  }
'''
replacement = insert_marker + '''
  @override
  Future<LearningCaseRecordReceipt> voidLearningCase(
    VoidLearningCaseCommand command,
  ) async {
    voidCalls.add(command);
    return LearningCaseRecordReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      recordState: 'voided',
      caseStatus: 'confirmed',
      caseVersion: command.expectedCaseVersion + 1,
      eventId: 'event-case-voided',
    );
  }

  @override
  Future<LearningCaseRecordReceipt> restoreLearningCase(
    RestoreLearningCaseCommand command,
  ) async {
    restoreCalls.add(command);
    return LearningCaseRecordReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      recordState: 'active',
      caseStatus: 'confirmed',
      caseVersion: command.expectedCaseVersion + 1,
      eventId: 'event-case-restored',
    );
  }

  @override
  Future<List<VoidedLearningCaseSummary>> listVoidedLearningCases({
    required String profileId,
  }) async => const <VoidedLearningCaseSummary>[];
'''
if insert_marker not in source:
    raise SystemExit('fake progressive endFollowUp block not found')
source = source.replace(insert_marker, replacement)
path.write_text(source, encoding='utf-8')
print('analyzer fixes applied')
