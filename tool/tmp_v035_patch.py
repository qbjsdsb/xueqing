from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f"expected exactly one match in {path}, got {count}: {old[:120]!r}"
        )
    p.write_text(text.replace(old, new, 1))


# 1) Timeline semantics: heading already carries the assessment result.
replace_once(
    "lib/features/design_v2/v2_read_model_adapter.dart",
    "              body: event.text,",
    "              body: _timelineBody(event),",
)
marker = "  static bool _isActiveCase(WorkspaceCase learningCase) =>\n"
helper = r'''  static String _timelineBody(WorkspaceTimelineEvent event) {
    final text = event.text.trim();
    const assessmentPrefix = '检查结果 · ';
    if (!event.typeLabel.startsWith(assessmentPrefix) || text.isEmpty) {
      return text;
    }

    final resultLabel = event.typeLabel
        .substring(assessmentPrefix.length)
        .trim();
    if (resultLabel.isEmpty) return text;

    final lines = text.split('\n');
    if (lines.isEmpty) return text;
    String normalize(String value) => value
        .trim()
        .replaceAll('：', ':')
        .replaceAll(RegExp(r'\s+'), '');
    if (normalize(lines.first) != normalize('检查结果：$resultLabel')) {
      return text;
    }
    return lines.skip(1).join('\n').trim();
  }

'''
replace_once(
    "lib/features/design_v2/v2_read_model_adapter.dart", marker, helper + marker
)

replace_once(
    "lib/features/design_v2/v2_workspace_preview.dart",
    """                const SizedBox(height: 5),
                Text(entry.body, style: Theme.of(context).textTheme.bodyMedium),
""",
    """                if (entry.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    entry.body,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
""",
)

# 2) Excel semantics: issue title has its own column; detail only contains
# genuinely additional information.
replace_once(
    "lib/export/learning_record_export.dart",
    "          content: initialContent.isEmpty ? learningCase.title : initialContent,",
    "          content: _dedupeIssueContent(learningCase.title, initialContent),",
)
replace_once(
    "lib/export/learning_record_export.dart",
    "            content: '${evidence.title}：${evidence.summary}',",
    """            content: _dedupeIssueContent(
              learningCase.title,
              '${evidence.title}：${evidence.summary}',
            ),""",
)
p = Path("lib/export/learning_record_export.dart")
text = p.read_text()
needle = "          content: record.content,"
if text.count(needle) != 2:
    raise SystemExit(f"expected 2 record.content projections, got {text.count(needle)}")
p.write_text(
    text.replace(
        needle,
        "          content: _dedupeIssueContent(record.issueTitle, record.content),",
    )
)
marker = "  static String _statusLabel(LearningCaseStatus status) {\n"
helper = r'''  static String _dedupeIssueContent(String issueTitle, String content) {
    final issue = issueTitle.trim();
    final text = content.trim();
    if (text.isEmpty || issue.isEmpty) return text;
    if (_semanticTextKey(text) == _semanticTextKey(issue)) return '';

    final lines = text.split('\n');
    if (lines.isNotEmpty &&
        _semanticTextKey(lines.first) == _semanticTextKey(issue)) {
      return lines.skip(1).join('\n').trim();
    }

    for (final separator in const ['：', ':']) {
      final prefix = '$issue$separator';
      if (!text.startsWith(prefix)) continue;
      final remainder = text.substring(prefix.length).trim();
      if (remainder.isEmpty ||
          _semanticTextKey(remainder) == _semanticTextKey(issue)) {
        return '';
      }
      return remainder;
    }

    for (final label in const ['具体表现：', '具体表现:']) {
      if (!text.startsWith(label)) continue;
      final remainder = text.substring(label.length).trim();
      if (_semanticTextKey(remainder) == _semanticTextKey(issue)) {
        return '';
      }
    }
    return text;
  }

  static String _semanticTextKey(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(
        RegExp(r'[\s，。！？、；：,.!?;:"“”‘’（）()\[\]【】《》—–\-·…]+'),
        '',
      );

'''
replace_once("lib/export/learning_record_export.dart", marker, helper + marker)

# 3) Backend drift error copy: do not blame the user's network when PostgREST
# says the installed client is calling a function missing from schema cache.
marker = "String? organizationSubjectSetupErrorMessage(Object error) {\n"
helper = r'''String? organizationBackendCompatibilityErrorMessage(Object error) {
  if (error is! PostgrestException) return null;
  final code = error.code.trim().toUpperCase();
  final detail = [error.message, error.details, error.hint]
      .whereType<Object>()
      .map((item) => item.toString())
      .join(' ')
      .toLowerCase();
  if (code == 'PGRST202' ||
      detail.contains('could not find the function') ||
      detail.contains('schema cache')) {
    return '当前软件与服务端版本暂不一致，请刷新后重试；如仍出现，请联系负责人更新服务端。';
  }
  return null;
}

'''
replace_once(
    "lib/cloud/organization_management_repository.dart", marker, helper + marker
)
replace_once(
    "lib/features/organization_management/presentation/organization_student_edit_dialog.dart",
    """  String _describeError(Object error) {
    final message = organizationStudentLifecycleErrorMessage(error);
    if (message != null) return message;
""",
    """  String _describeError(Object error) {
    final compatibilityMessage = organizationBackendCompatibilityErrorMessage(
      error,
    );
    if (compatibilityMessage != null) return compatibilityMessage;
    final message = organizationStudentLifecycleErrorMessage(error);
    if (message != null) return message;
""",
)

# 4) Data-free production compatibility contract.
Path("supabase/migrations/20260911153000_backend_compatibility_contract.sql").write_text(
    r'''-- v0.3.5: data-free production backend compatibility contract.
-- Stable release CI calls this with the public publishable key before signing
-- and publishing clients. It exposes no student/member data or credentials.

create or replace function public.xueqing_backend_compatibility()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $function$
  select jsonb_build_object(
    'contract_version', 1,
    'schema_version', '20260911153000',
    'capabilities', jsonb_build_object(
      'student_profile_edit',
        to_regprocedure(
          'public.update_organization_student_profile(uuid,uuid,uuid,integer,text,text,text,text,text)'
        ) is not null,
      'learning_record_export_attachments',
        to_regprocedure(
          'public.list_student_subject_learning_records_with_attachments(uuid,integer,integer)'
        ) is not null
    )
  )
$function$;

revoke all on function public.xueqing_backend_compatibility()
  from public, anon, authenticated, service_role;
grant execute on function public.xueqing_backend_compatibility()
  to anon, authenticated, service_role;

comment on function public.xueqing_backend_compatibility() is
  'Data-free schema/capability contract used by stable release compatibility gates.';
'''
)

# Stable publisher must prove production backend compatibility before expensive
# signed builds begin.
workflow = Path(".github/workflows/publish-release-assets.yml")
text = workflow.read_text()
anchor = '''          if [[ -z "$XUEQING_SUPABASE_URL" || -z "$XUEQING_SUPABASE_PUBLISHABLE_KEY" || -z "$XUEQING_SUPABASE_ALLOWED_HOSTS" ]]; then
            echo "Stable production releases require Supabase URL, publishable key, and allowed hosts."
            exit 1
          fi
'''
gate = anchor + '''          backend_json="$(curl --fail-with-body --silent --show-error --retry 2 --retry-all-errors --connect-timeout 10 --max-time 30 \\
            -X POST "${XUEQING_SUPABASE_URL%/}/rest/v1/rpc/xueqing_backend_compatibility" \\
            -H "apikey: $XUEQING_SUPABASE_PUBLISHABLE_KEY" \\
            -H "Content-Type: application/json" \\
            -d '{}')"
          BACKEND_JSON="$backend_json" python3 - <<'PY_BACKEND'
          import json
          import os

          required_schema = "20260911153000"
          payload = json.loads(os.environ["BACKEND_JSON"])
          actual_schema = str(payload.get("schema_version", ""))
          capabilities = payload.get("capabilities") or {}
          if actual_schema < required_schema:
              raise SystemExit(
                  f"Production backend is older than this client requires: {actual_schema!r} < {required_schema}."
              )
          required_capabilities = (
              "student_profile_edit",
              "learning_record_export_attachments",
          )
          missing = [
              name for name in required_capabilities
              if capabilities.get(name) is not True
          ]
          if missing:
              raise SystemExit(
                  "Production backend is missing required capabilities: "
                  + ", ".join(missing)
              )
          print(f"production backend schema {actual_schema} is compatible")
          PY_BACKEND
'''
if text.count(anchor) != 1:
    raise SystemExit("stable publisher compatibility insertion anchor not unique")
workflow.write_text(text.replace(anchor, gate, 1))

# Focused regression: duplicate assessment text is presentation-only, not a
# duplicate historical fact.
p = Path("test/features/design_v2_read_model_adapter_test.dart")
text = p.read_text()
anchor = "  });\n}\n\nTeacherWorkspace _workspace()"
test = r'''    test('removes duplicated assessment wording but preserves real follow-up text', () {
      final workspace = TeacherWorkspace(
        viewerName: '乔老师',
        organizationName: '测试机构',
        organizationTimeZone: 'Asia/Shanghai',
        hasTeachingAccess: true,
        loadedAt: DateTime(2026, 9, 11, 14),
        students: [
          WorkspaceStudent(
            id: 'student-1',
            profileId: 'profile-1',
            profileVersion: 1,
            name: '吴同学',
            grade: '初三',
            subject: '历史',
            context: '',
            positioning: null,
            strengths: null,
            cadenceNote: null,
            cases: [
              _case(
                id: 'case-assessment-copy',
                profileId: 'profile-1',
                title: '拜占庭帝国',
                status: LearningCaseStatus.closed,
                version: 2,
                timeline: [
                  WorkspaceTimelineEvent(
                    id: 'assessment-only',
                    occurredAt: DateTime(2026, 9, 9, 12, 30),
                    typeLabel: '检查结果 · 通过',
                    text: '检查结果：通过',
                  ),
                  WorkspaceTimelineEvent(
                    id: 'assessment-closed',
                    occurredAt: DateTime(2026, 9, 9, 13, 3),
                    typeLabel: '检查结果 · 通过',
                    text: '检查结果：通过\n结束跟进。',
                  ),
                ],
              ),
            ],
            recentFacts: const [],
          ),
        ],
      );

      final timeline = V2ReadModelAdapter.fromWorkspace(
        workspace,
      ).timelineForCase('case-assessment-copy');
      expect(timeline, hasLength(2));
      expect(timeline.first.kind, '检查结果 · 通过');
      expect(timeline.first.body, '结束跟进。');
      expect(timeline.last.body, isEmpty);
    });
  });
}

TeacherWorkspace _workspace()'''
if text.count(anchor) != 1:
    raise SystemExit("read model test insertion anchor not unique")
p.write_text(text.replace(anchor, test, 1))

p = Path("test/export/student_learning_record_export_test.dart")
text = p.read_text()
anchor = "\n}\n"
if not text.endswith(anchor):
    raise SystemExit("student export test ending changed")
test = r'''

  test('keeps issue title and detail columns semantically distinct', () {
    final rows = LearningRecordExport.rowsForStudentRecords(
      <StudentLearningRecord>[
        StudentLearningRecord(
          id: 'created-1',
          occurredAt: DateTime.utc(2026, 9, 9, 10),
          studentName: '示例学生',
          subjectName: '道德与法治',
          issueTitle: '分点作答意识不够',
          recordKind: 'case_created',
          content: '分点作答意识不够：分点作答意识不够',
          teacherName: '乔老师',
          attachmentCount: 0,
          currentStatus: 'confirmed',
        ),
        StudentLearningRecord(
          id: 'evidence-1',
          occurredAt: DateTime.utc(2026, 9, 9, 11),
          studentName: '示例学生',
          subjectName: '道德与法治',
          issueTitle: '分点作答意识不够',
          recordKind: 'evidence',
          content: '分点作答意识不够：第二问仍漏了一个得分点',
          teacherName: '乔老师',
          attachmentCount: 0,
          currentStatus: 'confirmed',
        ),
      ],
    );

    expect(rows.first.issueTitle, '分点作答意识不够');
    expect(rows.first.content, isEmpty);
    expect(rows.last.content, '第二问仍漏了一个得分点');
  });
'''
p.write_text(text[: -len(anchor)] + test + anchor)

p = Path("test/cloud/organization_management_repository_test.dart")
text = p.read_text()
anchor = "  test('maps invitation authorization errors to actionable copy', () {\n"
test = r'''  test('maps missing production RPCs to a backend compatibility message', () {
    expect(
      organizationBackendCompatibilityErrorMessage(
        const PostgrestException(
          message: 'Could not find the function public.update_organization_student_profile in the schema cache',
          code: 'PGRST202',
          details: '',
          hint: '',
        ),
      ),
      '当前软件与服务端版本暂不一致，请刷新后重试；如仍出现，请联系负责人更新服务端。',
    );
    expect(
      organizationBackendCompatibilityErrorMessage(
        const PostgrestException(
          message: 'organization_manager_required',
          code: 'P0001',
          details: '',
          hint: '',
        ),
      ),
      isNull,
    );
  });

'''
if text.count(anchor) != 1:
    raise SystemExit("organization repository test insertion anchor not unique")
p.write_text(text.replace(anchor, test + anchor, 1))

p = Path("test/update/stable_release_workflow_contract_test.dart")
text = p.read_text()
anchor = "  test('stable publisher verifies the permanent Android signing identity', () {\n"
test = r'''  test('stable publisher blocks clients newer than production backend', () {
    final workflow = File('.github/workflows/publish-release-assets.yml')
        .readAsStringSync();

    expect(workflow, contains('xueqing_backend_compatibility'));
    expect(workflow, contains('20260911153000'));
    expect(workflow, contains('student_profile_edit'));
    expect(workflow, contains('learning_record_export_attachments'));
    expect(
      workflow,
      contains('Production backend is older than this client requires'),
    );
  });

'''
if text.count(anchor) != 1:
    raise SystemExit("stable workflow test insertion anchor not unique")
p.write_text(text.replace(anchor, test + anchor, 1))
