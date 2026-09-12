from pathlib import Path


def replace_one(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


composers_path = Path("lib/features/design_v2/v2_composers.dart")
composers = composers_path.read_text()

composers = replace_one(
    composers,
    """class V2ExistingCaseOption {
  const V2ExistingCaseOption({
    required this.id,
    required this.title,
    required this.subject,
    required this.statusLabel,
    required this.nextStepLabel,
    required this.dueLabel,
  });

  final String id;
  final String title;
  final String subject;
  final String statusLabel;
  final String nextStepLabel;
  final String dueLabel;
}

typedef V2QuickCaptureContinueExisting = Future<void> Function(
""",
    """class V2ExistingCaseOption {
  const V2ExistingCaseOption({
    required this.id,
    required this.title,
    required this.subject,
    required this.statusLabel,
    required this.nextStepLabel,
    required this.dueLabel,
  });

  final String id;
  final String title;
  final String subject;
  final String statusLabel;
  final String nextStepLabel;
  final String dueLabel;
}

class V2QuickCaptureSubjectContext {
  const V2QuickCaptureSubjectContext({
    required this.label,
    required this.helperText,
    this.canSave = true,
  });

  final String label;
  final String helperText;
  final bool canSave;
}

typedef V2QuickCaptureContinueExisting = Future<void> Function(
""",
    "subject context model",
)

composers = replace_one(
    composers,
    """  List<V2ProblemTypeOption> problemTypes = v2PreviewProblemTypeOptions,
  List<V2ExistingCaseOption> existingCases = const <V2ExistingCaseOption>[],
  V2QuickCaptureSave? onSave,
""",
    """  List<V2ProblemTypeOption> problemTypes = v2PreviewProblemTypeOptions,
  List<V2ExistingCaseOption> existingCases = const <V2ExistingCaseOption>[],
  Map<String, V2QuickCaptureSubjectContext> subjectContexts =
      const <String, V2QuickCaptureSubjectContext>{},
  V2QuickCaptureSave? onSave,
""",
    "show quick capture signature",
)

composers = replace_one(
    composers,
    """          problemTypes: problemTypes,
          existingCases: existingCases,
          onSave: onSave,
""",
    """          problemTypes: problemTypes,
          existingCases: existingCases,
          subjectContexts: subjectContexts,
          onSave: onSave,
""",
    "show quick capture pass-through",
)

composers = replace_one(
    composers,
    """    this.existingCases = const <V2ExistingCaseOption>[],
    this.onSave,
""",
    """    this.existingCases = const <V2ExistingCaseOption>[],
    this.subjectContexts = const <String, V2QuickCaptureSubjectContext>{},
    this.onSave,
""",
    "composer constructor contexts",
)

composers = replace_one(
    composers,
    """  final List<V2ExistingCaseOption> existingCases;
  final V2QuickCaptureSave? onSave;
""",
    """  final List<V2ExistingCaseOption> existingCases;
  final Map<String, V2QuickCaptureSubjectContext> subjectContexts;
  final V2QuickCaptureSave? onSave;
""",
    "composer contexts field",
)

composers = replace_one(
    composers,
    """  bool get _canSave =>
      !_saving &&
      _selectedSubject != null &&
      _controller.text.trim().isNotEmpty;

  List<V2ExistingCaseOption> get _matchingExistingCases {
""",
    """  V2QuickCaptureSubjectContext? get _selectedSubjectContext {
    final subject = _selectedSubject;
    if (subject == null) return null;
    return widget.subjectContexts[subject];
  }

  bool get _canSave =>
      !_saving &&
      _selectedSubject != null &&
      (_selectedSubjectContext?.canSave ?? true) &&
      _controller.text.trim().isNotEmpty;

  List<V2ExistingCaseOption> get _matchingExistingCases {
""",
    "composer save gate",
)

composers = replace_one(
    composers,
    """              const SizedBox(height: 22),
            ],
            Text('今天发现什么？', style: Theme.of(context).textTheme.titleMedium),
""",
    """              const SizedBox(height: 14),
            ],
            if (_selectedSubjectContext != null) ...[
              _QuickCaptureSubjectContextPanel(
                subjectContext: _selectedSubjectContext!,
              ),
              const SizedBox(height: 18),
            ],
            Text('今天发现什么？', style: Theme.of(context).textTheme.titleMedium),
""",
    "composer context panel placement",
)

composers = replace_one(
    composers,
    """class _ExistingCaseContinuationPanel extends StatelessWidget {
""",
    """class _QuickCaptureSubjectContextPanel extends StatelessWidget {
  const _QuickCaptureSubjectContextPanel({required this.subjectContext});

  final V2QuickCaptureSubjectContext subjectContext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocked = !subjectContext.canSave;
    return Container(
      key: const Key('v2-quick-capture-subject-context'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: blocked ? scheme.error : scheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            blocked ? Icons.person_off_outlined : Icons.person_outline,
            size: 19,
            color: blocked ? scheme.error : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subjectContext.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: blocked ? scheme.error : scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subjectContext.helperText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExistingCaseContinuationPanel extends StatelessWidget {
""",
    "subject context panel class",
)

composers_path.write_text(composers)

org_path = Path("lib/features/design_v2/v2_organization_workspace_page.dart")
org = org_path.read_text()

org = replace_one(
    org,
    """    if (profiles.isEmpty) return;
    final hasLead = profiles.any(
      (profile) =>
          widget.responsibility.leadMembershipIdForProfile(profile.profileId) !=
          null,
    );
    if (!hasLead) {
""",
    """    if (profiles.isEmpty) return;
    final subjectContexts = <String, V2QuickCaptureSubjectContext>{};
    for (final subject in student.subjects) {
      final matchingProfiles = profiles
          .where((profile) => profile.subject == subject)
          .toList(growable: false);
      if (matchingProfiles.length != 1) {
        subjectContexts[subject] = const V2QuickCaptureSubjectContext(
          label: '主责信息暂不可用',
          helperText: '当前学科的责任关系无法安全确认，请刷新学情后再记录。',
          canSave: false,
        );
        continue;
      }
      final profile = matchingProfiles.single;
      final leadMembershipId = widget.responsibility.leadMembershipIdForProfile(
        profile.profileId,
      );
      if (leadMembershipId == null) {
        subjectContexts[subject] = const V2QuickCaptureSubjectContext(
          label: '尚未明确主责老师',
          helperText: '正式学情必须有人持续负责。请先在机构管理中设置主责老师。',
          canSave: false,
        );
        continue;
      }
      final leadLabel =
          widget.responsibility.displayNameForMembership(leadMembershipId) ??
          '主责老师';
      final currentTeacherSuffix =
          leadMembershipId == widget.responsibility.currentMembershipId
          ? '（你）'
          : '';
      subjectContexts[subject] = V2QuickCaptureSubjectContext(
        label: '教学主责：$leadLabel$currentTeacherSuffix',
        helperText: '你正在以机构视角记录，本次记录不会改变主责老师。',
      );
    }
    final hasLead = subjectContexts.values.any((context) => context.canSave);
    if (!hasLead) {
""",
    "organization responsibility contexts",
)

org = replace_one(
    org,
    """      problemTypes: problemTypes,
      existingCases: existingCases,
      persistence: persistence,
""",
    """      problemTypes: problemTypes,
      existingCases: existingCases,
      subjectContexts: subjectContexts,
      persistence: persistence,
""",
    "organization context pass-through",
)
org_path.write_text(org)

test_path = Path("test/features/v2_organization_quick_capture_test.dart")
test = test_path.read_text()

test = replace_one(
    test,
    """      expect(find.text('记录新问题'), findsOneWidget);
      expect(drafts.lastLoadedScope, isNotNull);
""",
    """      expect(find.text('记录新问题'), findsOneWidget);
      expect(find.text('教学主责：张老师'), findsOneWidget);
      expect(
        find.text('你正在以机构视角记录，本次记录不会改变主责老师。'),
        findsOneWidget,
      );
      expect(drafts.lastLoadedScope, isNotNull);
""",
    "assigned responsibility preview assertion",
)

insertion = """
  testWidgets(
    'Organization Quick Capture shows mixed subject responsibility before save',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final learning = _FakeOrganizationLearningRepository();
      await tester.pumpWidget(
        _app(
          learning: learning,
          workspace: _multiSubjectWorkspace(),
          responsibility: _multiSubjectResponsibility(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('v2-organization-quick-capture-student-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('选择学科'), findsOneWidget);
      expect(find.text('教学主责：张老师'), findsNothing);

      await tester.tap(find.text('历史'));
      await tester.pump();
      expect(find.text('尚未明确主责老师'), findsOneWidget);
      expect(
        find.text('正式学情必须有人持续负责。请先在机构管理中设置主责老师。'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('v2-quick-capture-body')),
        '历史材料题暴露出新的问题。',
      );
      await tester.pump();
      var save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '记录问题'),
      );
      expect(save.onPressed, isNull);
      expect(learning.organizationCalls, 0);

      await tester.tap(find.text('语文'));
      await tester.pump();
      expect(find.text('教学主责：张老师'), findsOneWidget);
      expect(find.text('尚未明确主责老师'), findsNothing);
      save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '记录问题'),
      );
      expect(save.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

"""
marker = """  testWidgets(
    'Organization Quick Capture fails closed when the Profile has no Lead',
"""
if marker not in test:
    raise SystemExit("mixed responsibility test insertion marker missing")
test = test.replace(marker, insertion + marker, 1)

test = replace_one(
    test,
    """Widget _app({
  required _FakeOrganizationLearningRepository learning,
  required WorkspaceResponsibilityContext responsibility,
  ComposerDraftStore? drafts,
}) {
  final workspace = _workspace();
""",
    """Widget _app({
  required _FakeOrganizationLearningRepository learning,
  required WorkspaceResponsibilityContext responsibility,
  ComposerDraftStore? drafts,
  TeacherWorkspace? workspace,
}) {
  final resolvedWorkspace = workspace ?? _workspace();
""",
    "test app optional workspace",
)

test = replace_one(
    test,
    """      workspace: workspace,
      workspaceData: V2ReadModelAdapter.fromWorkspace(workspace).workspaceData,
""",
    """      workspace: resolvedWorkspace,
      workspaceData: V2ReadModelAdapter.fromWorkspace(resolvedWorkspace)
          .workspaceData,
""",
    "test app resolved workspace",
)

helpers = """
TeacherWorkspace _multiSubjectWorkspace() => TeacherWorkspace(
  viewerName: '李老师',
  organizationName: '测试机构',
  organizationTimeZone: 'Asia/Shanghai',
  organizationId: 'org-1',
  hasTeachingAccess: true,
  canManageOrganization: true,
  roles: const ['org_admin'],
  loadedAt: DateTime(2026, 9, 12, 12),
  businessDate: DateTime(2026, 9, 12),
  students: [
    WorkspaceStudent(
      id: 'student-1',
      profileId: 'profile-cn',
      profileVersion: 3,
      name: '机构学生',
      grade: '初三',
      subject: '语文',
      context: '',
      positioning: null,
      strengths: null,
      cadenceNote: null,
      cases: const [],
      recentFacts: const [],
    ),
    WorkspaceStudent(
      id: 'student-1',
      profileId: 'profile-history',
      profileVersion: 1,
      name: '机构学生',
      grade: '初三',
      subject: '历史',
      context: '',
      positioning: null,
      strengths: null,
      cadenceNote: null,
      cases: const [],
      recentFacts: const [],
    ),
  ],
);

WorkspaceResponsibilityContext _multiSubjectResponsibility() =>
    WorkspaceResponsibilityContext(
      organizationId: 'org-1',
      currentMembershipId: 'membership-manager',
      personalAssignments: const [],
      caseOwnerMembershipIds: const {},
      actionAssignedMembershipIds: const {},
      eventActorMembershipIds: const {},
      memberDisplayNames: const {
        'membership-manager': '李老师',
        'membership-lead': '张老师',
      },
      profileLeadMembershipIds: const {
        'profile-cn': 'membership-lead',
        'profile-history': null,
      },
    );

"""
helper_marker = """WorkspaceResponsibilityContext _responsibility({
"""
if helper_marker not in test:
    raise SystemExit("helper insertion marker missing")
test = test.replace(helper_marker, helpers + helper_marker, 1)
test_path.write_text(test)
