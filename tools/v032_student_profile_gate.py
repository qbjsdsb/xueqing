from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    target = Path(path)
    text = target.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    target.write_text(text.replace(old, new, 1), encoding='utf-8')
    print(f'updated {label}')


# 1) Keep the existing lifecycle command intact for old clients and add a
# dedicated profile command. That prevents a basic-info edit from accidentally
# becoming a status transition.
repo_path = 'lib/cloud/organization_management_repository.dart'
interface_old = """  Future<OrganizationStudentUpdateResult> updateStudent({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String name,
    String? studentCode,
    required String status,
  });
  Future<OrganizationInvitation> createInvitation({
"""
interface_new = """  Future<OrganizationStudentUpdateResult> updateStudent({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String name,
    String? studentCode,
    required String status,
  });

  Future<OrganizationStudentUpdateResult> updateStudentProfile({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String name,
    String? studentCode,
    String? grade,
    String? className,
    String? campus,
  });

  Future<OrganizationInvitation> createInvitation({
"""
replace_once(repo_path, interface_old, interface_new, 'management repository interface')

error_old = """  return switch (detail.toLowerCase()) {
    'invalid_student_update_input' => '学生姓名、编号或状态不符合要求。',
    'student_code_already_exists' => '这个学生编号已被本机构其他学生使用，请核对后修改。',
"""
error_new = """  return switch (detail.toLowerCase()) {
    'invalid_student_update_input' => '学生姓名、编号或状态不符合要求。',
    'invalid_student_profile_update_input' => '学生姓名、编号、年级、班级或校区不符合要求。',
    'student_code_already_exists' => '这个学生编号已被本机构其他学生使用，请核对后修改。',
    'possible_duplicate_student' => '已存在姓名、年级、班级和校区相同的学生；请先核对，确为不同学生时填写不同学生编号。',
    'student_enrollment_not_found' => '这位学生缺少可编辑的在读资料，请刷新后重试。',
"""
replace_once(repo_path, error_old, error_new, 'student profile error mapping')

implementation_old = """  @override
  Future<OrganizationStudentUpdateResult> updateStudent({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String name,
    String? studentCode,
    required String status,
  }) async {
    if (operationId.trim().isEmpty ||
        studentId.trim().isEmpty ||
        name.trim().isEmpty ||
        status.trim().isEmpty) {
      throw ArgumentError('Student update identity cannot be empty.');
    }
    final response = await _call(
      'update_organization_student',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_id': studentId,
        'p_expected_student_version': expectedStudentVersion,
        'p_name': name.trim(),
        'p_student_code': _nullableText(studentCode),
        'p_status': status.trim(),
      },
    );
    return OrganizationStudentUpdateResult.fromJson(_mapResponse(response));
  }

  @override
  Future<OrganizationInvitation> createInvitation({
"""
implementation_new = """  @override
  Future<OrganizationStudentUpdateResult> updateStudent({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String name,
    String? studentCode,
    required String status,
  }) async {
    if (operationId.trim().isEmpty ||
        studentId.trim().isEmpty ||
        name.trim().isEmpty ||
        status.trim().isEmpty) {
      throw ArgumentError('Student update identity cannot be empty.');
    }
    final response = await _call(
      'update_organization_student',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_id': studentId,
        'p_expected_student_version': expectedStudentVersion,
        'p_name': name.trim(),
        'p_student_code': _nullableText(studentCode),
        'p_status': status.trim(),
      },
    );
    return OrganizationStudentUpdateResult.fromJson(_mapResponse(response));
  }

  @override
  Future<OrganizationStudentUpdateResult> updateStudentProfile({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String name,
    String? studentCode,
    String? grade,
    String? className,
    String? campus,
  }) async {
    if (operationId.trim().isEmpty ||
        organizationId.trim().isEmpty ||
        studentId.trim().isEmpty ||
        expectedStudentVersion <= 0 ||
        name.trim().isEmpty) {
      throw ArgumentError('Student profile update identity cannot be empty.');
    }
    final response = await _call(
      'update_organization_student_profile',
      <String, dynamic>{
        'p_operation_id': operationId,
        'p_organization_id': organizationId,
        'p_student_id': studentId,
        'p_expected_student_version': expectedStudentVersion,
        'p_name': name.trim(),
        'p_student_code': _nullableText(studentCode),
        'p_grade': _nullableText(grade),
        'p_class_name': _nullableText(className),
        'p_campus': _nullableText(campus),
      },
    );
    return OrganizationStudentUpdateResult.fromJson(_mapResponse(response));
  }

  @override
  Future<OrganizationInvitation> createInvitation({
"""
replace_once(repo_path, implementation_old, implementation_new, 'Supabase student profile command')

# 2) Replace the small dialog as one cohesive unit. Optional context remains
# genuinely optional; lifecycle controls stay outside this form.
dialog = r'''import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../cloud/learning_repository.dart';
import '../../../cloud/organization_management_repository.dart';

class OrganizationStudentEditDraft {
  const OrganizationStudentEditDraft({
    required this.operationId,
    required this.studentId,
    required this.expectedStudentVersion,
    required this.name,
    required this.studentCode,
    required this.grade,
    required this.className,
    required this.campus,
  });

  final String operationId;
  final String studentId;
  final int expectedStudentVersion;
  final String name;
  final String? studentCode;
  final String? grade;
  final String? className;
  final String? campus;
}

class OrganizationStudentEditDialog extends StatefulWidget {
  const OrganizationStudentEditDialog({
    required this.student,
    required this.onSubmit,
    super.key,
  });

  final OrganizationStudentRecord student;
  final Future<OrganizationStudentUpdateResult> Function(
    OrganizationStudentEditDraft draft,
  )
  onSubmit;

  @override
  State<OrganizationStudentEditDialog> createState() =>
      _OrganizationStudentEditDialogState();
}

class _OrganizationStudentEditDialogState
    extends State<OrganizationStudentEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _studentCodeController;
  late final TextEditingController _gradeController;
  late final TextEditingController _classNameController;
  late final TextEditingController _campusController;
  final String _operationId = createOperationId();
  bool _busy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student.studentName);
    _studentCodeController = TextEditingController(
      text: widget.student.studentCode ?? '',
    );
    _gradeController = TextEditingController(text: widget.student.grade ?? '');
    _classNameController = TextEditingController(
      text: widget.student.className ?? '',
    );
    _campusController = TextEditingController(text: widget.student.campus ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentCodeController.dispose();
    _gradeController.dispose();
    _classNameController.dispose();
    _campusController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.onSubmit(
        OrganizationStudentEditDraft(
          operationId: _operationId,
          studentId: widget.student.studentId,
          expectedStudentVersion: widget.student.version,
          name: _nameController.text.trim(),
          studentCode: _nullableText(_studentCodeController.text),
          grade: _nullableText(_gradeController.text),
          className: _nullableText(_classNameController.text),
          campus: _nullableText(_campusController.text),
        ),
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _describeError(error);
          _busy = false;
        });
      }
    }
  }

  String _describeError(Object error) {
    final message = organizationStudentLifecycleErrorMessage(error);
    if (message != null) return message;
    if (error is AuthException && error.message.trim().isNotEmpty) {
      return '操作未完成：${error.message.trim()}';
    }
    return '保存未完成；表单内容仍保留，可以检查网络后重试。';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('编辑学生资料'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.68,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '修改姓名、编号和在读信息，不会改变教学状态、学科、任课关系、问题或历史记录。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('student-edit-name-field'),
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '学生姓名 *',
                    hintText: '例如：林雨桐',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return '请输入学生姓名。';
                    if (text.length > 120) return '学生姓名不能超过 120 个字符。';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  key: const Key('student-edit-code-field'),
                  controller: _studentCodeController,
                  maxLength: 80,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '学生编号',
                    hintText: '可选，例如 S-001',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  key: const Key('student-edit-grade-field'),
                  controller: _gradeController,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '年级',
                    hintText: '可选，例如 初三',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  key: const Key('student-edit-class-field'),
                  controller: _classNameController,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '班级',
                    hintText: '可选，例如 3 班',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  key: const Key('student-edit-campus-field'),
                  controller: _campusController,
                  maxLength: 120,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: '校区',
                    hintText: '可选，例如 思明校区',
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('student-edit-submit'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存资料'),
        ),
      ],
    );
  }
}

String? _nullableText(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
'''
Path('lib/features/organization_management/presentation/organization_student_edit_dialog.dart').write_text(
    dialog,
    encoding='utf-8',
)
print('replaced student edit dialog')

# 3) Wire the profile-only command from management UI.
actions_path = 'lib/features/organization_management/presentation/organization_management_learning_actions.dart'
actions_old = """          onSubmit: (draft) => widget.repository.updateStudent(
            operationId: draft.operationId,
            organizationId: widget.organizationId,
            studentId: draft.studentId,
            expectedStudentVersion: draft.expectedStudentVersion,
            name: draft.name,
            studentCode: draft.studentCode,
            status: student.status,
          ),
"""
actions_new = """          onSubmit: (draft) => widget.repository.updateStudentProfile(
            operationId: draft.operationId,
            organizationId: widget.organizationId,
            studentId: draft.studentId,
            expectedStudentVersion: draft.expectedStudentVersion,
            name: draft.name,
            studentCode: draft.studentCode,
            grade: draft.grade,
            className: draft.className,
            campus: draft.campus,
          ),
"""
replace_once(actions_path, actions_old, actions_new, 'management student profile wiring')
replace_once(
    actions_path,
    "SnackBar(content: Text('已更新 ${result.studentName} 的基本信息。'))",
    "SnackBar(content: Text('已更新 ${result.studentName} 的基础资料。'))",
    'management profile success copy',
)

# 4) Keep the feature fake honest: lifecycle updates remain old-command updates,
# profile edits update profile fields while preserving status.
feature_test = 'test/features/organization_management_test.dart'
replace_once(
    feature_test,
    "  int studentUpdateCount = 0;\n  int teacherScopeUpdateCount = 0;",
    "  int studentUpdateCount = 0;\n  int studentProfileUpdateCount = 0;\n  int teacherScopeUpdateCount = 0;",
    'feature fake profile counter',
)

fake_old = """  @override
  Future<OrganizationInvitation> createInvitation({
    required String organizationId,
"""
fake_new = """  @override
  Future<OrganizationStudentUpdateResult> updateStudentProfile({
    required String operationId,
    required String organizationId,
    required String studentId,
    required int expectedStudentVersion,
    required String name,
    String? studentCode,
    String? grade,
    String? className,
    String? campus,
  }) async {
    studentProfileUpdateCount++;
    final index = students.indexWhere(
      (student) => student.studentId == studentId,
    );
    if (index < 0) throw StateError('Student not found.');
    final previous = students[index];
    final next = OrganizationStudentRecord(
      studentId: previous.studentId,
      studentName: name,
      studentCode: studentCode,
      status: previous.status,
      version: expectedStudentVersion + 1,
      grade: grade,
      className: className,
      campus: campus,
      startsOn: previous.startsOn,
      endsOn: previous.endsOn,
      subjectNames: previous.subjectNames,
      subjectServices: previous.subjectServices,
    );
    students[index] = next;
    updatedStudent = OrganizationStudentUpdateResult(
      operationId: operationId,
      studentId: studentId,
      studentName: next.studentName,
      studentCode: next.studentCode,
      status: next.status,
      version: next.version,
    );
    return updatedStudent!;
  }

  @override
  Future<OrganizationInvitation> createInvitation({
    required String organizationId,
"""
replace_once(feature_test, fake_old, fake_new, 'feature fake profile method')

widget_old = """  testWidgets('admin edits student identity without changing lifecycle', (
    tester,
  ) async {
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
      students: [_studentRecord()],
    );
    await _pumpManagement(tester, repository);

    expect(find.text('原学生'), findsOneWidget);
    expect(find.text('编辑资料'), findsNothing);
    await _openStudentMoreActions(tester);
    final editButton = find.byKey(
      const ValueKey<String>('student-edit-student-1'),
    );
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(find.text('编辑学生'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('教学可见状态 *'),
      ),
      findsNothing,
    );
    expect(
      find.text('这里只修改姓名和编号。暂停教学、恢复教学与归档属于独立操作，不会在普通编辑中顺带改变。'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField).first, '更新学生');
    await tester.tap(find.text('保存学生'));
    await tester.pumpAndSettle();

    expect(repository.studentUpdateCount, 1);
    expect(repository.updatedStudent?.studentName, '更新学生');
    expect(repository.updatedStudent?.status, 'active');
    expect(repository.updatedStudent?.version, 4);
    expect(find.text('编辑学生'), findsNothing);
  });
"""
widget_new = """  testWidgets('admin edits complete student profile without changing lifecycle', (
    tester,
  ) async {
    final repository = _FakeOrganizationManagementRepository(
      members: const [],
      invitations: const [],
      students: [_studentRecord()],
    );
    await _pumpManagement(tester, repository);

    expect(find.text('原学生'), findsOneWidget);
    expect(find.text('编辑资料'), findsNothing);
    await _openStudentMoreActions(tester);
    final editButton = find.byKey(
      const ValueKey<String>('student-edit-student-1'),
    );
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(find.text('编辑学生资料'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('教学可见状态 *'),
      ),
      findsNothing,
    );
    expect(
      find.text('修改姓名、编号和在读信息，不会改变教学状态、学科、任课关系、问题或历史记录。'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('student-edit-grade-field')),
          )
          .controller
          ?.text,
      '初二',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('student-edit-class-field')),
          )
          .controller
          ?.text,
      'A班',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('student-edit-campus-field')),
          )
          .controller
          ?.text,
      '思明校区',
    );

    await tester.enterText(
      find.byKey(const Key('student-edit-name-field')),
      '更新学生',
    );
    await tester.enterText(
      find.byKey(const Key('student-edit-code-field')),
      'S-UPDATED',
    );
    await tester.enterText(
      find.byKey(const Key('student-edit-grade-field')),
      '初三',
    );
    await tester.enterText(
      find.byKey(const Key('student-edit-class-field')),
      '3班',
    );
    await tester.enterText(
      find.byKey(const Key('student-edit-campus-field')),
      '湖里校区',
    );
    await tester.tap(find.byKey(const Key('student-edit-submit')));
    await tester.pumpAndSettle();

    expect(repository.studentProfileUpdateCount, 1);
    expect(repository.studentUpdateCount, 0);
    expect(repository.updatedStudent?.studentName, '更新学生');
    expect(repository.updatedStudent?.status, 'active');
    expect(repository.updatedStudent?.version, 4);
    expect(repository.students.single.studentCode, 'S-UPDATED');
    expect(repository.students.single.grade, '初三');
    expect(repository.students.single.className, '3班');
    expect(repository.students.single.campus, '湖里校区');
    expect(repository.students.single.subjectServices.single.status, 'active');
    expect(find.text('编辑学生资料'), findsNothing);
  });
"""
replace_once(feature_test, widget_old, widget_new, 'student profile widget regression')

# Add error-copy regressions to the repository unit tests.
repo_test = 'test/cloud/organization_management_repository_test.dart'
repo_test_old = """    expect(
      organizationStudentLifecycleErrorMessage(
        const AuthException('student_code_already_exists'),
      ),
      '这个学生编号已被本机构其他学生使用，请核对后修改。',
    );
  });
"""
repo_test_new = """    expect(
      organizationStudentLifecycleErrorMessage(
        const AuthException('student_code_already_exists'),
      ),
      '这个学生编号已被本机构其他学生使用，请核对后修改。',
    );
    expect(
      organizationStudentLifecycleErrorMessage(
        const AuthException('possible_duplicate_student'),
      ),
      '已存在姓名、年级、班级和校区相同的学生；请先核对，确为不同学生时填写不同学生编号。',
    );
    expect(
      organizationStudentLifecycleErrorMessage(
        const AuthException('student_enrollment_not_found'),
      ),
      '这位学生缺少可编辑的在读资料，请刷新后重试。',
    );
  });
"""
replace_once(repo_test, repo_test_old, repo_test_new, 'student profile error regression')

# 5) DB migration: profile correction is atomic across student identity and the
# same enrollment row displayed by the roster. Student.version serializes the
# aggregate; old update_organization_student remains untouched for compatibility.
migration = r'''-- v0.3.2: allow managers to correct the student profile shown in the roster
-- without coupling that edit to teaching lifecycle transitions.
--
-- The student root version is the optimistic concurrency token for this small
-- aggregate. The selected enrollment follows the same effective/latest rule as
-- list_organization_students, so the row a manager sees is the row being fixed.

alter table public.operation_receipts
  drop constraint if exists operation_receipts_command_type_check;

alter table public.operation_receipts
  add constraint operation_receipts_command_type_check
  check (command_type in (
    'quick_capture_case',
    'confirm_case',
    'add_case_evidence',
    'record_intervention',
    'record_assessment',
    'stabilize_case',
    'close_case',
    'reschedule_case_action',
    'quick_capture_case_with_type',
    'create_organization_case_type',
    'rename_organization_case_type',
    'archive_organization_case_type',
    'create_organization_subject',
    'create_organization_student',
    'add_organization_student_subject_service',
    'end_organization_student_subject_service',
    'restore_organization_student_subject_service',
    'pause_organization_student_teaching',
    'resume_organization_student_teaching',
    'update_organization_student',
    'update_organization_student_profile',
    'transfer_organization_student_teacher_assignment',
    'update_organization_teacher_subject_scope',
    'update_organization_membership_status',
    'create_organization_invitation',
    'approve_organization_invitation',
    'revoke_organization_invitation',
    'reissue_organization_invitation',
    'accept_organization_invitation',
    'prepare_member_credential_reissue',
    'provision_organization_member_from_auth',
    'revoke_member_auth_sessions',
    'complete_member_onboarding',
    'complete_case_action',
    'reopen_case',
    'end_case_follow_up',
    'record_case_progress'
  ));

create or replace function private.update_organization_student_profile(
  p_operation_id uuid,
  p_organization_id uuid,
  p_student_id uuid,
  p_expected_student_version integer,
  p_name text,
  p_student_code text,
  p_grade text,
  p_class_name text,
  p_campus text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  app_user_id uuid;
  v_organization_id uuid;
  v_business_date date;
  v_name text;
  v_student_code text;
  v_grade text;
  v_class_name text;
  v_campus text;
  current_status text;
  current_version integer;
  v_enrollment_id uuid;
  is_claimed boolean;
  existing_result jsonb;
  command_result jsonb;
begin
  v_name := btrim(coalesce(p_name, ''));
  v_student_code := nullif(btrim(coalesce(p_student_code, '')), '');
  v_grade := nullif(btrim(coalesce(p_grade, '')), '');
  v_class_name := nullif(btrim(coalesce(p_class_name, '')), '');
  v_campus := nullif(btrim(coalesce(p_campus, '')), '');

  if p_operation_id is null
    or p_organization_id is null
    or p_student_id is null
    or p_expected_student_version is null
    or p_expected_student_version <= 0
    or char_length(v_name) = 0
    or char_length(v_name) > 120
    or (v_student_code is not null and char_length(v_student_code) > 80)
    or (v_grade is not null and char_length(v_grade) > 120)
    or (v_class_name is not null and char_length(v_class_name) > 120)
    or (v_campus is not null and char_length(v_campus) > 120) then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_student_profile_update_input';
  end if;

  app_user_id := (select private.current_app_user_id_v2());
  if app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  select
    organization.id,
    (now() at time zone organization.time_zone)::date
  into
    v_organization_id,
    v_business_date
  from public.organizations as organization
  where organization.id = p_organization_id
    and organization.status = 'active'
  for update;

  if v_organization_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'organization_not_found';
  end if;

  if not (select private.can_manage_organization_v2(v_organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  select
    student.status,
    student.version
  into
    current_status,
    current_version
  from public.students as student
  where student.id = p_student_id
    and student.organization_id = v_organization_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'student_not_found';
  end if;

  select claimed, result
  into is_claimed, existing_result
  from private.claim_case_operation_v2(
    v_organization_id,
    p_operation_id,
    'update_organization_student_profile',
    'student',
    p_student_id
  );

  if not is_claimed then
    return existing_result;
  end if;

  if current_status = 'merged' then
    raise exception using
      errcode = 'P0001',
      message = 'student_merged_immutable';
  end if;

  if current_version <> p_expected_student_version then
    raise exception using
      errcode = 'P0001',
      message = 'version_conflict';
  end if;

  select enrollment.id
  into v_enrollment_id
  from public.student_enrollments as enrollment
  where enrollment.organization_id = v_organization_id
    and enrollment.student_id = p_student_id
  order by
    case
      when enrollment.starts_on <= v_business_date
        and (enrollment.ends_on is null or enrollment.ends_on >= v_business_date)
        then 0
      else 1
    end,
    enrollment.starts_on desc,
    enrollment.id desc
  limit 1
  for update;

  if v_enrollment_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'student_enrollment_not_found';
  end if;

  update public.students
  set name = v_name,
      student_code = v_student_code,
      version = version + 1,
      updated_at = timezone('utc', now())
  where id = p_student_id
    and organization_id = v_organization_id;

  update public.student_enrollments
  set grade = v_grade,
      class_name = v_class_name,
      campus = v_campus
  where id = v_enrollment_id
    and organization_id = v_organization_id
    and student_id = p_student_id;

  command_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'organization_id', v_organization_id,
    'student_id', p_student_id,
    'student_name', v_name,
    'student_code', v_student_code,
    'grade', v_grade,
    'class_name', v_class_name,
    'campus', v_campus,
    'status', current_status,
    'version', current_version + 1
  );

  perform private.finish_case_operation_v2(
    v_organization_id,
    p_operation_id,
    command_result
  );

  return command_result;
end
$function$;

revoke all on function private.update_organization_student_profile(
  uuid, uuid, uuid, integer, text, text, text, text, text
) from public, anon, authenticated, service_role;
grant execute on function private.update_organization_student_profile(
  uuid, uuid, uuid, integer, text, text, text, text, text
) to authenticated, service_role;

create or replace function public.update_organization_student_profile(
  p_operation_id uuid,
  p_organization_id uuid,
  p_student_id uuid,
  p_expected_student_version integer,
  p_name text,
  p_student_code text,
  p_grade text,
  p_class_name text,
  p_campus text
)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.update_organization_student_profile(
    p_operation_id,
    p_organization_id,
    p_student_id,
    p_expected_student_version,
    p_name,
    p_student_code,
    p_grade,
    p_class_name,
    p_campus
  )
$function$;

revoke all on function public.update_organization_student_profile(
  uuid, uuid, uuid, integer, text, text, text, text, text
) from public, anon, authenticated, service_role;
grant execute on function public.update_organization_student_profile(
  uuid, uuid, uuid, integer, text, text, text, text, text
) to authenticated, service_role;

comment on function public.update_organization_student_profile(
  uuid, uuid, uuid, integer, text, text, text, text, text
) is 'Corrects student identity and the roster-visible enrollment context atomically without changing teaching lifecycle.';
'''
migration_path = Path('supabase/migrations/20260910140000_organization_student_profile_edit.sql')
if migration_path.exists():
    raise SystemExit(f'{migration_path} already exists')
migration_path.write_text(migration, encoding='utf-8')
print('created student profile migration')

# 6) SQL contract: security boundary, lifecycle preservation, effective-row
# targeting, optimistic concurrency and idempotent retry are all executable.
sql_test = r'''begin;

select plan(18);

select is(
  to_regprocedure(
    'public.update_organization_student_profile(uuid,uuid,uuid,integer,text,text,text,text,text)'
  ) is not null,
  true,
  'student profile function exists'
);

select is(
  (
    select prosecdef
    from pg_proc
    where oid = to_regprocedure(
      'public.update_organization_student_profile(uuid,uuid,uuid,integer,text,text,text,text,text)'
    )
  ),
  false,
  'student profile public function is security-invoker wrapper'
);

select is(
  has_function_privilege(
    'anon',
    'public.update_organization_student_profile(uuid,uuid,uuid,integer,text,text,text,text,text)',
    'execute'
  ),
  false,
  'anon cannot update student profiles'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.update_organization_student_profile(uuid,uuid,uuid,integer,text,text,text,text,text)',
    'execute'
  ),
  true,
  'authenticated can reach the guarded student profile command'
);

select is(
  to_regprocedure(
    'public.update_organization_student(uuid,uuid,uuid,integer,text,text,text)'
  ) is not null,
  true,
  'legacy seven-argument student lifecycle RPC remains available'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.update_organization_student(uuid,uuid,uuid,integer,text,text,text)',
    'execute'
  ),
  true,
  'legacy student lifecycle RPC remains callable by authenticated clients'
);

reset role;

insert into public.student_enrollments (
  id,
  organization_id,
  student_id,
  grade,
  class_name,
  campus,
  starts_on,
  ends_on
) values (
  '76000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  '历史年级',
  '历史班级',
  '历史校区',
  date '2025-01-01',
  date '2025-06-30'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-0000-0000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '20000000-0000-0000-0000-000000000001',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000001'
  )::text,
  true
);

select lives_ok(
  $$
    select set_config(
      'xueqing.student_profile_update',
      public.update_organization_student_profile(
        '76000000-0000-0000-0000-000000000010',
        '00000000-0000-0000-0000-000000000001',
        '30000000-0000-0000-0000-000000000001',
        1,
        '林雨桐（资料更新）',
        'S-PROFILE',
        '初三',
        '3班',
        '湖里校区'
      )::text,
      true
    )
  $$,
  'manager can atomically update student profile data'
);

select is(
  current_setting('xueqing.student_profile_update')::jsonb ->> 'status',
  'active',
  'profile edit preserves teaching lifecycle status'
);

select is(
  (current_setting('xueqing.student_profile_update')::jsonb ->> 'version')::int,
  2,
  'profile edit increments the student optimistic version'
);

select is(
  current_setting('xueqing.student_profile_update')::jsonb ->> 'grade',
  '初三',
  'profile edit returns the corrected grade'
);

reset role;

select is(
  (
    select student.name || '|' || student.student_code || '|' ||
      student.status || '|' || student.version::text
    from public.students as student
    where student.id = '30000000-0000-0000-0000-000000000001'
  ),
  '林雨桐（资料更新）|S-PROFILE|active|2',
  'student root stores identity correction without lifecycle drift'
);

select is(
  (
    select enrollment.grade || '|' || enrollment.class_name || '|' || enrollment.campus
    from public.student_enrollments as enrollment
    where enrollment.student_id = '30000000-0000-0000-0000-000000000001'
      and enrollment.id <> '76000000-0000-0000-0000-000000000001'
    order by enrollment.starts_on desc, enrollment.id desc
    limit 1
  ),
  '初三|3班|湖里校区',
  'roster-visible current enrollment stores the corrected school context'
);

select is(
  (
    select enrollment.grade || '|' || enrollment.class_name || '|' || enrollment.campus
    from public.student_enrollments as enrollment
    where enrollment.id = '76000000-0000-0000-0000-000000000001'
  ),
  '历史年级|历史班级|历史校区',
  'profile correction does not rewrite historical enrollment context'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-0000-0000-000000000002',
  true
);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '20000000-0000-0000-0000-000000000002',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000002'
  )::text,
  true
);

select throws_ok(
  $$
    select public.update_organization_student_profile(
      '76000000-0000-0000-0000-000000000011',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      2,
      '越权学生',
      null,
      '越权年级',
      null,
      null
    )
  $$,
  'P0001',
  null,
  'teacher cannot use manager student profile command'
);

select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-0000-0000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '20000000-0000-0000-0000-000000000001',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000001'
  )::text,
  true
);

select throws_ok(
  $$
    select public.update_organization_student_profile(
      '76000000-0000-0000-0000-000000000012',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      1,
      '过期版本',
      null,
      null,
      null,
      null
    )
  $$,
  'P0001',
  null,
  'stale student version is rejected'
);

select lives_ok(
  $$
    select public.update_organization_student_profile(
      '76000000-0000-0000-0000-000000000010',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      1,
      '不同重试值',
      'DIFFERENT',
      '不同年级',
      '不同班级',
      '不同校区'
    )
  $$,
  'retry of a committed profile operation returns the original result'
);

reset role;

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where operation_id = '76000000-0000-0000-0000-000000000010'
      and command_type = 'update_organization_student_profile'
      and target_type = 'student'
      and result ->> 'student_name' = '林雨桐（资料更新）'
      and result ->> 'grade' = '初三'
      and committed_at is not null
  ),
  1,
  'profile retry keeps one committed operation receipt'
);

select is(
  (
    select count(*)::int
    from public.students
    where id = '30000000-0000-0000-0000-000000000001'
      and name = '林雨桐（资料更新）'
      and student_code = 'S-PROFILE'
      and status = 'active'
      and version = 2
  ),
  1,
  'retry does not apply the alternate profile payload'
);

select is(
  (
    select count(*)::int
    from public.student_enrollments
    where student_id = '30000000-0000-0000-0000-000000000001'
      and grade = '初三'
      and class_name = '3班'
      and campus = '湖里校区'
  ),
  1,
  'only the intended enrollment context carries the corrected profile'
);

select is(
  has_table_privilege('authenticated', 'public.student_enrollments', 'update'),
  false,
  'authenticated still cannot bypass the guarded RPC with direct enrollment updates'
);

select * from finish();

rollback;
'''
test_path = Path('supabase/tests/organization_student_profile_edit_test.sql')
if test_path.exists():
    raise SystemExit(f'{test_path} already exists')
test_path.write_text(sql_test, encoding='utf-8')
print('created student profile SQL regression')
