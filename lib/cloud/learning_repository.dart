import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

enum LearningCaseStatus {
  newCase,
  confirmed,
  intervening,
  pendingVerification,
  stable,
  closed,
}

extension LearningCaseStatusPresentation on LearningCaseStatus {
  String get wireValue => switch (this) {
    LearningCaseStatus.newCase => 'new',
    LearningCaseStatus.confirmed => 'confirmed',
    LearningCaseStatus.intervening => 'intervening',
    LearningCaseStatus.pendingVerification => 'pending_verification',
    LearningCaseStatus.stable => 'stable',
    LearningCaseStatus.closed => 'closed',
  };

  String get label => switch (this) {
    LearningCaseStatus.newCase => '待整理',
    LearningCaseStatus.confirmed => '已确认',
    LearningCaseStatus.intervening => '干预中',
    LearningCaseStatus.pendingVerification => '待验证',
    LearningCaseStatus.stable => '稳定',
    LearningCaseStatus.closed => '已关闭',
  };
}

enum LearningCaseType { knowledge, habit, examStrategy, other }

extension LearningCaseTypePresentation on LearningCaseType {
  String get wireValue => switch (this) {
    LearningCaseType.knowledge => 'knowledge',
    LearningCaseType.habit => 'habit',
    LearningCaseType.examStrategy => 'exam_strategy',
    LearningCaseType.other => 'other',
  };

  String get label => switch (this) {
    LearningCaseType.knowledge => '知识漏洞',
    LearningCaseType.habit => '学习习惯',
    LearningCaseType.examStrategy => '考试技巧',
    LearningCaseType.other => '其他',
  };
}

class WorkspaceCaseType {
  const WorkspaceCaseType({
    required this.displayName,
    required this.baseType,
    required this.status,
    required this.sortOrder,
    required this.version,
    this.id,
  });

  const WorkspaceCaseType.builtIn(this.baseType)
    : id = null,
      displayName = null,
      status = 'active',
      sortOrder = 0,
      version = 1;

  final String? id;
  final String? displayName;
  final LearningCaseType baseType;
  final String status;
  final int sortOrder;
  final int version;

  static const List<WorkspaceCaseType> builtInTypes = <WorkspaceCaseType>[
    WorkspaceCaseType.builtIn(LearningCaseType.knowledge),
    WorkspaceCaseType.builtIn(LearningCaseType.habit),
    WorkspaceCaseType.builtIn(LearningCaseType.examStrategy),
    WorkspaceCaseType.builtIn(LearningCaseType.other),
  ];

  bool get isBuiltIn => id == null;

  bool get isActive => status == 'active';

  String get key => id ?? 'builtin:${baseType.wireValue}';

  String get label => isBuiltIn ? baseType.label : displayName!;

  factory WorkspaceCaseType.fromJson(Map<String, dynamic> json) {
    final id = _stringValue(json['id']);
    if (id == null) {
      throw const FormatException('Missing case_type_id in server response.');
    }
    return WorkspaceCaseType(
      id: id,
      displayName: _requiredString(json['display_name'], 'case_type_name'),
      baseType: _caseTypeFromWire(json['base_case_type']),
      status: _stringValue(json['status']) ?? 'active',
      sortOrder: _intValue(json['sort_order']) ?? 0,
      version: _intValue(json['version']) ?? 1,
    );
  }
}

enum WorkspaceActionBucket { overdue, today, future, undated }

extension WorkspaceActionBucketPresentation on WorkspaceActionBucket {
  String get label => switch (this) {
    WorkspaceActionBucket.overdue => '已逾期',
    WorkspaceActionBucket.today => '今天到期',
    WorkspaceActionBucket.future => '未来',
    WorkspaceActionBucket.undated => '待安排',
  };
}

enum WorkspaceActionStatus { pending, done, cancelled }

class WorkspaceAction {
  const WorkspaceAction({
    required this.id,
    required this.caseId,
    required this.title,
    required this.actionType,
    required this.status,
    required this.isPrimary,
    required this.bucket,
    required this.version,
    this.dueAt,
  });

  final String id;
  final String caseId;
  final String title;
  final String actionType;
  final WorkspaceActionStatus status;
  final bool isPrimary;
  final WorkspaceActionBucket bucket;
  final int version;
  final DateTime? dueAt;
}

class WorkspaceEvidence {
  const WorkspaceEvidence({
    required this.id,
    required this.sourceType,
    required this.title,
    required this.observedAt,
    required this.summary,
    required this.status,
  });

  final String id;
  final String sourceType;
  final String title;
  final DateTime observedAt;
  final String summary;
  final String status;
}

class WorkspaceIntervention {
  const WorkspaceIntervention({
    required this.id,
    required this.strategy,
    required this.notes,
    required this.occurredAt,
  });

  final String id;
  final String strategy;
  final String? notes;
  final DateTime occurredAt;
}

class WorkspaceAssessment {
  const WorkspaceAssessment({
    required this.id,
    required this.result,
    required this.evidenceSummary,
    required this.notes,
    required this.assessedAt,
  });

  final String id;
  final String result;
  final String evidenceSummary;
  final String? notes;
  final DateTime assessedAt;
}

class WorkspaceTimelineEvent {
  const WorkspaceTimelineEvent({
    required this.id,
    required this.occurredAt,
    required this.typeLabel,
    required this.text,
  });

  final String id;
  final DateTime occurredAt;
  final String typeLabel;
  final String text;
}

class WorkspaceCase {
  const WorkspaceCase({
    required this.id,
    required this.profileId,
    required this.title,
    required this.type,
    required this.status,
    required this.priority,
    required this.description,
    required this.firstObservedAt,
    required this.version,
    required this.evidence,
    required this.interventions,
    required this.assessments,
    required this.actions,
    required this.timeline,
    this.organizationCaseTypeId,
    this.caseTypeLabelSnapshot,
  });

  final String id;
  final String profileId;
  final String title;
  final LearningCaseType type;
  final String? organizationCaseTypeId;
  final String? caseTypeLabelSnapshot;
  final LearningCaseStatus status;
  final String priority;
  final String? description;
  final DateTime firstObservedAt;
  final int version;
  final List<WorkspaceEvidence> evidence;
  final List<WorkspaceIntervention> interventions;
  final List<WorkspaceAssessment> assessments;
  final List<WorkspaceAction> actions;
  final List<WorkspaceTimelineEvent> timeline;

  String get typeLabel => caseTypeLabelSnapshot ?? type.label;

  WorkspaceAction? get primaryAction {
    for (final action in actions) {
      if (action.isPrimary && action.status == WorkspaceActionStatus.pending) {
        return action;
      }
    }
    return null;
  }
}

class WorkspaceStudent {
  const WorkspaceStudent({
    required this.id,
    required this.profileId,
    required this.profileVersion,
    required this.name,
    required this.grade,
    required this.subject,
    required this.context,
    required this.positioning,
    required this.strengths,
    required this.cadenceNote,
    required this.cases,
    required this.recentFacts,
  });

  final String id;
  final String profileId;
  final int profileVersion;
  final String name;
  final String grade;
  final String subject;
  final String context;
  final String? positioning;
  final String? strengths;
  final String? cadenceNote;
  final List<WorkspaceCase> cases;
  final List<WorkspaceTimelineEvent> recentFacts;
}

class TeacherWorkspace {
  const TeacherWorkspace({
    required this.viewerName,
    required this.organizationName,
    required this.organizationTimeZone,
    required this.hasTeachingAccess,
    required this.students,
    required this.loadedAt,
    this.organizationId,
    this.caseTypes = WorkspaceCaseType.builtInTypes,
    this.roles = const <String>[],
    this.canManageCaseTypes = false,
    this.canManageOrganization = false,
  });

  final String viewerName;
  final String organizationName;
  final String organizationTimeZone;
  final bool hasTeachingAccess;
  final List<WorkspaceStudent> students;
  final DateTime loadedAt;
  final String? organizationId;
  final List<WorkspaceCaseType> caseTypes;
  final List<String> roles;
  final bool canManageCaseTypes;
  final bool canManageOrganization;
}

class QuickCaptureCommand {
  const QuickCaptureCommand({
    required this.operationId,
    required this.profileId,
    required this.expectedProfileVersion,
    required this.caseType,
    required this.title,
    required this.description,
    required this.observedAt,
    required this.evidenceSummary,
    required this.nextActionTitle,
    required this.nextActionDueAt,
    this.organizationCaseTypeId,
  });

  final String operationId;
  final String profileId;
  final int expectedProfileVersion;
  final LearningCaseType caseType;
  final String? organizationCaseTypeId;
  final String title;
  final String? description;
  final DateTime observedAt;
  final String evidenceSummary;
  final String nextActionTitle;
  final DateTime? nextActionDueAt;

  void validate() {
    if (operationId.trim().isEmpty) {
      throw ArgumentError('operationId cannot be empty.');
    }
    if (profileId.trim().isEmpty) {
      throw ArgumentError('profileId cannot be empty.');
    }
    if (expectedProfileVersion <= 0) {
      throw ArgumentError('expectedProfileVersion must be positive.');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError('title cannot be empty.');
    }
    if (evidenceSummary.trim().isEmpty) {
      throw ArgumentError('evidenceSummary cannot be empty.');
    }
    if (nextActionTitle.trim().isEmpty) {
      throw ArgumentError('nextActionTitle cannot be empty.');
    }
    if (organizationCaseTypeId != null &&
        organizationCaseTypeId!.trim().isEmpty) {
      throw ArgumentError('organizationCaseTypeId cannot be blank.');
    }
  }
}

class QuickCaptureReceipt {
  const QuickCaptureReceipt({
    required this.operationId,
    required this.caseId,
    required this.evidenceId,
    required this.actionId,
    required this.status,
    required this.caseVersion,
  });

  final String operationId;
  final String caseId;
  final String evidenceId;
  final String actionId;
  final String status;
  final int caseVersion;

  factory QuickCaptureReceipt.fromJson(Map<String, dynamic> json) {
    final operationId = _requiredString(json['operation_id'], 'operation_id');
    final caseId = _requiredString(json['case_id'], 'case_id');
    final evidenceId = _requiredString(json['evidence_id'], 'evidence_id');
    final actionId = _requiredString(json['action_id'], 'action_id');
    return QuickCaptureReceipt(
      operationId: operationId,
      caseId: caseId,
      evidenceId: evidenceId,
      actionId: actionId,
      status: _requiredString(json['status'], 'status'),
      caseVersion: _requiredInt(json['case_version'], 'case_version'),
    );
  }
}

enum CaseAssessmentResult { passed, partial, notPassed }

extension CaseAssessmentResultPresentation on CaseAssessmentResult {
  String get wireValue => switch (this) {
    CaseAssessmentResult.passed => 'passed',
    CaseAssessmentResult.partial => 'partial',
    CaseAssessmentResult.notPassed => 'not_passed',
  };

  String get label => switch (this) {
    CaseAssessmentResult.passed => '通过',
    CaseAssessmentResult.partial => '部分通过',
    CaseAssessmentResult.notPassed => '未通过',
  };
}

class CaseCommandReceipt {
  const CaseCommandReceipt({
    required this.operationId,
    required this.caseId,
    this.actionId,
    required this.eventId,
    required this.status,
    required this.caseVersion,
    this.recordId,
  });

  final String operationId;
  final String caseId;
  final String? actionId;
  final String eventId;
  final String status;
  final int caseVersion;
  final String? recordId;

  factory CaseCommandReceipt.fromJson(Map<String, dynamic> json) {
    return CaseCommandReceipt(
      operationId: _requiredString(json['operation_id'], 'operation_id'),
      caseId: _requiredString(json['case_id'], 'case_id'),
      actionId: _stringValue(json['action_id']),
      eventId: _requiredString(json['event_id'], 'event_id'),
      status: _requiredString(json['status'], 'status'),
      caseVersion: _requiredInt(json['case_version'], 'case_version'),
      recordId:
          _stringValue(json['intervention_id']) ??
          _stringValue(json['assessment_id']) ??
          _stringValue(json['evidence_id']),
    );
  }
}

class ConfirmCaseCommand {
  const ConfirmCaseCommand({
    required this.operationId,
    required this.caseId,
    required this.expectedCaseVersion,
    required this.nextActionTitle,
    required this.nextActionDueAt,
  });

  final String operationId;
  final String caseId;
  final int expectedCaseVersion;
  final String nextActionTitle;
  final DateTime? nextActionDueAt;

  void validate() {
    _validateCaseCommandIdentity(
      operationId: operationId,
      caseId: caseId,
      expectedCaseVersion: expectedCaseVersion,
    );
    _validateNextActionTitle(nextActionTitle);
  }
}

class RecordInterventionCommand {
  const RecordInterventionCommand({
    required this.operationId,
    required this.caseId,
    required this.expectedCaseVersion,
    required this.strategy,
    required this.notes,
    required this.occurredAt,
    required this.nextActionTitle,
    required this.nextActionDueAt,
  });

  final String operationId;
  final String caseId;
  final int expectedCaseVersion;
  final String strategy;
  final String? notes;
  final DateTime? occurredAt;
  final String nextActionTitle;
  final DateTime? nextActionDueAt;

  void validate() {
    _validateCaseCommandIdentity(
      operationId: operationId,
      caseId: caseId,
      expectedCaseVersion: expectedCaseVersion,
    );
    if (strategy.trim().isEmpty) {
      throw ArgumentError('strategy cannot be empty.');
    }
    _validateNextActionTitle(nextActionTitle);
  }
}

class RecordAssessmentCommand {
  const RecordAssessmentCommand({
    required this.operationId,
    required this.caseId,
    required this.expectedCaseVersion,
    required this.result,
    required this.evidenceSummary,
    required this.notes,
    required this.assessedAt,
    required this.nextActionTitle,
    required this.nextActionDueAt,
  });

  final String operationId;
  final String caseId;
  final int expectedCaseVersion;
  final CaseAssessmentResult result;
  final String evidenceSummary;
  final String? notes;
  final DateTime? assessedAt;
  final String nextActionTitle;
  final DateTime? nextActionDueAt;

  void validate() {
    _validateCaseCommandIdentity(
      operationId: operationId,
      caseId: caseId,
      expectedCaseVersion: expectedCaseVersion,
    );
    if (evidenceSummary.trim().isEmpty) {
      throw ArgumentError('evidenceSummary cannot be empty.');
    }
    _validateNextActionTitle(nextActionTitle);
  }
}

class StabilizeCaseCommand {
  const StabilizeCaseCommand({
    required this.operationId,
    required this.caseId,
    required this.expectedCaseVersion,
    required this.stabilizedAt,
    required this.nextActionTitle,
    required this.nextActionDueAt,
  });

  final String operationId;
  final String caseId;
  final int expectedCaseVersion;
  final DateTime? stabilizedAt;
  final String nextActionTitle;
  final DateTime? nextActionDueAt;

  void validate() {
    _validateCaseCommandIdentity(
      operationId: operationId,
      caseId: caseId,
      expectedCaseVersion: expectedCaseVersion,
    );
    _validateNextActionTitle(nextActionTitle);
  }
}

class CloseCaseCommand {
  const CloseCaseCommand({
    required this.operationId,
    required this.caseId,
    required this.expectedCaseVersion,
    required this.closedAt,
  });

  final String operationId;
  final String caseId;
  final int expectedCaseVersion;
  final DateTime? closedAt;

  void validate() {
    _validateCaseCommandIdentity(
      operationId: operationId,
      caseId: caseId,
      expectedCaseVersion: expectedCaseVersion,
    );
  }
}

class RescheduleCaseActionCommand {
  const RescheduleCaseActionCommand({
    required this.operationId,
    required this.actionId,
    required this.caseId,
    required this.expectedCaseVersion,
    required this.expectedActionVersion,
    required this.dueOn,
  });

  final String operationId;
  final String actionId;
  final String caseId;
  final int expectedCaseVersion;
  final int expectedActionVersion;
  final DateTime? dueOn;

  void validate() {
    _validateActionCommandIdentity(
      operationId: operationId,
      actionId: actionId,
      caseId: caseId,
      expectedCaseVersion: expectedCaseVersion,
      expectedActionVersion: expectedActionVersion,
    );
  }
}

abstract interface class LearningRepository {
  Future<TeacherWorkspace> loadWorkspace();

  Future<QuickCaptureReceipt> quickCapture(QuickCaptureCommand command);

  Future<WorkspaceCaseType> createCaseType({
    required String organizationId,
    required String displayName,
    required LearningCaseType baseType,
  });

  Future<WorkspaceCaseType> renameCaseType({
    required String caseTypeId,
    required String displayName,
    required int expectedVersion,
  });

  Future<WorkspaceCaseType> archiveCaseType({
    required String caseTypeId,
    required int expectedVersion,
  });

  Future<CaseCommandReceipt> confirmCase(ConfirmCaseCommand command);

  Future<CaseCommandReceipt> recordIntervention(
    RecordInterventionCommand command,
  );

  Future<CaseCommandReceipt> recordAssessment(RecordAssessmentCommand command);

  Future<CaseCommandReceipt> stabilizeCase(StabilizeCaseCommand command);

  Future<CaseCommandReceipt> closeCase(CloseCaseCommand command);

  Future<CaseCommandReceipt> rescheduleCaseAction(
    RescheduleCaseActionCommand command,
  );
}

class SupabaseLearningRepository implements LearningRepository {
  SupabaseLearningRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<TeacherWorkspace> loadWorkspace() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }
    final expectedUserId = authUser.id;

    final appUser = await _client
        .from('app_users')
        .select('id,display_name')
        .eq('auth_provider', 'supabase')
        .eq('auth_subject_id', expectedUserId)
        .eq('status', 'active')
        .maybeSingle();
    _assertSameSession(expectedUserId);
    final viewerName =
        _stringValue(appUser?['display_name']) ?? authUser.email ?? '教师';

    final appUserId = appUser?['id'] as String?;
    if (appUserId == null) {
      return TeacherWorkspace(
        viewerName: viewerName,
        organizationName: '无活动机构',
        organizationTimeZone: 'UTC',
        hasTeachingAccess: false,
        students: const <WorkspaceStudent>[],
        loadedAt: DateTime.now(),
      );
    }

    final membership = await _client
        .from('organization_memberships')
        .select('id,organization_id')
        .eq('app_user_id', appUserId)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();
    _assertSameSession(expectedUserId);
    if (membership == null) {
      return TeacherWorkspace(
        viewerName: viewerName,
        organizationName: '无活动机构',
        organizationTimeZone: 'UTC',
        hasTeachingAccess: false,
        students: const <WorkspaceStudent>[],
        loadedAt: DateTime.now(),
      );
    }

    final organizationId = _requiredString(
      membership['organization_id'],
      'organization_id',
    );
    final membershipId = _requiredString(membership['id'], 'membership_id');
    final roleRows = await _rows(
      _client
          .from('membership_roles')
          .select('role')
          .eq('organization_id', organizationId)
          .eq('membership_id', membershipId),
      expectedUserId,
    );
    final roles = <String>[
      for (final row in roleRows)
        if (row['role'] is String) row['role'] as String,
    ];
    final hasTeachingAccess = roles.contains('teacher');
    final canManageOrganization = roles.any(
      (role) => role == 'org_owner' || role == 'org_admin',
    );
    final canManageCaseTypes = roles.any(
      (role) =>
          role == 'org_owner' ||
          role == 'org_admin' ||
          role == 'academic_admin',
    );

    final organization = await _client
        .from('organizations')
        .select('name,time_zone')
        .eq('id', organizationId)
        .maybeSingle();
    _assertSameSession(expectedUserId);
    if (organization == null) {
      throw const FormatException('Active organization was not found.');
    }

    final caseTypeRows = await _rows(
      _client
          .from('organization_case_types')
          .select('id,display_name,base_case_type,status,sort_order,version')
          .eq('organization_id', organizationId)
          .order('sort_order')
          .order('created_at'),
      expectedUserId,
    );
    final caseTypes = <WorkspaceCaseType>[
      ...WorkspaceCaseType.builtInTypes,
      for (final row in caseTypeRows) WorkspaceCaseType.fromJson(row),
    ];

    if (!hasTeachingAccess) {
      return TeacherWorkspace(
        organizationId: organizationId,
        viewerName: viewerName,
        organizationName: _stringValue(organization['name']) ?? '未命名机构',
        organizationTimeZone: _stringValue(organization['time_zone']) ?? 'UTC',
        hasTeachingAccess: false,
        students: const <WorkspaceStudent>[],
        loadedAt: DateTime.now(),
        caseTypes: List<WorkspaceCaseType>.unmodifiable(caseTypes),
        roles: List<String>.unmodifiable(roles),
        canManageCaseTypes: canManageCaseTypes,
        canManageOrganization: canManageOrganization,
      );
    }

    final rows = await Future.wait<List<Map<String, dynamic>>>([
      _rows(
        _client
            .from('organization_subjects')
            .select('id,display_name')
            .eq('organization_id', organizationId)
            .eq('status', 'active'),
        expectedUserId,
      ),
      _rows(
        _client
            .from('student_subject_profiles')
            .select(
              'id,student_id,organization_subject_id,positioning,strengths, '
              'cadence_note,version',
            )
            .eq('organization_id', organizationId)
            .eq('status', 'active'),
        expectedUserId,
      ),
      _rows(
        _client
            .from('students')
            .select('id,name,organization_id')
            .eq('organization_id', organizationId)
            .eq('status', 'active'),
        expectedUserId,
      ),
      _rows(
        _client
            .from('teacher_workspace_student_enrollments')
            .select(
              'student_id,grade,class_name,campus,starts_on,ends_on,is_current',
            )
            .eq('organization_id', organizationId),
        expectedUserId,
      ),
      _rows(
        _client
            .from('learning_cases')
            .select(
              'id,student_subject_profile_id,case_type,'
              'organization_case_type_id,case_type_label_snapshot,'
              'title,description,priority,status,first_observed_at,version',
            )
            .eq('organization_id', organizationId),
        expectedUserId,
      ),
      _rows(
        _client
            .from('case_actions')
            .select(
              'id,learning_case_id,action_type,title,due_at,is_primary,'
              'status,version',
            )
            .eq('organization_id', organizationId),
        expectedUserId,
      ),
      _rows(
        _client
            .from('teacher_workspace_action_queue')
            .select('id,due_bucket')
            .eq('organization_id', organizationId),
        expectedUserId,
      ),
      _rows(
        _client
            .from('case_evidence')
            .select(
              'id,learning_case_id,source_type,title,observed_at,summary,status',
            )
            .eq('organization_id', organizationId),
        expectedUserId,
      ),
      _rows(
        _client
            .from('interventions')
            .select('id,learning_case_id,strategy,notes,occurred_at')
            .eq('organization_id', organizationId),
        expectedUserId,
      ),
      _rows(
        _client
            .from('assessments')
            .select(
              'id,learning_case_id,result,evidence_summary,notes,assessed_at',
            )
            .eq('organization_id', organizationId),
        expectedUserId,
      ),
      _rows(
        _client
            .from('case_events')
            .select('id,learning_case_id,event_type,occurred_at,metadata')
            .eq('organization_id', organizationId),
        expectedUserId,
      ),
    ]);
    final subjectRows = rows[0];
    final profileRows = rows[1];
    final studentRows = rows[2];
    final enrollmentRows = rows[3];
    final caseRows = rows[4];
    final actionRows = rows[5];
    final queueRows = rows[6];
    final evidenceRows = rows[7];
    final interventionRows = rows[8];
    final assessmentRows = rows[9];
    final eventRows = rows[10];

    // Index each child collection once. This keeps a large institution's
    // client-side assembly proportional to the rows returned instead of
    // rescanning every child row for every profile and case.
    final casesByProfileId = _groupRowsByKey(
      caseRows,
      'student_subject_profile_id',
    );
    final actionsByCaseId = _groupRowsByKey(actionRows, 'learning_case_id');
    final evidenceByCaseId = _groupRowsByKey(evidenceRows, 'learning_case_id');
    final interventionsByCaseId = _groupRowsByKey(
      interventionRows,
      'learning_case_id',
    );
    final assessmentsByCaseId = _groupRowsByKey(
      assessmentRows,
      'learning_case_id',
    );
    final eventsByCaseId = _groupRowsByKey(eventRows, 'learning_case_id');
    final enrollmentsByStudentId = _groupRowsByKey(
      enrollmentRows,
      'student_id',
    );

    final subjectsById = <String, String>{
      for (final row in subjectRows)
        _requiredString(row['id'], 'subject_id'):
            _stringValue(row['display_name']) ?? '未命名学科',
    };
    final studentsById = <String, Map<String, dynamic>>{
      for (final row in studentRows)
        _requiredString(row['id'], 'student_id'): row,
    };
    final bucketByActionId = <String, WorkspaceActionBucket>{
      for (final row in queueRows)
        _requiredString(row['id'], 'action_id'): _actionBucketFromWire(
          row['due_bucket'],
        ),
    };

    final workspaceStudents = <WorkspaceStudent>[];
    for (final profile in profileRows) {
      final profileId = _requiredString(profile['id'], 'profile_id');
      final studentId = _requiredString(profile['student_id'], 'student_id');
      final student = studentsById[studentId];
      if (student == null) {
        continue;
      }
      final subjectId = _requiredString(
        profile['organization_subject_id'],
        'organization_subject_id',
      );
      final cases = <WorkspaceCase>[];
      for (final caseRow
          in casesByProfileId[profileId] ?? const <Map<String, dynamic>>[]) {
        cases.add(
          _buildCase(
            profileId: profileId,
            row: caseRow,
            actionRows: actionsByCaseId,
            bucketByActionId: bucketByActionId,
            evidenceRows: evidenceByCaseId,
            interventionRows: interventionsByCaseId,
            assessmentRows: assessmentsByCaseId,
            eventRows: eventsByCaseId,
          ),
        );
      }
      final facts = <WorkspaceTimelineEvent>[
        for (final learningCase in cases) ...learningCase.timeline,
      ]..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
      final enrollment = _currentEnrollment(
        enrollmentsByStudentId[studentId] ?? const <Map<String, dynamic>>[],
      );
      final grade = _stringValue(enrollment?['grade']) ?? '年级未设置';
      final context =
          _stringValue(profile['positioning']) ??
          _stringValue(profile['cadence_note']) ??
          '尚未填写学科定位';
      workspaceStudents.add(
        WorkspaceStudent(
          id: studentId,
          profileId: profileId,
          profileVersion: _intValue(profile['version']) ?? 1,
          name: _requiredString(student['name'], 'student_name'),
          grade: grade,
          subject: subjectsById[subjectId] ?? '未命名学科',
          context: context,
          positioning: _stringValue(profile['positioning']),
          strengths: _stringValue(profile['strengths']),
          cadenceNote: _stringValue(profile['cadence_note']),
          cases: List<WorkspaceCase>.unmodifiable(cases),
          recentFacts: List<WorkspaceTimelineEvent>.unmodifiable(facts.take(5)),
        ),
      );
    }
    workspaceStudents.sort((left, right) => left.name.compareTo(right.name));

    return TeacherWorkspace(
      organizationId: organizationId,
      viewerName: viewerName,
      organizationName: _stringValue(organization['name']) ?? '未命名机构',
      organizationTimeZone: _stringValue(organization['time_zone']) ?? 'UTC',
      hasTeachingAccess: true,
      students: List<WorkspaceStudent>.unmodifiable(workspaceStudents),
      loadedAt: DateTime.now(),
      caseTypes: List<WorkspaceCaseType>.unmodifiable(caseTypes),
      roles: List<String>.unmodifiable(roles),
      canManageCaseTypes: canManageCaseTypes,
      canManageOrganization: canManageOrganization,
    );
  }

  @override
  Future<QuickCaptureReceipt> quickCapture(QuickCaptureCommand command) async {
    command.validate();
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }
    final functionName = command.organizationCaseTypeId == null
        ? 'quick_capture_case'
        : 'quick_capture_case_with_type';
    final params = <String, dynamic>{
      'p_operation_id': command.operationId,
      'p_profile_id': command.profileId,
      'p_expected_profile_version': command.expectedProfileVersion,
      'p_case_type': command.caseType.wireValue,
      'p_title': command.title.trim(),
      'p_description': command.description?.trim(),
      'p_observed_at': command.observedAt.toUtc().toIso8601String(),
      'p_evidence_summary': command.evidenceSummary.trim(),
      'p_next_action_title': command.nextActionTitle.trim(),
      'p_next_action_due_at': command.nextActionDueAt
          ?.toUtc()
          .toIso8601String(),
    };
    if (command.organizationCaseTypeId != null) {
      params['p_organization_case_type_id'] = command.organizationCaseTypeId;
    }
    final response = await _client.rpc(functionName, params: params);
    _assertSameSession(authUser.id);
    if (response is! Map) {
      throw const FormatException('Quick Capture returned an invalid result.');
    }
    return QuickCaptureReceipt.fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<WorkspaceCaseType> createCaseType({
    required String organizationId,
    required String displayName,
    required LearningCaseType baseType,
  }) {
    return _invokeCaseTypeCommand(
      functionName: 'create_organization_case_type',
      params: <String, dynamic>{
        'p_organization_id': organizationId,
        'p_display_name': displayName.trim(),
        'p_base_case_type': baseType.wireValue,
      },
    );
  }

  @override
  Future<WorkspaceCaseType> renameCaseType({
    required String caseTypeId,
    required String displayName,
    required int expectedVersion,
  }) {
    return _invokeCaseTypeCommand(
      functionName: 'rename_organization_case_type',
      params: <String, dynamic>{
        'p_case_type_id': caseTypeId,
        'p_display_name': displayName.trim(),
        'p_expected_version': expectedVersion,
      },
    );
  }

  @override
  Future<WorkspaceCaseType> archiveCaseType({
    required String caseTypeId,
    required int expectedVersion,
  }) {
    return _invokeCaseTypeCommand(
      functionName: 'archive_organization_case_type',
      params: <String, dynamic>{
        'p_case_type_id': caseTypeId,
        'p_expected_version': expectedVersion,
      },
    );
  }

  Future<WorkspaceCaseType> _invokeCaseTypeCommand({
    required String functionName,
    required Map<String, dynamic> params,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }
    final response = await _client.rpc(functionName, params: params);
    _assertSameSession(authUser.id);
    if (response is! Map) {
      throw FormatException('$functionName returned an invalid result.');
    }
    return WorkspaceCaseType.fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<CaseCommandReceipt> confirmCase(ConfirmCaseCommand command) async {
    command.validate();
    return _invokeCaseCommand(
      functionName: 'confirm_case',
      params: <String, dynamic>{
        'p_operation_id': command.operationId,
        'p_case_id': command.caseId,
        'p_expected_case_version': command.expectedCaseVersion,
        'p_next_action_title': command.nextActionTitle.trim(),
        'p_next_action_due_at': _utcIso8601(command.nextActionDueAt),
      },
    );
  }

  @override
  Future<CaseCommandReceipt> recordIntervention(
    RecordInterventionCommand command,
  ) async {
    command.validate();
    return _invokeCaseCommand(
      functionName: 'record_intervention',
      params: <String, dynamic>{
        'p_operation_id': command.operationId,
        'p_case_id': command.caseId,
        'p_expected_case_version': command.expectedCaseVersion,
        'p_strategy': command.strategy.trim(),
        'p_notes': command.notes?.trim(),
        'p_occurred_at': _utcIso8601(command.occurredAt),
        'p_next_action_title': command.nextActionTitle.trim(),
        'p_next_action_due_at': _utcIso8601(command.nextActionDueAt),
      },
    );
  }

  @override
  Future<CaseCommandReceipt> recordAssessment(
    RecordAssessmentCommand command,
  ) async {
    command.validate();
    return _invokeCaseCommand(
      functionName: 'record_assessment',
      params: <String, dynamic>{
        'p_operation_id': command.operationId,
        'p_case_id': command.caseId,
        'p_expected_case_version': command.expectedCaseVersion,
        'p_result': command.result.wireValue,
        'p_evidence_summary': command.evidenceSummary.trim(),
        'p_notes': command.notes?.trim(),
        'p_assessed_at': _utcIso8601(command.assessedAt),
        'p_next_action_title': command.nextActionTitle.trim(),
        'p_next_action_due_at': _utcIso8601(command.nextActionDueAt),
      },
    );
  }

  @override
  Future<CaseCommandReceipt> stabilizeCase(StabilizeCaseCommand command) async {
    command.validate();
    return _invokeCaseCommand(
      functionName: 'stabilize_case',
      params: <String, dynamic>{
        'p_operation_id': command.operationId,
        'p_case_id': command.caseId,
        'p_expected_case_version': command.expectedCaseVersion,
        'p_stabilized_at': _utcIso8601(command.stabilizedAt),
        'p_next_action_title': command.nextActionTitle.trim(),
        'p_next_action_due_at': _utcIso8601(command.nextActionDueAt),
      },
    );
  }

  @override
  Future<CaseCommandReceipt> closeCase(CloseCaseCommand command) async {
    command.validate();
    return _invokeCaseCommand(
      functionName: 'close_case',
      params: <String, dynamic>{
        'p_operation_id': command.operationId,
        'p_case_id': command.caseId,
        'p_expected_case_version': command.expectedCaseVersion,
        'p_closed_at': _utcIso8601(command.closedAt),
      },
    );
  }

  @override
  Future<CaseCommandReceipt> rescheduleCaseAction(
    RescheduleCaseActionCommand command,
  ) async {
    command.validate();
    return _invokeCaseCommand(
      functionName: 'reschedule_case_action',
      params: <String, dynamic>{
        'p_operation_id': command.operationId,
        'p_action_id': command.actionId,
        'p_case_id': command.caseId,
        'p_expected_case_version': command.expectedCaseVersion,
        'p_expected_action_version': command.expectedActionVersion,
        'p_due_on': _dateOnlyString(command.dueOn),
      },
    );
  }

  Future<CaseCommandReceipt> _invokeCaseCommand({
    required String functionName,
    required Map<String, dynamic> params,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }
    final response = await _client.rpc(functionName, params: params);
    _assertSameSession(authUser.id);
    if (response is! Map) {
      throw FormatException('$functionName returned an invalid result.');
    }
    return CaseCommandReceipt.fromJson(Map<String, dynamic>.from(response));
  }

  Future<List<Map<String, dynamic>>> _rows(
    dynamic query,
    String expectedUserId,
  ) async {
    final response = await query;
    _assertSameSession(expectedUserId);
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  WorkspaceCase _buildCase({
    required String profileId,
    required Map<String, dynamic> row,
    required Map<String, List<Map<String, dynamic>>> actionRows,
    required Map<String, WorkspaceActionBucket> bucketByActionId,
    required Map<String, List<Map<String, dynamic>>> evidenceRows,
    required Map<String, List<Map<String, dynamic>>> interventionRows,
    required Map<String, List<Map<String, dynamic>>> assessmentRows,
    required Map<String, List<Map<String, dynamic>>> eventRows,
  }) {
    final caseId = _requiredString(row['id'], 'case_id');
    final actions = <WorkspaceAction>[];
    for (final actionRow
        in actionRows[caseId] ?? const <Map<String, dynamic>>[]) {
      final actionId = _requiredString(actionRow['id'], 'action_id');
      final dueAt = _dateTimeValue(actionRow['due_at']);
      actions.add(
        WorkspaceAction(
          id: actionId,
          caseId: caseId,
          title: _requiredString(actionRow['title'], 'action_title'),
          actionType: _stringValue(actionRow['action_type']) ?? 'other',
          status: _actionStatusFromWire(actionRow['status']),
          isPrimary: actionRow['is_primary'] == true,
          version: _requiredInt(actionRow['version'], 'action_version'),
          bucket: bucketByActionId[actionId] ?? _fallbackBucketForDueAt(dueAt),
          dueAt: dueAt,
        ),
      );
    }
    actions.sort((left, right) {
      if (left.status != right.status) {
        return left.status.index.compareTo(right.status.index);
      }
      return (left.dueAt ?? DateTime.utc(9999)).compareTo(
        right.dueAt ?? DateTime.utc(9999),
      );
    });

    final evidence = <WorkspaceEvidence>[];
    for (final evidenceRow
        in evidenceRows[caseId] ?? const <Map<String, dynamic>>[]) {
      evidence.add(
        WorkspaceEvidence(
          id: _requiredString(evidenceRow['id'], 'evidence_id'),
          sourceType: _stringValue(evidenceRow['source_type']) ?? 'other',
          title: _requiredString(evidenceRow['title'], 'evidence_title'),
          observedAt: _requiredDateTime(
            evidenceRow['observed_at'],
            'evidence_observed_at',
          ),
          summary: _requiredString(evidenceRow['summary'], 'evidence_summary'),
          status: _stringValue(evidenceRow['status']) ?? 'finalized',
        ),
      );
    }
    evidence.sort((left, right) => right.observedAt.compareTo(left.observedAt));

    final interventions = <WorkspaceIntervention>[];
    for (final interventionRow
        in interventionRows[caseId] ?? const <Map<String, dynamic>>[]) {
      interventions.add(
        WorkspaceIntervention(
          id: _requiredString(interventionRow['id'], 'intervention_id'),
          strategy: _requiredString(
            interventionRow['strategy'],
            'intervention_strategy',
          ),
          notes: _stringValue(interventionRow['notes']),
          occurredAt: _requiredDateTime(
            interventionRow['occurred_at'],
            'intervention_occurred_at',
          ),
        ),
      );
    }
    interventions.sort(
      (left, right) => right.occurredAt.compareTo(left.occurredAt),
    );

    final assessments = <WorkspaceAssessment>[];
    for (final assessmentRow
        in assessmentRows[caseId] ?? const <Map<String, dynamic>>[]) {
      assessments.add(
        WorkspaceAssessment(
          id: _requiredString(assessmentRow['id'], 'assessment_id'),
          result: _stringValue(assessmentRow['result']) ?? 'not_passed',
          evidenceSummary: _requiredString(
            assessmentRow['evidence_summary'],
            'assessment_evidence_summary',
          ),
          notes: _stringValue(assessmentRow['notes']),
          assessedAt: _requiredDateTime(
            assessmentRow['assessed_at'],
            'assessment_assessed_at',
          ),
        ),
      );
    }
    assessments.sort(
      (left, right) => right.assessedAt.compareTo(left.assessedAt),
    );

    final timeline = <WorkspaceTimelineEvent>[];
    for (final eventRow
        in eventRows[caseId] ?? const <Map<String, dynamic>>[]) {
      final eventType = _stringValue(eventRow['event_type']) ?? 'event';
      timeline.add(
        WorkspaceTimelineEvent(
          id: _requiredString(eventRow['id'], 'event_id'),
          occurredAt: _requiredDateTime(
            eventRow['occurred_at'],
            'event_occurred_at',
          ),
          typeLabel: _eventTypeLabel(eventType),
          text: _eventText(eventType, eventRow['metadata']),
        ),
      );
    }
    for (final item in evidence) {
      timeline.add(
        WorkspaceTimelineEvent(
          id: 'evidence:${item.id}',
          occurredAt: item.observedAt,
          typeLabel: 'Evidence / 证据',
          text: '${item.title}：${item.summary}',
        ),
      );
    }
    for (final item in interventions) {
      timeline.add(
        WorkspaceTimelineEvent(
          id: 'intervention:${item.id}',
          occurredAt: item.occurredAt,
          typeLabel: 'Intervention / 教学动作',
          text: item.strategy,
        ),
      );
    }
    for (final item in assessments) {
      timeline.add(
        WorkspaceTimelineEvent(
          id: 'assessment:${item.id}',
          occurredAt: item.assessedAt,
          typeLabel: 'Assessment / 验证',
          text:
              '${_assessmentResultLabel(item.result)}：${item.evidenceSummary}',
        ),
      );
    }
    timeline.sort((left, right) => right.occurredAt.compareTo(left.occurredAt));

    return WorkspaceCase(
      id: caseId,
      profileId: profileId,
      title: _requiredString(row['title'], 'case_title'),
      type: _caseTypeFromWire(row['case_type']),
      organizationCaseTypeId: _stringValue(row['organization_case_type_id']),
      caseTypeLabelSnapshot: _stringValue(row['case_type_label_snapshot']),
      status: _caseStatusFromWire(row['status']),
      priority: _stringValue(row['priority']) ?? 'normal',
      description: _stringValue(row['description']),
      firstObservedAt: _requiredDateTime(
        row['first_observed_at'],
        'case_first_observed_at',
      ),
      version: _intValue(row['version']) ?? 1,
      evidence: List<WorkspaceEvidence>.unmodifiable(evidence),
      interventions: List<WorkspaceIntervention>.unmodifiable(interventions),
      assessments: List<WorkspaceAssessment>.unmodifiable(assessments),
      actions: List<WorkspaceAction>.unmodifiable(actions),
      timeline: List<WorkspaceTimelineEvent>.unmodifiable(timeline),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupRowsByKey(
    List<Map<String, dynamic>> rows,
    String key,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final value = row[key];
      if (value is! String || value.isEmpty) {
        continue;
      }
      grouped.putIfAbsent(value, () => <Map<String, dynamic>>[]).add(row);
    }
    return grouped;
  }

  Map<String, dynamic>? _currentEnrollment(List<Map<String, dynamic>> rows) {
    // The read model evaluates is_current using the organization's IANA
    // timezone. Do not re-derive this business fact from the device clock.
    final candidates = rows.where((row) => row['is_current'] == true).toList();
    candidates.sort((left, right) {
      final leftDate = _dateOnlyValue(left['starts_on']);
      final rightDate = _dateOnlyValue(right['starts_on']);
      return (rightDate ?? DateTime.utc(1970)).compareTo(
        leftDate ?? DateTime.utc(1970),
      );
    });
    return candidates.isEmpty ? null : candidates.first;
  }

  void _assertSameSession(String expectedUserId) {
    if (_client.auth.currentUser?.id != expectedUserId) {
      throw const AuthException(
        'The active session changed while loading workspace data.',
      );
    }
  }
}

String createOperationId() {
  final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
  final value = hex.join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

final Random _secureRandom = Random.secure();

void _validateCaseCommandIdentity({
  required String operationId,
  required String caseId,
  required int expectedCaseVersion,
}) {
  if (operationId.trim().isEmpty) {
    throw ArgumentError('operationId cannot be empty.');
  }
  if (caseId.trim().isEmpty) {
    throw ArgumentError('caseId cannot be empty.');
  }
  if (expectedCaseVersion <= 0) {
    throw ArgumentError('expectedCaseVersion must be positive.');
  }
}

void _validateActionCommandIdentity({
  required String operationId,
  required String actionId,
  required String caseId,
  required int expectedCaseVersion,
  required int expectedActionVersion,
}) {
  _validateCaseCommandIdentity(
    operationId: operationId,
    caseId: caseId,
    expectedCaseVersion: expectedCaseVersion,
  );
  if (actionId.trim().isEmpty) {
    throw ArgumentError('actionId cannot be empty.');
  }
  if (expectedActionVersion <= 0) {
    throw ArgumentError('expectedActionVersion must be positive.');
  }
}

void _validateNextActionTitle(String value) {
  if (value.trim().isEmpty) {
    throw ArgumentError('nextActionTitle cannot be empty.');
  }
}

String? _dateOnlyString(DateTime? value) {
  if (value == null) {
    return null;
  }
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String? _utcIso8601(DateTime? value) => value?.toUtc().toIso8601String();

String _requiredString(dynamic value, String field) {
  final stringValue = _stringValue(value);
  if (stringValue == null || stringValue.isEmpty) {
    throw FormatException('Missing $field in server response.');
  }
  return stringValue;
}

String? _stringValue(dynamic value) {
  if (value == null) {
    return null;
  }
  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}

int _requiredInt(dynamic value, String field) {
  final result = _intValue(value);
  if (result == null) {
    throw FormatException('Missing $field in server response.');
  }
  return result;
}

int? _intValue(dynamic value, {int? fallback}) {
  if (value is int) {
    return value;
  }
  final parsed = int.tryParse(value?.toString() ?? '');
  return parsed ?? fallback;
}

DateTime? _dateTimeValue(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString())?.toLocal();
}

DateTime _requiredDateTime(dynamic value, String field) {
  final result = _dateTimeValue(value);
  if (result == null) {
    throw FormatException('Missing $field in server response.');
  }
  return result;
}

DateTime? _dateOnlyValue(dynamic value) {
  final result = _stringValue(value);
  if (result == null) {
    return null;
  }
  return DateTime.tryParse(result);
}

WorkspaceActionBucket _actionBucketFromWire(dynamic value) {
  return switch (_stringValue(value)) {
    'overdue' => WorkspaceActionBucket.overdue,
    'today' => WorkspaceActionBucket.today,
    'future' => WorkspaceActionBucket.future,
    _ => WorkspaceActionBucket.undated,
  };
}

WorkspaceActionBucket _fallbackBucketForDueAt(DateTime? dueAt) {
  if (dueAt == null) {
    return WorkspaceActionBucket.undated;
  }
  final today = DateTime.now();
  final dueDate = DateTime(dueAt.year, dueAt.month, dueAt.day);
  final todayDate = DateTime(today.year, today.month, today.day);
  if (dueDate.isBefore(todayDate)) {
    return WorkspaceActionBucket.overdue;
  }
  if (dueDate == todayDate) {
    return WorkspaceActionBucket.today;
  }
  return WorkspaceActionBucket.future;
}

LearningCaseStatus _caseStatusFromWire(dynamic value) {
  return switch (_stringValue(value)) {
    'confirmed' => LearningCaseStatus.confirmed,
    'intervening' => LearningCaseStatus.intervening,
    'pending_verification' => LearningCaseStatus.pendingVerification,
    'stable' => LearningCaseStatus.stable,
    'closed' => LearningCaseStatus.closed,
    _ => LearningCaseStatus.newCase,
  };
}

LearningCaseType _caseTypeFromWire(dynamic value) {
  return switch (_stringValue(value)) {
    'knowledge' => LearningCaseType.knowledge,
    'habit' => LearningCaseType.habit,
    'exam_strategy' => LearningCaseType.examStrategy,
    _ => LearningCaseType.other,
  };
}

WorkspaceActionStatus _actionStatusFromWire(dynamic value) {
  return switch (_stringValue(value)) {
    'done' => WorkspaceActionStatus.done,
    'cancelled' => WorkspaceActionStatus.cancelled,
    _ => WorkspaceActionStatus.pending,
  };
}

String _eventTypeLabel(String value) {
  return switch (value) {
    'case_created' => 'Case / 创建',
    'case_confirmed' => 'Case / 确认',
    'evidence_recorded' => 'Evidence / 证据',
    'intervention_recorded' => 'Intervention / 教学动作',
    'assessment_recorded' => 'Assessment / 验证',
    'case_stabilized' => 'Case / 稳定',
    'case_closed' => 'Case / 关闭',
    _ => '记录',
  };
}

String _eventText(String eventType, dynamic rawMetadata) {
  final metadata = rawMetadata is Map
      ? Map<String, dynamic>.from(rawMetadata)
      : const <String, dynamic>{};
  return switch (eventType) {
    'case_created' => '创建了这条 Learning Case。',
    'case_confirmed' => 'Case 已确认，进入正式跟进。',
    'evidence_recorded' => '补充了一条 Evidence。',
    'intervention_recorded' => '记录了一次教学动作。',
    'assessment_recorded' =>
      '记录了一次验证：${_assessmentResultLabel(metadata['result'])}。',
    'case_stabilized' => '教师确认 Case 已稳定，仍可安排复查。',
    'case_closed' => 'Case 已关闭。',
    _ => '记录了一条 Case 事件。',
  };
}

String _assessmentResultLabel(dynamic value) {
  return switch (_stringValue(value)) {
    'passed' => '通过',
    'partial' => '部分通过',
    'not_passed' => '未通过',
    _ => '待判断',
  };
}
