from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one match, found {count}: {old[:100]!r}")
    file.write_text(text.replace(old, new, 1))


# 1) Membership gate: a signed-in account with no organization must be able to
# accept an invitation or leave the session before the V2 business shell starts.
join_page = Path(
    "lib/features/organization_management/presentation/organization_invitation_join_page.dart"
)
join_page.write_text(
    r'''import 'package:flutter/material.dart';

import '../../../cloud/organization_management_repository.dart';
import 'organization_invitation_acceptance_card.dart';

class OrganizationInvitationJoinPage extends StatefulWidget {
  const OrganizationInvitationJoinPage({
    required this.repository,
    required this.onJoined,
    this.email,
    this.onSignOut,
    super.key,
  });

  final OrganizationInvitationAcceptanceRepository? repository;
  final Future<void> Function() onJoined;
  final String? email;
  final VoidCallback? onSignOut;

  @override
  State<OrganizationInvitationJoinPage> createState() =>
      _OrganizationInvitationJoinPageState();
}

class _OrganizationInvitationJoinPageState
    extends State<OrganizationInvitationJoinPage> {
  final _formKey = GlobalKey<FormState>();
  final _inviteCodeController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _busy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final repository = widget.repository;
    if (_busy || repository == null) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await repository.acceptInvitation(
        inviteCode: _inviteCodeController.text.trim(),
        displayName: _displayNameController.text.trim(),
      );
      _inviteCodeController.clear();
      _displayNameController.clear();
      await widget.onJoined();
    } catch (error) {
      if (!mounted) return;
      final known = organizationInvitationErrorMessage(error);
      setState(() {
        _errorMessage = known == null
            ? '接受邀请失败，请检查邀请代码、登录邮箱和网络后重试。'
            : '接受邀请失败：$known';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email?.trim();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 36,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '加入机构',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email == null || email.isEmpty
                        ? '当前账号还没有加入机构。收到邀请代码后，可以在这里完成加入。'
                        : '当前登录账号：$email\n这个账号还没有加入机构。收到邀请代码后，可以在这里完成加入。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  if (widget.repository != null)
                    OrganizationInvitationAcceptanceCard(
                      formKey: _formKey,
                      inviteCodeController: _inviteCodeController,
                      displayNameController: _displayNameController,
                      busy: _busy,
                      initiallyExpanded: true,
                      errorMessage: _errorMessage,
                      onAccept: () => _accept(),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          '当前环境没有配置邀请加入能力。你可以先退出当前账号，再联系负责人确认账号配置。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  if (widget.onSignOut != null) ...[
                    const SizedBox(height: 14),
                    TextButton.icon(
                      key: const Key('invitation-join-sign-out'),
                      onPressed: _busy ? null : widget.onSignOut,
                      icon: const Icon(Icons.logout_outlined),
                      label: const Text('退出当前账号'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
'''
)

entry = "lib/features/teacher_workspace/presentation/teacher_workspace_page.dart"
replace_once(
    entry,
    "import '../../organization_management/presentation/organization_invitation_acceptance_card.dart';\nimport '../../organization_management/presentation/organization_management_page.dart';",
    "import '../../organization_management/presentation/organization_invitation_acceptance_card.dart';\nimport '../../organization_management/presentation/organization_invitation_join_page.dart';\nimport '../../organization_management/presentation/organization_management_page.dart';",
)
replace_once(
    entry,
    """        if (membershipState?.isDisabled == true) {
          return _WorkspaceStatusScaffold(
            title: '账号已停用',
            child: _WorkspaceErrorBody(
              title: '暂时无法进入工作台',
              message: '当前账号已被机构负责人停用，请联系负责人处理。',
              onRetry: () => unawaited(_signOut()),
            ),
          );
        }
        final authenticatedWorkspaceBuilder =
""",
    """        if (membershipState?.isDisabled == true) {
          return _WorkspaceStatusScaffold(
            title: '账号已停用',
            child: _WorkspaceErrorBody(
              title: '暂时无法进入工作台',
              message: '当前账号已被机构负责人停用，请联系负责人处理。',
              onRetry: () => unawaited(_signOut()),
            ),
          );
        }
        if (membershipState?.status == 'none') {
          return OrganizationInvitationJoinPage(
            key: ValueKey('join-organization-$_activeUserId'),
            repository: _invitationAcceptanceRepository,
            email: _authRepository!.currentUser?.email,
            onJoined: _loadMembershipState,
            onSignOut: _busy ? null : () => unawaited(_signOut()),
          );
        }
        final authenticatedWorkspaceBuilder =
""",
)

# 2) Admin wording must reflect the current hardened contract: learning and
# operations yes, member-account writes no.
areas = "lib/features/organization_management/presentation/organization_management_areas.dart"
replace_once(
    areas,
    "description: '管理机构成员、账号状态和老师可教学科。邮箱只用于登录，日常协作优先显示姓名。',",
    "description: widget.isOwner\n          ? '管理机构成员、账号状态和老师可教学科。邮箱只用于登录，日常协作优先显示姓名。'\n          : '查看机构成员并管理老师可教学科；邀请、停用和账号凭据由负责人处理。',",
)

# 3) Carry a real due date into the presentation model so Today can sort
# deterministically without parsing localized labels.
fixture = "lib/features/design_v2/v2_fixture.dart"
replace_once(
    fixture,
    """    required this.subject,
    this.actionTiming,
    this.pendingVerification = false,
""",
    """    required this.subject,
    this.actionTiming,
    this.dueOn,
    this.pendingVerification = false,
""",
)
replace_once(
    fixture,
    """  final String subject;
  final V2ActionTiming? actionTiming;
  final bool pendingVerification;
""",
    """  final String subject;
  final V2ActionTiming? actionTiming;
  final DateTime? dueOn;
  final bool pendingVerification;
""",
)

adapter = "lib/features/design_v2/v2_read_model_adapter.dart"
replace_once(
    adapter,
    """          actionTiming: closed ? null : _actionTiming(primaryAction),
          pendingVerification:
""",
    """          actionTiming: closed ? null : _actionTiming(primaryAction),
          dueOn: closed ? null : _actionDueOn(primaryAction),
          pendingVerification:
""",
)
replace_once(
    adapter,
    """  static String _dueLabel(WorkspaceAction? action) {
    if (action == null) {
      return '待安排';
    }
    final date = action.businessDueDate ?? action.dueAt;
    return date == null ? '待安排' : _dateLabel(date);
  }
""",
    """  static DateTime? _actionDueOn(WorkspaceAction? action) =>
      action?.businessDueDate ?? action?.dueAt;

  static String _dueLabel(WorkspaceAction? action) {
    final date = _actionDueOn(action);
    return date == null ? '待安排' : _dateLabel(date);
  }
""",
)

preview = "lib/features/design_v2/v2_workspace_preview.dart"

# Searchable student picker shared by phone and desktop quick capture.
old_picker = r'''  Widget choices(BuildContext selectionContext) => ListView.separated(
    shrinkWrap: true,
    itemCount: students.length,
    separatorBuilder: (_, _) => Divider(
      height: 1,
      color: Theme.of(selectionContext).colorScheme.outlineVariant,
    ),
    itemBuilder: (_, index) {
      final student = students[index];
      return ListTile(
        title: Text(student.name),
        subtitle: Text('${student.grade} · ${student.subjects.join(' / ')}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(selectionContext).pop(student),
      );
    },
  );

  final compact = MediaQuery.sizeOf(context).width < 720;
  final selected = compact
      ? await showModalBottomSheet<V2Student>(
          context: context,
          useSafeArea: true,
          showDragHandle: true,
          builder: (sheetContext) => Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择学生',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 480),
                  child: choices(sheetContext),
                ),
              ],
            ),
          ),
        )
      : await showDialog<V2Student>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('选择学生'),
            content: SizedBox(
              width: 420,
              height: 480,
              child: choices(dialogContext),
            ),
          ),
        );
'''
new_picker = r'''  final compact = MediaQuery.sizeOf(context).width < 720;
  final selected = compact
      ? await showModalBottomSheet<V2Student>(
          context: context,
          useSafeArea: true,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (sheetContext) => Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              8,
              18,
              28 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 560),
              child: _V2StudentPicker(students: students),
            ),
          ),
        )
      : await showDialog<V2Student>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            content: SizedBox(
              width: 440,
              height: 540,
              child: _V2StudentPicker(students: students),
            ),
          ),
        );
'''
replace_once(preview, old_picker, new_picker)
insert_anchor = """Future<void> _showV2CompleteCurrentAction(
"""
student_picker_widget = r'''class _V2StudentPicker extends StatefulWidget {
  const _V2StudentPicker({required this.students});

  final List<V2Student> students;

  @override
  State<_V2StudentPicker> createState() => _V2StudentPickerState();
}

class _V2StudentPickerState extends State<_V2StudentPicker> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<V2Student> get _visibleStudents {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.students;
    return widget.students
        .where((student) {
          final haystack = [
            student.name,
            student.grade,
            ...student.subjects,
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleStudents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('选择学生', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          key: const Key('v2-quick-capture-student-search'),
          controller: _controller,
          autofocus: true,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: '搜索姓名、年级或学科…',
            prefixIcon: const Icon(Icons.search, size: 19),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: '清除搜索',
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close, size: 18),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _query.trim().isEmpty
              ? '全部 ${widget.students.length} 位'
              : '找到 ${visible.length} 位',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    '没有找到匹配的学生',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  itemBuilder: (_, index) {
                    final student = visible[index];
                    return ListTile(
                      title: Text(student.name),
                      subtitle: Text(
                        '${student.grade} · ${student.subjects.join(' / ')}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pop(student),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

'''
replace_once(preview, insert_anchor, student_picker_widget + insert_anchor)

# Compact shell: three true destinations. Overflow actions live in the page header.
replace_once(
    preview,
    """                    onOpenMore: () => _showWorkspaceMenu(context),
                  );
""",
    """                    onOpenMore: hasMenuActions
                        ? () => _showWorkspaceMenu(context)
                        : null,
                  );
""",
)
replace_once(
    preview,
    """  final VoidCallback onBackFromCase;
  final VoidCallback onOpenMore;
""",
    """  final VoidCallback onBackFromCase;
  final VoidCallback? onOpenMore;
""",
)
replace_once(
    preview,
    """        selectedStudent: widget.selectedStudent,
        compact: true,
        onSelected: (student) {
""",
    """        selectedStudent: widget.selectedStudent,
        compact: true,
        onOpenMore: widget.onOpenMore,
        onSelected: (student) {
""",
)
replace_once(
    preview,
    """      body = _TodayPane(onOpenCase: widget.onOpenCase, compact: true);
    } else {
      body = _CaseIndexPane(onOpenCase: widget.onOpenCase, compact: true);
""",
    """      body = _TodayPane(
        onOpenCase: widget.onOpenCase,
        compact: true,
        onOpenMore: widget.onOpenMore,
      );
    } else {
      body = _CaseIndexPane(
        onOpenCase: widget.onOpenCase,
        compact: true,
        onOpenMore: widget.onOpenMore,
      );
""",
)
replace_once(
    preview,
    """              onDestinationSelected: (value) {
                if (value == 3) {
                  widget.onOpenMore();
                  return;
                }
                setState(() => _studentOpen = false);
                widget.onDestinationChanged(value);
              },
""",
    """              onDestinationSelected: (value) {
                setState(() => _studentOpen = false);
                widget.onDestinationChanged(value);
              },
""",
)
replace_once(
    preview,
    """                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: '学情',
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  label: '更多',
                ),
""",
    """                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: '学情',
                ),
""",
)

# Give desktop rail targets the full recommended 48 logical pixels.
replace_once(
    preview,
    """              width: 48,
              height: 44,
""",
    """              width: 48,
              height: 48,
""",
)

# Student list header overflow.
replace_once(
    preview,
    """    required this.onSelected,
    this.compact = false,
  });

  final V2Student selectedStudent;
  final ValueChanged<V2Student> onSelected;
  final bool compact;
""",
    """    required this.onSelected,
    this.compact = false,
    this.onOpenMore,
  });

  final V2Student selectedStudent;
  final ValueChanged<V2Student> onSelected;
  final bool compact;
  final VoidCallback? onOpenMore;
""",
)
replace_once(
    preview,
    """                Text('学生', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 18),
""",
    """                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '学生',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (widget.compact && widget.onOpenMore != null)
                      IconButton(
                        key: const Key('v2-compact-more'),
                        tooltip: '更多操作',
                        onPressed: widget.onOpenMore,
                        icon: const Icon(Icons.more_vert),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
""",
)

# Today deterministic priority: overdue -> today -> undated; future by date.
replace_once(
    preview,
    """class _TodayPane extends StatelessWidget {
  const _TodayPane({required this.onOpenCase, this.compact = false});

  final ValueChanged<V2FocusItem> onOpenCase;
  final bool compact;
""",
    """class _TodayPane extends StatelessWidget {
  const _TodayPane({
    required this.onOpenCase,
    this.compact = false,
    this.onOpenMore,
  });

  final ValueChanged<V2FocusItem> onOpenCase;
  final bool compact;
  final VoidCallback? onOpenMore;

  static int _priority(V2FocusItem item) => switch (item.actionTiming) {
    V2ActionTiming.overdue => 0,
    V2ActionTiming.today => 1,
    V2ActionTiming.undated => 2,
    V2ActionTiming.future => 3,
    null => 4,
  };

  static int _compare(V2FocusItem left, V2FocusItem right) {
    final priority = _priority(left).compareTo(_priority(right));
    if (priority != 0) return priority;
    final leftDue = left.dueOn;
    final rightDue = right.dueOn;
    if (leftDue != null && rightDue != null) {
      final due = leftDue.compareTo(rightDue);
      if (due != 0) return due;
    } else if (leftDue != null) {
      return -1;
    } else if (rightDue != null) {
      return 1;
    }
    return left.title.compareTo(right.title);
  }
""",
)
replace_once(
    preview,
    """        )
        .toList(growable: false);
    final verificationItems = validItems
""",
    """        )
        .toList(growable: true)
      ..sort(_compare);
    final verificationItems = validItems
""",
)
replace_once(
    preview,
    """        )
        .toList(growable: false);
    final futureItems = validItems
""",
    """        )
        .toList(growable: true)
      ..sort(_compare);
    final futureItems = validItems
""",
)
replace_once(
    preview,
    """    final futureItems = validItems
        .where((item) => item.actionTiming == V2ActionTiming.future)
        .toList(growable: false);
""",
    """    final futureItems = validItems
        .where((item) => item.actionTiming == V2ActionTiming.future)
        .toList(growable: true)
      ..sort(_compare);
""",
)
replace_once(
    preview,
    """                  FilledButton.tonalIcon(
                    key: const Key('v2-today-quick-capture'),
                    onPressed: () => _showV2QuickCaptureStudentPicker(context),
                    icon: const Icon(Icons.note_add_outlined, size: 18),
                    label: const Text('记录问题'),
                  ),
""",
    """                  FilledButton.tonalIcon(
                    key: const Key('v2-today-quick-capture'),
                    onPressed: () => _showV2QuickCaptureStudentPicker(context),
                    icon: const Icon(Icons.note_add_outlined, size: 18),
                    label: const Text('记录问题'),
                  ),
                  if (compact && onOpenMore != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      key: const Key('v2-compact-more'),
                      tooltip: '更多操作',
                      onPressed: onOpenMore,
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
""",
)
replace_once(
    preview,
    """            Text(
              verification ? '待验证' : item.dueLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
""",
    """            Text(
              _todayActionStatus(item, verification: verification),
              style: Theme.of(context).textTheme.bodySmall,
            ),
""",
)
replace_once(
    preview,
    """class _CaseIndexPane extends StatefulWidget {
""",
    """String _todayActionStatus(V2FocusItem item, {required bool verification}) {
  if (verification) {
    return item.actionTiming == V2ActionTiming.overdue ? '待验证 · 已逾期' : '待验证';
  }
  if (item.actionTiming == V2ActionTiming.overdue) {
    return item.dueLabel == '待安排' ? '已逾期' : '逾期 · ${item.dueLabel}';
  }
  return item.dueLabel;
}

class _CaseIndexPane extends StatefulWidget {
""",
)

# Case index header overflow.
replace_once(
    preview,
    """class _CaseIndexPane extends StatefulWidget {
  const _CaseIndexPane({required this.onOpenCase, this.compact = false});

  final ValueChanged<V2FocusItem> onOpenCase;
  final bool compact;
""",
    """class _CaseIndexPane extends StatefulWidget {
  const _CaseIndexPane({
    required this.onOpenCase,
    this.compact = false,
    this.onOpenMore,
  });

  final ValueChanged<V2FocusItem> onOpenCase;
  final bool compact;
  final VoidCallback? onOpenMore;
""",
)
replace_once(
    preview,
    """              Text('学情', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 5),
""",
    """              Row(
                children: [
                  Expanded(
                    child: Text(
                      '学情',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (widget.compact && widget.onOpenMore != null)
                    IconButton(
                      key: const Key('v2-compact-more'),
                      tooltip: '更多操作',
                      onPressed: widget.onOpenMore,
                      icon: const Icon(Icons.more_vert),
                    ),
                ],
              ),
              const SizedBox(height: 5),
""",
)

# Source-level release contract updated for the new membership gate and compact nav.
source_test = "test/features/v2_shell_production_capabilities_test.dart"
replace_once(
    source_test,
    """    expect(preview, contains(\"label: '更多'\"));
""",
    """    expect(preview, isNot(contains(\"label: '更多'\")));
    expect(preview, contains(\"Key('v2-compact-more')\"));
""",
)
replace_once(
    source_test,
    """    expect(loader, contains('workspace.canManageOrganization'));
""",
    """    expect(loader, contains('workspace.canManageOrganization'));
    expect(teacherWorkspace, contains(\"membershipState?.status == 'none'\"));
    expect(teacherWorkspace, contains('OrganizationInvitationJoinPage('));
""",
)

# Focused behavioral tests for the standalone membership gate.
join_test = Path("test/features/organization_invitation_join_page_test.dart")
join_test.write_text(
    r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/cloud/organization_management_repository.dart';
import 'package:xueqing/features/organization_management/presentation/'
    'organization_invitation_join_page.dart';

class _FakeInvitationAcceptanceRepository
    implements OrganizationInvitationAcceptanceRepository {
  String? inviteCode;
  String? displayName;
  Object? error;

  @override
  Future<void> acceptInvitation({
    required String inviteCode,
    String? displayName,
  }) async {
    this.inviteCode = inviteCode;
    this.displayName = displayName;
    final nextError = error;
    if (nextError != null) throw nextError;
  }
}

void main() {
  testWidgets('no-membership account can accept an invite and refresh membership', (
    tester,
  ) async {
    final repository = _FakeInvitationAcceptanceRepository();
    var joined = 0;
    var signedOut = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: OrganizationInvitationJoinPage(
          repository: repository,
          email: 'teacher@example.com',
          onJoined: () async => joined++,
          onSignOut: () => signedOut++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('加入机构'), findsOneWidget);
    expect(find.textContaining('teacher@example.com'), findsOneWidget);
    expect(find.byKey(const Key('invitation-accept-code')), findsOneWidget);
    expect(find.byKey(const Key('invitation-join-sign-out')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('invitation-accept-code')),
      '0123456789abcdef01234567',
    );
    await tester.enterText(
      find.byKey(const Key('invitation-accept-display-name')),
      '王老师',
    );
    await tester.tap(find.text('接受邀请'));
    await tester.pumpAndSettle();

    expect(repository.inviteCode, '0123456789abcdef01234567');
    expect(repository.displayName, '王老师');
    expect(joined, 1);

    await tester.tap(find.byKey(const Key('invitation-join-sign-out')));
    expect(signedOut, 1);
  });

  testWidgets('invite failure stays actionable and explains email mismatch', (
    tester,
  ) async {
    final repository = _FakeInvitationAcceptanceRepository()
      ..error = const AuthException('invitation_email_mismatch');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: OrganizationInvitationJoinPage(
          repository: repository,
          email: 'wrong@example.com',
          onJoined: () async {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('invitation-accept-code')),
      '0123456789abcdef01234567',
    );
    await tester.tap(find.text('接受邀请'));
    await tester.pumpAndSettle();

    expect(find.textContaining('接受邀请失败'), findsOneWidget);
    expect(find.byKey(const Key('invitation-accept-code')), findsOneWidget);
    expect(find.byKey(const Key('invitation-join-sign-out')), findsOneWidget);
  });
}
'''
)

# Focused V2 ergonomics tests: priority, searchable picker, 3-destination mobile nav.
ergonomics_test = Path("test/features/v2_final_ergonomics_test.dart")
ergonomics_test.write_text(
    r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_fixture.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_data.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

const _students = <V2Student>[
  V2Student(
    id: 's1',
    name: '林同学',
    grade: '初三',
    subjects: ['语文'],
    openCaseCount: 3,
    updatedLabel: '今天',
    teacherSummary: '',
  ),
  V2Student(
    id: 's2',
    name: '王同学',
    grade: '初二',
    subjects: ['英语'],
    openCaseCount: 1,
    updatedLabel: '今天',
    teacherSummary: '',
  ),
];

V2FocusItem _item(
  String id,
  String title,
  V2ActionTiming timing, {
  DateTime? dueOn,
  String dueLabel = '待安排',
}) => V2FocusItem(
  id: id,
  studentId: 's1',
  title: title,
  summary: '测试摘要',
  nextStep: '下一步',
  dueLabel: dueLabel,
  subject: '语文',
  actionTiming: timing,
  dueOn: dueOn,
);

Widget _app(V2WorkspaceData data, {VoidCallback? onSignOut}) => MaterialApp(
  theme: V2Theme.light(),
  home: V2WorkspacePreview(data: data, onSignOut: onSignOut),
);

void main() {
  testWidgets('Today orders overdue before today before undated', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final data = V2WorkspaceData(
      students: _students,
      focusItems: <V2FocusItem>[
        _item('undated', '待安排问题', V2ActionTiming.undated),
        _item(
          'today',
          '今天问题',
          V2ActionTiming.today,
          dueOn: DateTime(2026, 9, 10),
          dueLabel: '9 月 10 日',
        ),
        _item(
          'overdue',
          '逾期问题',
          V2ActionTiming.overdue,
          dueOn: DateTime(2026, 9, 8),
          dueLabel: '9 月 8 日',
        ),
      ],
      timeline: const [],
      businessDate: DateTime(2026, 9, 10),
    );

    await tester.pumpWidget(_app(data));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('今日'));
    await tester.pumpAndSettle();

    final overdueY = tester.getTopLeft(find.text('逾期问题')).dy;
    final todayY = tester.getTopLeft(find.text('今天问题')).dy;
    final undatedY = tester.getTopLeft(find.text('待安排问题')).dy;
    expect(overdueY, lessThan(todayY));
    expect(todayY, lessThan(undatedY));
    expect(find.text('逾期 · 9 月 8 日'), findsOneWidget);
  });

  testWidgets('quick capture student picker searches name grade and subject', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const data = V2WorkspaceData(
      students: _students,
      focusItems: [],
      timeline: [],
    );

    await tester.pumpWidget(_app(data));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今日'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-today-quick-capture')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('v2-quick-capture-student-search')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('v2-quick-capture-student-search')),
      '初二',
    );
    await tester.pump();

    expect(find.text('找到 1 位'), findsOneWidget);
    expect(find.text('王同学'), findsOneWidget);
    expect(find.text('林同学'), findsNothing);
  });

  testWidgets('compact shell keeps three primary destinations and moves More to header', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const data = V2WorkspaceData(
      students: _students,
      focusItems: [],
      timeline: [],
    );

    await tester.pumpWidget(_app(data, onSignOut: () {}));
    await tester.pumpAndSettle();

    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.destinations.length, 3);
    expect(find.text('更多'), findsNothing);
    expect(find.byKey(const Key('v2-compact-more')), findsOneWidget);

    await tester.tap(find.byKey(const Key('v2-compact-more')));
    await tester.pumpAndSettle();
    expect(find.text('退出登录'), findsOneWidget);
  });
}
'''
)

print("V2 final ergonomics patch applied")
