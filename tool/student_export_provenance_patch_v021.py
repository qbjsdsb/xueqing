from pathlib import Path


def replace_exact(text: str, old: str, new: str, label: str, expected: int = 1) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f"{label}: expected {expected} matches, found {count}")
    return text.replace(old, new)


# 1) Keep the existing 下一步/提醒 export semantics while adding provenance.
migration_path = Path(
    "supabase/migrations/20260909063000_student_subject_learning_record_export.sql"
)
migration = migration_path.read_text(encoding="utf-8")
migration = replace_exact(
    migration,
    "  teacher_name text,\n  attachment_count integer,",
    "  teacher_name text,\n  next_step text,\n  attachment_count integer,",
    "migration return columns",
    expected=2,
)
action_projection = """coalesce(nullif(btrim(creator_user.display_name), ''), '未命名成员')
        as teacher_name,
      (
        select action.title
        from public.case_actions as action
        where action.learning_case_id = learning_case.id
          and action.status = 'pending'
          and action.is_primary
        order by action.updated_at desc, action.id
        limit 1
      ) as next_step,
      coalesce(("""
migration = replace_exact(
    migration,
    """coalesce(nullif(btrim(creator_user.display_name), ''), '未命名成员')
        as teacher_name,
      coalesce((""",
    action_projection,
    "case/evidence next-step projection",
    expected=2,
)
action_projection_zero = """coalesce(nullif(btrim(creator_user.display_name), ''), '未命名成员')
        as teacher_name,
      (
        select action.title
        from public.case_actions as action
        where action.learning_case_id = learning_case.id
          and action.status = 'pending'
          and action.is_primary
        order by action.updated_at desc, action.id
        limit 1
      ) as next_step,
      0 as attachment_count,"""
migration = replace_exact(
    migration,
    """coalesce(nullif(btrim(creator_user.display_name), ''), '未命名成员')
        as teacher_name,
      0 as attachment_count,""",
    action_projection_zero,
    "intervention/assessment next-step projection",
    expected=2,
)
migration = replace_exact(
    migration,
    """    raw_records.assessment_result,
    raw_records.teacher_name,
    raw_records.attachment_count,""",
    """    raw_records.assessment_result,
    raw_records.teacher_name,
    raw_records.next_step,
    raw_records.attachment_count,""",
    "final next-step selection",
)
migration_path.write_text(migration, encoding="utf-8")

# 2) Parse the extra next-step field in the narrow client repository.
repo_path = Path("lib/cloud/student_learning_record_repository.dart")
repo = repo_path.read_text(encoding="utf-8")
repo = replace_exact(
    repo,
    """    required this.teacherName,
    required this.attachmentCount,""",
    """    required this.teacherName,
    this.nextStep,
    required this.attachmentCount,""",
    "student record constructor",
)
repo = replace_exact(
    repo,
    """  final String teacherName;
  final int attachmentCount;""",
    """  final String teacherName;
  final String? nextStep;
  final int attachmentCount;""",
    "student record fields",
)
repo = replace_exact(
    repo,
    """      teacherName: _requiredString(json['teacher_name'], 'teacher_name'),
      attachmentCount: _requiredInt(""",
    """      teacherName: _requiredString(json['teacher_name'], 'teacher_name'),
      nextStep: _optionalString(json['next_step']),
      attachmentCount: _requiredInt(""",
    "student record parser",
)
repo_path.write_text(repo, encoding="utf-8")

# 3) Map server-side provenance rows to the existing XLSX surface.
export_path = Path("lib/export/learning_record_export.dart")
export = export_path.read_text(encoding="utf-8")
export = replace_exact(
    export,
    "import '../cloud/learning_repository.dart';\n",
    "import '../cloud/learning_repository.dart';\nimport '../cloud/student_learning_record_repository.dart';\n",
    "export import",
)
student_mapper = """  static List<LearningRecordExportRow> rowsForStudentRecords(
    List<StudentLearningRecord> records,
  ) {
    final rows = <LearningRecordExportRow>[
      for (final record in records)
        LearningRecordExportRow(
          occurredAt: record.occurredAt,
          studentName: record.studentName,
          subjectName: record.subjectName,
          issueTitle: record.issueTitle,
          recordType: _teacherRecordTypeLabel(record.recordKind),
          content: record.content,
          assessmentResult: record.assessmentResult == null
              ? null
              : _assessmentResultLabel(record.assessmentResult!),
          nextStep: record.nextStep,
          teacherName: record.teacherName,
          attachmentNote: record.attachmentCount <= 0
              ? null
              : '${record.attachmentCount} 个附件',
          status: _wireStatusLabel(record.currentStatus),
        ),
    ];
    rows.sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
    return List<LearningRecordExportRow>.unmodifiable(rows);
  }

"""
export = replace_exact(
    export,
    "  static List<LearningRecordExportRow> rowsForTeacherRecords(\n",
    student_mapper + "  static List<LearningRecordExportRow> rowsForTeacherRecords(\n",
    "student export mapper",
)
export_path.write_text(export, encoding="utf-8")

# 4) Inject the narrow repository and use it for student exports when available.
page_path = Path("lib/features/teacher_workspace/presentation/teacher_workspace_page.dart")
page = page_path.read_text(encoding="utf-8")
page = replace_exact(
    page,
    "import '../../../cloud/teacher_learning_record_repository.dart';\n",
    "import '../../../cloud/teacher_learning_record_repository.dart';\nimport '../../../cloud/student_learning_record_repository.dart';\n",
    "page import",
)
page = replace_exact(
    page,
    "    this.teacherLearningRecordRepository,\n",
    "    this.teacherLearningRecordRepository,\n    this.studentLearningRecordRepository,\n",
    "constructor dependencies",
    expected=2,
)
page = replace_exact(
    page,
    "  final TeacherLearningRecordRepository? teacherLearningRecordRepository;\n",
    "  final TeacherLearningRecordRepository? teacherLearningRecordRepository;\n  final StudentLearningRecordRepository? studentLearningRecordRepository;\n",
    "widget dependency fields",
    expected=2,
)
page = replace_exact(
    page,
    "  TeacherLearningRecordRepository? _teacherLearningRecordRepository;\n",
    "  TeacherLearningRecordRepository? _teacherLearningRecordRepository;\n  StudentLearningRecordRepository? _studentLearningRecordRepository;\n",
    "entry state dependency field",
)
page = replace_exact(
    page,
    "      _teacherLearningRecordRepository = widget.teacherLearningRecordRepository;\n",
    "      _teacherLearningRecordRepository = widget.teacherLearningRecordRepository;\n      _studentLearningRecordRepository = widget.studentLearningRecordRepository;\n",
    "injected repository wiring",
)
page = replace_exact(
    page,
    """      _teacherLearningRecordRepository =
          SupabaseTeacherLearningRecordRepository(CloudClient.client);""",
    """      _teacherLearningRecordRepository =
          SupabaseTeacherLearningRecordRepository(CloudClient.client);
      _studentLearningRecordRepository =
          SupabaseStudentLearningRecordRepository(CloudClient.client);""",
    "cloud repository wiring",
)
page = replace_exact(
    page,
    "          teacherLearningRecordRepository: _teacherLearningRecordRepository,\n",
    "          teacherLearningRecordRepository: _teacherLearningRecordRepository,\n          studentLearningRecordRepository: _studentLearningRecordRepository,\n",
    "page dependency pass-through",
)
page = replace_exact(
    page,
    """  Future<void> _exportStudentSubject(WorkspaceStudent student) async {
    final rows = LearningRecordExport.rowsForStudentSubject(student);""",
    """  Future<void> _exportStudentSubject(WorkspaceStudent student) async {
    late final List<LearningRecordExportRow> rows;
    try {
      final recordRepository = widget.studentLearningRecordRepository;
      rows = recordRepository == null
          ? LearningRecordExport.rowsForStudentSubject(student)
          : LearningRecordExport.rowsForStudentRecords(
              await recordRepository.listStudentSubjectRecords(
                profileId: student.profileId,
              ),
            );
    } catch (error, stackTrace) {
      _workspaceLogger.error(
        'student_subject_export_load_failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        final message =
            studentLearningRecordExportErrorMessage(error) ??
            '学情记录暂时无法读取，请检查网络后重试。';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      return;
    }""",
    "student export loading",
)
page_path.write_text(page, encoding="utf-8")

# 5) Extend repository parsing tests with next-step preservation.
test_path = Path("test/cloud/student_learning_record_repository_test.dart")
test = test_path.read_text(encoding="utf-8")
test = replace_exact(
    test,
    "      'teacher_name': '王老师',\n      'attachment_count': 2,",
    "      'teacher_name': '王老师',\n      'next_step': '下节课再检查一次',\n      'attachment_count': 2,",
    "repository test fixture",
)
test = replace_exact(
    test,
    "    expect(record.teacherName, '王老师');\n",
    "    expect(record.teacherName, '王老师');\n    expect(record.nextStep, '下节课再检查一次');\n",
    "repository next-step assertion",
)
test_path.write_text(test, encoding="utf-8")

# 6) Lock the next-step projection into the SQL contract test.
contract_path = Path("test/cloud/student_learning_record_export_sql_contract_test.dart")
contract = contract_path.read_text(encoding="utf-8")
contract = replace_exact(
    contract,
    "      expect(sql, contains('teacher_name text'));\n",
    "      expect(sql, contains('teacher_name text'));\n      expect(sql, contains('next_step text'));\n      expect(sql, contains(\"action.status = 'pending'\"));\n      expect(sql, contains('action.is_primary'));\n",
    "SQL next-step contract",
)
contract_path.write_text(contract, encoding="utf-8")
