import 'package:supabase_flutter/supabase_flutter.dart';

import 'learning_repository.dart';
import 'responsibility_read_repository.dart';

enum WorkspaceWriteScope { personal, organization }

extension WorkspaceWriteScopeWire on WorkspaceWriteScope {
  String get wireValue => switch (this) {
    WorkspaceWriteScope.personal => 'personal',
    WorkspaceWriteScope.organization => 'organization',
  };
}

abstract interface class ResponsibilityWriteRepository {
  Future<QuickCaptureReceipt> quickCaptureInScope({
    required QuickCaptureCommand command,
    required WorkspaceWriteScope workspaceScope,
    required String expectedResponsibilityMembershipId,
  });
}

class SupabaseResponsibilityWriteRepository
    implements ResponsibilityWriteRepository {
  SupabaseResponsibilityWriteRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<QuickCaptureReceipt> quickCaptureInScope({
    required QuickCaptureCommand command,
    required WorkspaceWriteScope workspaceScope,
    required String expectedResponsibilityMembershipId,
  }) async {
    command.validate();
    final responsibilityMembershipId = expectedResponsibilityMembershipId
        .trim();
    if (responsibilityMembershipId.isEmpty) {
      throw ArgumentError('expectedResponsibilityMembershipId is required.');
    }

    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }
    final expectedUserId = authUser.id;

    _assertSameSession(expectedUserId);
    final response = await _client.rpc(
      'quick_capture_case_in_scope',
      params: <String, dynamic>{
        'p_operation_id': command.operationId,
        'p_profile_id': command.profileId,
        'p_expected_profile_version': command.expectedProfileVersion,
        'p_case_type': command.caseType.wireValue,
        'p_title': command.title.trim(),
        'p_description': command.description?.trim(),
        'p_observed_at': command.observedAt.toUtc().toIso8601String(),
        'p_evidence_summary': command.evidenceSummary.trim(),
        'p_next_action_title': command.nextActionTitle?.trim(),
        'p_next_action_due_at': command.nextActionDueAt
            ?.toUtc()
            .toIso8601String(),
        'p_organization_case_type_id': command.organizationCaseTypeId,
        'p_workspace_scope': workspaceScope.wireValue,
        'p_expected_responsibility_membership_id': responsibilityMembershipId,
      },
    );
    _assertSameSession(expectedUserId);

    if (response is! Map) {
      throw const FormatException(
        'Scoped Quick Capture returned an invalid result.',
      );
    }
    return QuickCaptureReceipt.fromJson(Map<String, dynamic>.from(response));
  }

  void _assertSameSession(String expectedUserId) {
    if (_client.auth.currentUser?.id != expectedUserId) {
      throw const AuthException(
        'The active session changed while saving responsibility-scoped learning data.',
      );
    }
  }
}

/// Bridges the existing V2 Personal workspace to responsibility-safe writes
/// without changing the broad [LearningRepository] contract.
///
/// The same object is supplied to V2 as both the learning repository and the
/// responsibility reader. V2 always loads responsibility after loading the raw
/// workspace, so a Personal Quick Capture can reuse the exact membership
/// snapshot that produced the Personal Projection. A failed/missing context
/// therefore fails closed instead of silently falling back to legacy writes.
class ResponsibilityScopedLearningRepository
    implements LearningRepository, ResponsibilityReadRepository {
  ResponsibilityScopedLearningRepository({
    required LearningRepository learningRepository,
    required ResponsibilityReadRepository responsibilityReadRepository,
    required ResponsibilityWriteRepository responsibilityWriteRepository,
  }) : _learningRepository = learningRepository,
       _responsibilityReadRepository = responsibilityReadRepository,
       _responsibilityWriteRepository = responsibilityWriteRepository;

  final LearningRepository _learningRepository;
  final ResponsibilityReadRepository _responsibilityReadRepository;
  final ResponsibilityWriteRepository _responsibilityWriteRepository;

  String? _workspaceOrganizationId;
  WorkspaceResponsibilityContext? _responsibilityContext;

  @override
  Future<TeacherWorkspace> loadWorkspace() async {
    // A refresh must never keep using an older responsibility snapshot while a
    // newer workspace is being assembled.
    _responsibilityContext = null;
    final workspace = await _learningRepository.loadWorkspace();
    _workspaceOrganizationId = workspace.organizationId?.trim();
    return workspace;
  }

  @override
  Future<WorkspaceResponsibilityContext> loadContext({
    required String organizationId,
  }) async {
    _responsibilityContext = null;
    final context = await _responsibilityReadRepository.loadContext(
      organizationId: organizationId,
    );
    final workspaceOrganizationId = _workspaceOrganizationId;
    if (workspaceOrganizationId != null &&
        workspaceOrganizationId.isNotEmpty &&
        context.organizationId != workspaceOrganizationId) {
      throw const FormatException(
        'Responsibility context organization does not match workspace.',
      );
    }
    _workspaceOrganizationId = context.organizationId;
    _responsibilityContext = context;
    return context;
  }

  @override
  Future<QuickCaptureReceipt> quickCapture(QuickCaptureCommand command) {
    final context = _responsibilityContext;
    if (context == null) {
      throw StateError('personal_responsibility_context_required');
    }
    if (!context.isPersonalProfile(command.profileId)) {
      throw StateError('personal_profile_responsibility_required');
    }
    return _responsibilityWriteRepository.quickCaptureInScope(
      command: command,
      workspaceScope: WorkspaceWriteScope.personal,
      expectedResponsibilityMembershipId: context.currentMembershipId,
    );
  }

  @override
  Future<WorkspaceCaseType> createCaseType({
    required String organizationId,
    required String displayName,
    required LearningCaseType baseType,
  }) => _learningRepository.createCaseType(
    organizationId: organizationId,
    displayName: displayName,
    baseType: baseType,
  );

  @override
  Future<WorkspaceCaseType> renameCaseType({
    required String caseTypeId,
    required String displayName,
    required int expectedVersion,
  }) => _learningRepository.renameCaseType(
    caseTypeId: caseTypeId,
    displayName: displayName,
    expectedVersion: expectedVersion,
  );

  @override
  Future<WorkspaceCaseType> archiveCaseType({
    required String caseTypeId,
    required int expectedVersion,
  }) => _learningRepository.archiveCaseType(
    caseTypeId: caseTypeId,
    expectedVersion: expectedVersion,
  );

  @override
  Future<CaseCommandReceipt> confirmCase(ConfirmCaseCommand command) =>
      _learningRepository.confirmCase(command);

  @override
  Future<CaseCommandReceipt> recordIntervention(
    RecordInterventionCommand command,
  ) => _learningRepository.recordIntervention(command);

  @override
  Future<CaseCommandReceipt> recordAssessment(RecordAssessmentCommand command) =>
      _learningRepository.recordAssessment(command);

  @override
  Future<CaseCommandReceipt> stabilizeCase(StabilizeCaseCommand command) =>
      _learningRepository.stabilizeCase(command);

  @override
  Future<CaseCommandReceipt> closeCase(CloseCaseCommand command) =>
      _learningRepository.closeCase(command);

  @override
  Future<CaseCommandReceipt> addCaseEvidence(AddCaseEvidenceCommand command) =>
      _learningRepository.addCaseEvidence(command);

  @override
  Future<CaseCommandReceipt> reopenCase(ReopenCaseCommand command) =>
      _learningRepository.reopenCase(command);

  @override
  Future<CaseCommandReceipt> rescheduleCaseAction(
    RescheduleCaseActionCommand command,
  ) => _learningRepository.rescheduleCaseAction(command);

  @override
  Future<CaseCommandReceipt> completeCaseAction(
    CompleteCaseActionCommand command,
  ) => _learningRepository.completeCaseAction(command);
}
