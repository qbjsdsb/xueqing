import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/layout/responsive.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../cloud/auth_repository.dart';
import '../../../cloud/cloud_client.dart';
import '../../../cloud/learning_repository.dart';
import '../../../config/app_config.dart';

class TeacherWorkspaceEntryPage extends StatefulWidget {
  const TeacherWorkspaceEntryPage({
    required this.config,
    this.authRepository,
    this.learningRepository,
    super.key,
  });

  final AppConfig config;
  final AuthRepository? authRepository;
  final LearningRepository? learningRepository;

  @override
  State<TeacherWorkspaceEntryPage> createState() =>
      _TeacherWorkspaceEntryPageState();
}

class _TeacherWorkspaceEntryPageState extends State<TeacherWorkspaceEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late Future<void> _initialization;
  StreamSubscription<AuthState>? _authSubscription;
  AuthRepository? _authRepository;
  LearningRepository? _learningRepository;
  String? _errorMessage;
  bool _signedIn = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final hasAuthRepository = widget.authRepository != null;
    final hasLearningRepository = widget.learningRepository != null;
    if (hasAuthRepository != hasLearningRepository) {
      throw ArgumentError(
        'authRepository and learningRepository must be supplied together.',
      );
    }

    if (hasAuthRepository && hasLearningRepository) {
      _authRepository = widget.authRepository;
      _learningRepository = widget.learningRepository;
    } else {
      widget.config.cloudConfig.validate();
      if (!widget.config.cloudConfig.isConfigured) {
        return;
      }
      await CloudClient.initialize(widget.config.cloudConfig);
      _authRepository = SupabaseAuthRepository(CloudClient.client);
      _learningRepository = SupabaseLearningRepository(CloudClient.client);
    }

    _signedIn = _authRepository!.currentUser != null;
    _authSubscription = _authRepository!.authStateChanges.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _signedIn = state.session != null;
        if (_signedIn) {
          _errorMessage = null;
        }
      });
    });
  }

  void _retryInitialization() {
    setState(() {
      _initialization = _initialize();
    });
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate() || _authRepository == null) {
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await _authRepository!.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (_authRepository!.currentUser == null) {
        throw const AuthException('Authentication did not return a user.');
      }
      if (mounted) {
        setState(() {
          _signedIn = true;
        });
      }
      _passwordController.clear();
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _describeAuthError(error, action: '登录');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    final authRepository = _authRepository;
    if (authRepository == null || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await authRepository.signOut();
      if (authRepository.currentUser != null) {
        await authRepository.signOut(global: false);
      }
      if (mounted) {
        setState(() {
          _signedIn = authRepository.currentUser != null;
          if (!_signedIn) {
            _emailController.clear();
            _passwordController.clear();
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _signedIn = authRepository.currentUser != null;
          _errorMessage = _describeAuthError(error, action: '退出登录');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _describeAuthError(Object error, {required String action}) {
    if (error is AuthException) {
      final detail = error.message.trim();
      if (detail.toLowerCase() == 'invalid login credentials') {
        return '$action失败：账号或密码不正确。';
      }
      if (detail.isEmpty) {
        return '$action失败，请检查网络后重试。';
      }
      return '$action失败：$detail';
    }
    return '$action失败，请检查网络后重试。';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _WorkspaceStatusScaffold(
            title: '教师工作台',
            child: _WorkspaceLoadingBody(message: '正在准备教师工作台…'),
          );
        }
        if (snapshot.hasError) {
          return _WorkspaceStatusScaffold(
            title: '教师工作台',
            child: _WorkspaceErrorBody(
              message: '工作台初始化失败，请检查开发环境配置后重试。',
              onRetry: _retryInitialization,
            ),
          );
        }
        if (_authRepository == null || _learningRepository == null) {
          return const _WorkspaceStatusScaffold(
            title: '教师工作台',
            child: _WorkspaceConfigBody(),
          );
        }
        if (!_signedIn) {
          return _WorkspaceLoginBody(
            formKey: _formKey,
            emailController: _emailController,
            passwordController: _passwordController,
            busy: _busy,
            errorMessage: _errorMessage,
            onSubmit: _signIn,
          );
        }
        return TeacherWorkspacePage(
          repository: _learningRepository!,
          onSignOut: _busy ? null : _signOut,
        );
      },
    );
  }
}

class TeacherWorkspacePage extends StatefulWidget {
  const TeacherWorkspacePage({
    required this.repository,
    this.onSignOut,
    super.key,
  });

  final LearningRepository repository;
  final VoidCallback? onSignOut;

  @override
  State<TeacherWorkspacePage> createState() => _TeacherWorkspacePageState();
}

class _TeacherWorkspacePageState extends State<TeacherWorkspacePage> {
  final _studentSearchController = TextEditingController();
  int _selectedIndex = 0;
  WorkspaceStudent? _selectedStudent;
  WorkspaceCase? _selectedCase;
  late Future<TeacherWorkspace> _workspaceFuture;

  @override
  void initState() {
    super.initState();
    _workspaceFuture = widget.repository.loadWorkspace();
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    super.dispose();
  }

  void _selectDestination(int index) {
    setState(() {
      _selectedIndex = index;
      _selectedStudent = null;
      _selectedCase = null;
    });
  }

  void _openStudent(WorkspaceStudent student) {
    setState(() {
      _selectedStudent = student;
      _selectedCase = null;
    });
  }

  void _openCase(WorkspaceStudent student, WorkspaceCase learningCase) {
    setState(() {
      _selectedStudent = student;
      _selectedCase = learningCase;
    });
  }

  void _goBack() {
    if (_selectedCase != null) {
      setState(() => _selectedCase = null);
      return;
    }
    if (_selectedStudent != null) {
      setState(() => _selectedStudent = null);
    }
  }

  Future<void> _reload({
    WorkspaceStudent? preserveStudent,
    String? preserveCaseId,
  }) async {
    final nextFuture = widget.repository.loadWorkspace();
    setState(() {
      _workspaceFuture = nextFuture;
    });
    try {
      final workspace = await nextFuture;
      if (!mounted || preserveStudent == null) {
        return;
      }
      WorkspaceStudent? matchingStudent;
      for (final student in workspace.students) {
        if (student.profileId == preserveStudent.profileId) {
          matchingStudent = student;
          break;
        }
      }
      if (matchingStudent != null) {
        WorkspaceCase? matchingCase;
        if (preserveCaseId != null) {
          for (final learningCase in matchingStudent.cases) {
            if (learningCase.id == preserveCaseId) {
              matchingCase = learningCase;
              break;
            }
          }
        }
        setState(() {
          _selectedStudent = matchingStudent;
          if (preserveCaseId != null) {
            _selectedCase = matchingCase;
          }
        });
      }
    } catch (_) {
      // FutureBuilder renders the retained error state. The input form has
      // already closed only after the command committed successfully.
    }
  }

  Future<void> _showQuickCapture({WorkspaceStudent? student}) async {
    final workspace = await _workspaceFuture;
    if (!mounted) {
      return;
    }
    final sizeClass = ResponsiveBreakpoints.classify(
      MediaQuery.sizeOf(context).width,
    );
    final result = sizeClass == WindowSizeClass.compact
        ? await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            isDismissible: false,
            enableDrag: false,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            clipBehavior: Clip.antiAlias,
            builder: (context) => _WorkspaceQuickCaptureForm(
              students: workspace.students,
              caseTypes: workspace.caseTypes,
              initialStudent: student,
              repository: widget.repository,
            ),
          )
        : await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              child: _WorkspaceQuickCaptureForm(
                students: workspace.students,
                caseTypes: workspace.caseTypes,
                initialStudent: student,
                repository: widget.repository,
              ),
            ),
          );

    if (!mounted || result != true) {
      return;
    }
    await _reload(preserveStudent: student);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已保存为待整理 Case，并保留下一步行动。')));
  }

  Future<void> _showCaseTypeManager() async {
    final workspace = await _workspaceFuture;
    final organizationId = workspace.organizationId;
    if (!mounted || !workspace.canManageCaseTypes || organizationId == null) {
      return;
    }
    final sizeClass = ResponsiveBreakpoints.classify(
      MediaQuery.sizeOf(context).width,
    );
    final manager = _WorkspaceCaseTypeManager(
      organizationId: organizationId,
      caseTypes: workspace.caseTypes,
      repository: widget.repository,
      onChanged: () => _reload(),
    );
    if (sizeClass == WindowSizeClass.compact) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        builder: (_) => manager,
      );
    } else {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(child: manager),
      );
    }
  }

  Future<CaseCommandReceipt?> _showCaseForm({
    required _CaseCommandMode mode,
    required WorkspaceCase learningCase,
  }) {
    final sizeClass = ResponsiveBreakpoints.classify(
      MediaQuery.sizeOf(context).width,
    );
    final form = _WorkspaceCaseCommandForm(
      mode: mode,
      learningCase: learningCase,
      repository: widget.repository,
    );
    return sizeClass == WindowSizeClass.compact
        ? showModalBottomSheet<CaseCommandReceipt>(
            context: context,
            isScrollControlled: true,
            isDismissible: false,
            enableDrag: false,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            clipBehavior: Clip.antiAlias,
            builder: (_) => form,
          )
        : showDialog<CaseCommandReceipt>(
            context: context,
            barrierDismissible: false,
            builder: (_) => Dialog(child: form),
          );
  }

  Future<void> _showCaseCommand(
    WorkspaceStudent student,
    WorkspaceCase learningCase,
  ) async {
    final mode = _caseCommandMode(learningCase);
    if (mode == null) {
      return;
    }
    final result = await _showCaseForm(mode: mode, learningCase: learningCase);
    if (!mounted || result == null) {
      return;
    }
    await _reload(preserveStudent: student, preserveCaseId: learningCase.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已保存，Case 进入${_caseStatusLabelFromWire(result.status)}。'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherWorkspace>(
      future: _workspaceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _WorkspaceStatusScaffold(
            title: '教师工作台',
            child: _WorkspaceLoadingBody(message: '正在加载学生和今日事项…'),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _WorkspaceStatusScaffold(
            title: '教师工作台',
            child: _WorkspaceErrorBody(
              message: '学生和今日事项暂时加载失败。可以重试，已有输入不会被删除。',
              onRetry: () => _reload(),
            ),
          );
        }

        final workspace = snapshot.data!;
        if (!workspace.hasTeachingAccess) {
          if (workspace.canManageCaseTypes &&
              workspace.organizationId != null) {
            return _WorkspaceStatusScaffold(
              title: '机构问题类型',
              child: _WorkspaceCaseTypeManager(
                organizationId: workspace.organizationId!,
                caseTypes: workspace.caseTypes,
                repository: widget.repository,
                onChanged: () => _reload(),
                showCloseButton: false,
              ),
            );
          }
          return const _WorkspaceStatusScaffold(
            title: '教师工作台',
            child: _WorkspaceNoAccessBody(),
          );
        }

        return PopScope<void>(
          canPop: _selectedStudent == null && _selectedCase == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _goBack();
            }
          },
          child: _WorkspaceShell(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectDestination,
            onSignOut: widget.onSignOut,
            child: ResponsiveLayout(
              builder: (context, sizeClass) => _WorkspaceFrame(
                sizeClass: sizeClass,
                child: _buildCurrentPage(workspace, sizeClass),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentPage(
    TeacherWorkspace workspace,
    WindowSizeClass sizeClass,
  ) {
    if (_selectedCase != null && _selectedStudent != null) {
      return _buildCaseDetail(_selectedStudent!, _selectedCase!);
    }
    if (_selectedStudent != null) {
      return _buildStudentDetail(_selectedStudent!, sizeClass);
    }
    return _selectedIndex == 0
        ? _buildToday(workspace)
        : _buildStudents(workspace);
  }

  Widget _buildToday(TeacherWorkspace workspace) {
    final actions = <WorkspaceActionWithContext>[];
    final pendingVerification = <WorkspaceCaseWithContext>[];
    for (final student in workspace.students) {
      for (final learningCase in student.cases) {
        if (learningCase.status == LearningCaseStatus.pendingVerification) {
          pendingVerification.add(
            WorkspaceCaseWithContext(
              student: student,
              learningCase: learningCase,
            ),
          );
          continue;
        }
        final action = learningCase.primaryAction;
        if (action == null ||
            learningCase.status == LearningCaseStatus.closed) {
          continue;
        }
        actions.add(
          WorkspaceActionWithContext(
            student: student,
            learningCase: learningCase,
            action: action,
          ),
        );
      }
    }

    final overdue = _actionsInBucket(actions, WorkspaceActionBucket.overdue);
    final today = _actionsInBucket(actions, WorkspaceActionBucket.today);
    final future = _actionsInBucket(actions, WorkspaceActionBucket.future);
    final undated = _actionsInBucket(actions, WorkspaceActionBucket.undated);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WorkspaceBoundaryBanner(),
        const SizedBox(height: AppSpacing.lg),
        _WorkspacePageHeader(
          title: '今日',
          subtitle: '先处理今天要做的事，再回看需要判断的学生。',
          actions: [
            if (workspace.canManageCaseTypes &&
                workspace.organizationId != null)
              OutlinedButton.icon(
                onPressed: _showCaseTypeManager,
                icon: const Icon(Icons.category_outlined),
                label: const Text('问题类型'),
              ),
            OutlinedButton.icon(
              onPressed: () => _showQuickCapture(),
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('记录问题'),
            ),
          ],
        ),
        if (overdue.isEmpty && today.isEmpty)
          const _WorkspaceStateNotice(
            title: '今天没有已安排的行动',
            message: '可以回看最近学生，或在课堂中先记录一句问题。',
            icon: Icons.check_circle_outline,
          )
        else
          _WorkspaceSection(
            key: const Key('workspace-today-work-section'),
            title: '今天的工作',
            count: '${overdue.length + today.length} 项',
            child: Column(
              children: [
                if (overdue.isNotEmpty) ...[
                  const _WorkspaceSubheading(
                    label: '已逾期',
                    color: AppColors.danger,
                    icon: Icons.warning_amber_outlined,
                  ),
                  ..._buildActionRows(overdue),
                ],
                if (today.isNotEmpty) ...[
                  if (overdue.isNotEmpty) const Divider(height: AppSpacing.lg),
                  const _WorkspaceSubheading(
                    label: '今天到期',
                    color: AppColors.warning,
                    icon: Icons.today_outlined,
                  ),
                  ..._buildActionRows(today),
                ],
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        _WorkspaceSection(
          key: const Key('workspace-pending-verification-section'),
          title: '待验证',
          count: '${pendingVerification.length} 个 Case',
          showTopDivider: true,
          child: pendingVerification.isEmpty
              ? const _WorkspaceStateNotice(
                  title: '还没有待验证事项',
                  message: '完成一次检查后，在这里确认是否稳定。',
                  icon: Icons.fact_check_outlined,
                )
              : Column(
                  children: [
                    for (final item in pendingVerification)
                      _WorkspaceCaseRow(
                        student: item.student,
                        learningCase: item.learningCase,
                        onOpen: () =>
                            _openCase(item.student, item.learningCase),
                      ),
                  ],
                ),
        ),
        if (future.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _WorkspaceSection(
            key: const Key('workspace-future-actions-section'),
            title: '未来',
            count: '${future.length} 项',
            showTopDivider: true,
            child: Column(children: _buildActionRows(future)),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _WorkspaceSection(
          key: const Key('workspace-undated-actions-section'),
          title: '待安排',
          count: '${undated.length} 项',
          showTopDivider: true,
          child: undated.isEmpty
              ? const _WorkspaceStateNotice(
                  title: '没有待安排的行动',
                  message: '需要跟进但尚未设定日期的行动会一直保留在这里。',
                  icon: Icons.event_available_outlined,
                )
              : Column(children: _buildActionRows(undated)),
        ),
        const SizedBox(height: AppSpacing.lg),
        _WorkspaceSection(
          title: '最近学生',
          showTopDivider: true,
          action: TextButton(
            onPressed: () => _selectDestination(1),
            child: const Text('查看全部'),
          ),
          child: Column(
            children: [
              for (final student in workspace.students.take(5))
                _WorkspaceStudentRow(
                  student: student,
                  onOpen: () => _openStudent(student),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<WorkspaceActionWithContext> _actionsInBucket(
    Iterable<WorkspaceActionWithContext> actions,
    WorkspaceActionBucket bucket,
  ) {
    return actions.where((item) => item.action.bucket == bucket).toList();
  }

  List<Widget> _buildActionRows(List<WorkspaceActionWithContext> items) {
    final grouped = <String, List<WorkspaceActionWithContext>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.student.profileId, () => []).add(item);
    }
    return [
      for (final group in grouped.values)
        _WorkspaceActionGroup(
          student: group.first.student,
          items: group,
          onOpenCase: (learningCase) =>
              _openCase(group.first.student, learningCase),
        ),
    ];
  }

  Widget _buildStudents(TeacherWorkspace workspace) {
    return AnimatedBuilder(
      animation: _studentSearchController,
      builder: (context, _) {
        final query = _studentSearchController.text.trim();
        final students = workspace.students.where((student) {
          if (query.isEmpty) {
            return true;
          }
          final caseText = student.cases
              .map(
                (learningCase) =>
                    '${learningCase.title}${learningCase.description ?? ''}',
              )
              .join();
          return '${student.name}${student.subject}${student.context}$caseText'
              .contains(query);
        }).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _WorkspaceBoundaryBanner(),
            const SizedBox(height: AppSpacing.lg),
            _WorkspacePageHeader(
              title: '学生',
              subtitle: '搜索学生，先理解当前重点，再进入需要处理的 Case。',
              actions: [
                if (workspace.canManageCaseTypes &&
                    workspace.organizationId != null)
                  OutlinedButton.icon(
                    onPressed: _showCaseTypeManager,
                    icon: const Icon(Icons.category_outlined),
                    label: const Text('问题类型'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _showQuickCapture(),
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('记录问题'),
                ),
              ],
            ),
            TextField(
              controller: _studentSearchController,
              decoration: const InputDecoration(
                labelText: '搜索学生或学情',
                hintText: '输入姓名、学科或问题关键词',
                prefixIcon: Icon(Icons.search),
              ),
              textInputAction: TextInputAction.search,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (students.isEmpty)
              const _WorkspaceStateNotice(
                title: '没有找到匹配的学生',
                message: '换一个姓名、学科或问题关键词试试。',
                icon: Icons.search_off_outlined,
              )
            else
              _WorkspaceSection(
                title: '可访问的学生',
                count: '${students.length} 人',
                child: Column(
                  children: [
                    for (final student in students)
                      _WorkspaceStudentRow(
                        student: student,
                        onOpen: () => _openStudent(student),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStudentDetail(
    WorkspaceStudent student,
    WindowSizeClass sizeClass,
  ) {
    final importantCases = student.cases
        .where(
          (learningCase) => learningCase.status != LearningCaseStatus.closed,
        )
        .take(3)
        .toList();
    final pendingCases = student.cases
        .where(
          (learningCase) =>
              learningCase.status == LearningCaseStatus.pendingVerification,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorkspacePageHeader(
          title: student.name,
          subtitle:
              '${student.grade} · ${student.subject} · ${student.context}',
          leading: IconButton(
            tooltip: '返回',
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () => _showQuickCapture(student: student),
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('记录问题'),
            ),
          ],
        ),
        _WorkspaceStateNotice(
          title: '学科上下文',
          message: student.positioning == null
              ? '当前显示 ${student.subject} 的最小学科上下文。'
              : student.positioning!,
          icon: Icons.menu_book_outlined,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (importantCases.isEmpty)
          const _WorkspaceStateNotice(
            title: '还没有 Learning Case',
            message: '发现问题时，可以先记录一句，课后再整理。',
            icon: Icons.inbox_outlined,
          )
        else
          _WorkspaceSection(
            title: '现在最重要的事',
            count: '${importantCases.length} 项',
            child: Column(
              children: [
                for (final learningCase in importantCases)
                  _WorkspaceCaseRow(
                    student: student,
                    learningCase: learningCase,
                    onOpen: () => _openCase(student, learningCase),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        _WorkspaceSection(
          title: '当前 Learning Cases',
          count: '${student.cases.length} 个',
          showTopDivider: true,
          child: student.cases.isEmpty
              ? const _WorkspaceStateNotice(
                  title: '还没有当前 Case',
                  message: '问题出现时可以从这里开始记录。',
                  icon: Icons.inbox_outlined,
                )
              : Column(
                  children: [
                    for (final learningCase in student.cases)
                      _WorkspaceCaseRow(
                        student: student,
                        learningCase: learningCase,
                        onOpen: () => _openCase(student, learningCase),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _WorkspaceSection(
          title: '待验证',
          count: '${pendingCases.length} 个',
          showTopDivider: true,
          child: pendingCases.isEmpty
              ? const _WorkspaceStateNotice(
                  title: '目前没有待验证 Case',
                  message: '完成一次检查后，回到这里确认是否稳定。',
                  icon: Icons.fact_check_outlined,
                )
              : Column(
                  children: [
                    for (final learningCase in pendingCases)
                      _WorkspaceCaseRow(
                        student: student,
                        learningCase: learningCase,
                        onOpen: () => _openCase(student, learningCase),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _WorkspaceFacts(student: student, sizeClass: sizeClass),
      ],
    );
  }

  Widget _buildCaseDetail(
    WorkspaceStudent student,
    WorkspaceCase learningCase,
  ) {
    final primaryAction = learningCase.primaryAction;
    final commandLabel = _caseCommandLabel(learningCase);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorkspacePageHeader(
          title: learningCase.title,
          subtitle: '${student.name} · ${student.subject}',
          leading: IconButton(
            tooltip: '返回学生详情',
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [_WorkspaceStatusMarker(label: learningCase.status.label)],
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _WorkspaceMetadata(learningCase.typeLabel),
            _WorkspaceMetadata(_priorityLabel(learningCase.priority)),
            if (primaryAction != null)
              _WorkspaceMetadata(
                '下一步：${primaryAction.title}',
                icon: Icons.arrow_forward_outlined,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (learningCase.status == LearningCaseStatus.pendingVerification)
          const _WorkspaceStateNotice(
            title: '本次验证通过，仍待确认是否稳定',
            message: 'Assessment passed 不是 stable。请保留这次检查记录，再由教师确认是否稳定。',
            icon: Icons.fact_check_outlined,
          )
        else if (learningCase.status == LearningCaseStatus.stable)
          const _WorkspaceStateNotice(
            title: '稳定；仍需安排下一次检查',
            message: '稳定不等于已关闭，当前仍需保留 review / verify action。',
            icon: Icons.check_circle_outline,
          )
        else if (learningCase.status == LearningCaseStatus.newCase)
          const _WorkspaceStateNotice(
            title: '待整理 Case',
            message: 'Quick Capture 已保存原始问题和证据；确认前请补充判断和合适的下一步。',
            icon: Icons.edit_note_outlined,
          ),
        if (commandLabel != null) ...[
          const SizedBox(height: AppSpacing.md),
          _WorkspaceCaseCommandSection(
            title: commandLabel,
            message: _caseCommandHint(learningCase),
            buttonLabel: commandLabel,
            onPressed: () => _showCaseCommand(student, learningCase),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _WorkspaceNarrativeSection(
          title: '问题',
          content: learningCase.description ?? '尚未补充问题说明。',
        ),
        _WorkspaceNarrativeSection(
          title: 'Evidence / 证据',
          content: learningCase.evidence.isEmpty
              ? '尚未记录 Evidence。'
              : learningCase.evidence
                    .map(
                      (item) =>
                          '${_formatDate(item.observedAt)} ${item.title}：${item.summary}',
                    )
                    .join('\n\n'),
        ),
        _WorkspaceNarrativeSection(
          title: 'Intervention / 教学动作',
          content: learningCase.interventions.isEmpty
              ? '尚未记录教学动作。'
              : learningCase.interventions
                    .map(
                      (item) =>
                          '${_formatDate(item.occurredAt)}：${item.strategy}',
                    )
                    .join('\n\n'),
        ),
        _WorkspaceNarrativeSection(
          title: 'Assessment / Verification',
          content: learningCase.assessments.isEmpty
              ? '尚未记录验证。'
              : learningCase.assessments
                    .map(
                      (item) =>
                          '${_formatDate(item.assessedAt)} ${_assessmentLabel(item.result)}：${item.evidenceSummary}',
                    )
                    .join('\n\n'),
        ),
        _WorkspaceNarrativeSection(
          title: 'Next Action / 下一行动',
          content: primaryAction == null
              ? '当前没有待完成的主要行动。'
              : '${primaryAction.title}（${_formatActionDate(primaryAction)}）',
          isPrimary: true,
        ),
        _WorkspaceSection(
          title: '历史 timeline',
          showTopDivider: true,
          child: learningCase.timeline.isEmpty
              ? const _WorkspaceStateNotice(
                  title: '暂时没有更多历史',
                  message: '新的 Evidence、教学动作和验证会按时间追加在这里。',
                  icon: Icons.history_outlined,
                )
              : Column(
                  children: [
                    for (final event in learningCase.timeline)
                      _WorkspaceTimelineItem(event: event),
                  ],
                ),
        ),
      ],
    );
  }
}

enum _CaseCommandMode { confirm, intervention, assessment }

class _WorkspaceCaseCommandForm extends StatefulWidget {
  const _WorkspaceCaseCommandForm({
    required this.mode,
    required this.learningCase,
    required this.repository,
  });

  final _CaseCommandMode mode;
  final WorkspaceCase learningCase;
  final LearningRepository repository;

  @override
  State<_WorkspaceCaseCommandForm> createState() =>
      _WorkspaceCaseCommandFormState();
}

class _WorkspaceCaseCommandFormState extends State<_WorkspaceCaseCommandForm> {
  late final TextEditingController _strategyController;
  late final TextEditingController _evidenceController;
  late final TextEditingController _notesController;
  late final TextEditingController _nextActionController;
  late final String _operationId;

  CaseAssessmentResult _assessmentResult = CaseAssessmentResult.partial;
  DateTime? _nextActionDueAt;
  String? _strategyError;
  String? _evidenceError;
  String? _nextActionError;
  String? _saveError;
  bool _saving = false;

  String get _defaultNextActionTitle => switch (widget.mode) {
    _CaseCommandMode.confirm => '安排一次针对性练习',
    _CaseCommandMode.intervention => '安排一次检查',
    _CaseCommandMode.assessment => '安排下一次验证',
  };

  String get _title => switch (widget.mode) {
    _CaseCommandMode.confirm => '确认 Case',
    _CaseCommandMode.intervention => '记录教学动作',
    _CaseCommandMode.assessment => '记录验证结果',
  };

  String get _subtitle => switch (widget.mode) {
    _CaseCommandMode.confirm => '把原始观察转成一个可执行的学习问题，并安排下一步。',
    _CaseCommandMode.intervention => '记录这次实际做了什么；保存后系统会生成 verify action。',
    _CaseCommandMode.assessment => '记录本次检查看到的结果；不要用结果直接替代后续教师判断。',
  };

  bool get _isDirty =>
      _strategyController.text.trim().isNotEmpty ||
      _evidenceController.text.trim().isNotEmpty ||
      _notesController.text.trim().isNotEmpty ||
      _nextActionController.text.trim() != _defaultNextActionTitle ||
      _nextActionDueAt != null ||
      _assessmentResult != CaseAssessmentResult.partial;

  @override
  void initState() {
    super.initState();
    _operationId = createOperationId();
    _strategyController = TextEditingController();
    _evidenceController = TextEditingController();
    _notesController = TextEditingController();
    _nextActionController = TextEditingController(
      text: _defaultNextActionTitle,
    );
    _strategyController.addListener(_clearInlineErrors);
    _evidenceController.addListener(_clearInlineErrors);
    _nextActionController.addListener(_clearInlineErrors);
  }

  @override
  void dispose() {
    _strategyController
      ..removeListener(_clearInlineErrors)
      ..dispose();
    _evidenceController
      ..removeListener(_clearInlineErrors)
      ..dispose();
    _notesController.dispose();
    _nextActionController
      ..removeListener(_clearInlineErrors)
      ..dispose();
    super.dispose();
  }

  void _clearInlineErrors() {
    if (!mounted) {
      return;
    }
    final clearStrategy =
        _strategyError != null && _strategyController.text.trim().isNotEmpty;
    final clearEvidence =
        _evidenceError != null && _evidenceController.text.trim().isNotEmpty;
    final clearNextAction =
        _nextActionError != null &&
        _nextActionController.text.trim().isNotEmpty;
    if (clearStrategy || clearEvidence || clearNextAction) {
      setState(() {
        if (clearStrategy) {
          _strategyError = null;
        }
        if (clearEvidence) {
          _evidenceError = null;
        }
        if (clearNextAction) {
          _nextActionError = null;
        }
      });
    }
  }

  Future<void> _pickDueDate() async {
    final today = DateTime.now();
    final current = _nextActionDueAt ?? today;
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 2, 12, 31),
      helpText: '选择下一行动日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      // Use UTC noon as the date-only convention; the read model renders
      // the stored instant in the organization timezone.
      _nextActionDueAt = DateTime.utc(
        selected.year,
        selected.month,
        selected.day,
        12,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final strategy = _strategyController.text.trim();
    final evidenceSummary = _evidenceController.text.trim();
    final notes = _notesController.text.trim();
    final nextActionTitle = _nextActionController.text.trim();

    var valid = true;
    if (widget.mode == _CaseCommandMode.intervention && strategy.isEmpty) {
      _strategyError = '请写下这次实际采用的教学动作';
      valid = false;
    }
    if (widget.mode == _CaseCommandMode.assessment && evidenceSummary.isEmpty) {
      _evidenceError = '请写下本次验证中可观察到的结果';
      valid = false;
    }
    if (nextActionTitle.isEmpty) {
      _nextActionError = '请保留或改写下一行动';
      valid = false;
    }
    if (!valid) {
      setState(() {});
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      late final CaseCommandReceipt receipt;
      if (widget.mode == _CaseCommandMode.confirm) {
        receipt = await widget.repository.confirmCase(
          ConfirmCaseCommand(
            operationId: _operationId,
            caseId: widget.learningCase.id,
            expectedCaseVersion: widget.learningCase.version,
            nextActionTitle: nextActionTitle,
            nextActionDueAt: _nextActionDueAt,
          ),
        );
      } else if (widget.mode == _CaseCommandMode.intervention) {
        receipt = await widget.repository.recordIntervention(
          RecordInterventionCommand(
            operationId: _operationId,
            caseId: widget.learningCase.id,
            expectedCaseVersion: widget.learningCase.version,
            strategy: strategy,
            notes: notes.isEmpty ? null : notes,
            occurredAt: null,
            nextActionTitle: nextActionTitle,
            nextActionDueAt: _nextActionDueAt,
          ),
        );
      } else {
        receipt = await widget.repository.recordAssessment(
          RecordAssessmentCommand(
            operationId: _operationId,
            caseId: widget.learningCase.id,
            expectedCaseVersion: widget.learningCase.version,
            result: _assessmentResult,
            evidenceSummary: evidenceSummary,
            notes: notes.isEmpty ? null : notes,
            assessedAt: null,
            nextActionTitle: nextActionTitle,
            nextActionDueAt: _nextActionDueAt,
          ),
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(receipt);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _saveError = _describeCaseCommandError(error);
      });
    }
  }

  Future<void> _confirmDiscard() async {
    if (_saving) {
      return;
    }
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃这次记录？'),
        content: const Text('当前输入还没有保存。放弃后不会生成新的教学事实。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃记录'),
          ),
        ],
      ),
    );
    if (mounted && discard == true) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final caseContext =
        '${widget.learningCase.typeLabel} · ${widget.learningCase.status.label} · version ${widget.learningCase.version}';
    return PopScope<void>(
      canPop: !_isDirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) {
          _confirmDiscard();
        }
      },
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: _saving ? null : _confirmDiscard,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _subtitle,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _WorkspaceContextLine(label: '当前 Case', value: caseContext),
                  if (widget.mode == _CaseCommandMode.intervention) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _strategyController,
                      autofocus: true,
                      enabled: !_saving,
                      minLines: 3,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: '教学动作 / Intervention *',
                        hintText: '记下讲解、练习、提示或调整方式',
                        errorText: _strategyError,
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                  if (widget.mode == _CaseCommandMode.assessment) ...[
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<CaseAssessmentResult>(
                      initialValue: _assessmentResult,
                      decoration: const InputDecoration(labelText: '验证结果 *'),
                      items: [
                        for (final result in CaseAssessmentResult.values)
                          DropdownMenuItem<CaseAssessmentResult>(
                            value: result,
                            child: Text(result.label),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (result) {
                              if (result != null) {
                                setState(() => _assessmentResult = result);
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _evidenceController,
                      autofocus: true,
                      enabled: !_saving,
                      minLines: 3,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: '本次验证 / Evidence *',
                        hintText: '记下学生这次能否独立完成、错在哪里、是否需要提示',
                        errorText: _evidenceError,
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                  if (widget.mode != _CaseCommandMode.confirm) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _notesController,
                      enabled: !_saving,
                      minLines: 2,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: '补充备注（可选）',
                        hintText: '记录对下一次教学有帮助的上下文',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _nextActionController,
                    enabled: !_saving,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: '下一行动 *',
                      hintText: '明确下一次要做什么',
                      errorText: _nextActionError,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _pickDueDate,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            _nextActionDueAt == null
                                ? '安排日期（可选）'
                                : '行动日期：${_formatDateOnly(_nextActionDueAt!)}',
                          ),
                        ),
                      ),
                      if (_nextActionDueAt != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        IconButton(
                          tooltip: '清除日期',
                          onPressed: _saving
                              ? null
                              : () => setState(() => _nextActionDueAt = null),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '日期按机构时区解释；提交失败时输入会保留，重试沿用同一 operation ID。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_saveError != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _WorkspaceErrorText(message: _saveError!),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _confirmDiscard,
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? '保存中…' : '保存并进入下一步'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceQuickCaptureForm extends StatefulWidget {
  const _WorkspaceQuickCaptureForm({
    required this.students,
    required this.caseTypes,
    required this.repository,
    this.initialStudent,
  });

  final List<WorkspaceStudent> students;
  final List<WorkspaceCaseType> caseTypes;
  final WorkspaceStudent? initialStudent;
  final LearningRepository repository;

  @override
  State<_WorkspaceQuickCaptureForm> createState() =>
      _WorkspaceQuickCaptureFormState();
}

class _WorkspaceQuickCaptureFormState
    extends State<_WorkspaceQuickCaptureForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _evidenceController;
  late final String _operationId;
  WorkspaceStudent? _selectedStudent;
  String _selectedCaseTypeKey = WorkspaceCaseType.builtInTypes.first.key;
  String? _studentError;
  String? _titleError;
  String? _evidenceError;
  String? _saveError;
  bool _saving = false;

  bool get _isDirty =>
      _titleController.text.trim().isNotEmpty ||
      _evidenceController.text.trim().isNotEmpty;

  List<WorkspaceCaseType> get _caseTypeOptions {
    final customTypes = widget.caseTypes.where(
      (caseType) => !caseType.isBuiltIn && caseType.isActive,
    );
    return <WorkspaceCaseType>[
      ...WorkspaceCaseType.builtInTypes,
      ...customTypes,
    ];
  }

  WorkspaceCaseType get _selectedCaseType {
    for (final caseType in _caseTypeOptions) {
      if (caseType.key == _selectedCaseTypeKey) {
        return caseType;
      }
    }
    return WorkspaceCaseType.builtInTypes.first;
  }

  @override
  void initState() {
    super.initState();
    _selectedStudent = widget.initialStudent;
    _operationId = createOperationId();
    _titleController = TextEditingController();
    _evidenceController = TextEditingController();
    _titleController.addListener(_clearInlineErrors);
    _evidenceController.addListener(_clearInlineErrors);
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_clearInlineErrors)
      ..dispose();
    _evidenceController
      ..removeListener(_clearInlineErrors)
      ..dispose();
    super.dispose();
  }

  void _clearInlineErrors() {
    if (!mounted) {
      return;
    }
    if ((_titleError != null && _titleController.text.trim().isNotEmpty) ||
        (_evidenceError != null &&
            _evidenceController.text.trim().isNotEmpty)) {
      setState(() {
        if (_titleController.text.trim().isNotEmpty) {
          _titleError = null;
        }
        if (_evidenceController.text.trim().isNotEmpty) {
          _evidenceError = null;
        }
      });
    }
  }

  Future<void> _save() async {
    var valid = true;
    if (_selectedStudent == null) {
      _studentError = '请选择学生';
      valid = false;
    }
    if (_titleController.text.trim().isEmpty) {
      _titleError = '请先写下问题标题';
      valid = false;
    }
    if (_evidenceController.text.trim().isEmpty) {
      _evidenceError = '请记下一条可观察的表现或证据';
      valid = false;
    }
    if (!valid) {
      setState(() {});
      return;
    }

    final student = _selectedStudent!;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.repository.quickCapture(
        QuickCaptureCommand(
          operationId: _operationId,
          profileId: student.profileId,
          expectedProfileVersion: student.profileVersion,
          caseType: _selectedCaseType.baseType,
          organizationCaseTypeId: _selectedCaseType.id,
          title: _titleController.text.trim(),
          description: _evidenceController.text.trim(),
          observedAt: DateTime.now(),
          evidenceSummary: _evidenceController.text.trim(),
          nextActionTitle: '补充证据并确认下一步',
          nextActionDueAt: null,
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _saveError = _describeSaveError(error);
      });
    }
  }

  Future<void> _confirmDiscard() async {
    if (!_isDirty && !_saving) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃这段记录？'),
        content: const Text('当前输入还没有保存。放弃后可以从学生详情重新记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃记录'),
          ),
        ],
      ),
    );
    if (mounted && discard == true) {
      Navigator.of(context).pop();
    }
  }

  String _describeSaveError(Object error) {
    final detail = error.toString().toLowerCase();
    if (detail.contains('version_conflict')) {
      return '学生资料已经发生变化。请保留这段输入，返回刷新后再试。';
    }
    if (detail.contains('network') ||
        detail.contains('socket') ||
        detail.contains('timeout')) {
      return '网络暂时不可用。输入仍保留在这里，请检查网络后重试。';
    }
    return '保存失败。输入仍保留在这里，请重试；未确认成功前不会生成重复 Case。';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope<void>(
      canPop: !_isDirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) {
          _confirmDiscard();
        }
      },
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '记录问题',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: _saving ? null : _confirmDiscard,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '先记录一条真实观察；保存后 Case 会保持“待整理”，不会自动跳过教师判断。',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<WorkspaceStudent>(
                    initialValue: _selectedStudent,
                    decoration: InputDecoration(
                      labelText: '学生 *',
                      errorText: _studentError,
                    ),
                    hint: const Text('选择学生后开始'),
                    items: [
                      for (final student in widget.students)
                        DropdownMenuItem<WorkspaceStudent>(
                          value: student,
                          child: Text('${student.name} · ${student.subject}'),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (student) {
                            setState(() {
                              _selectedStudent = student;
                              _studentError = null;
                            });
                          },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    key: const Key('quick-capture-case-type-dropdown'),
                    initialValue: _selectedCaseTypeKey,
                    decoration: const InputDecoration(labelText: '问题类型'),
                    items: [
                      for (final type in _caseTypeOptions)
                        DropdownMenuItem<String>(
                          value: type.key,
                          child: Text(type.label),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (typeKey) {
                            if (typeKey != null) {
                              setState(() => _selectedCaseTypeKey = typeKey);
                            }
                          },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _titleController,
                    autofocus: _selectedStudent != null,
                    enabled: !_saving,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: '问题标题 *',
                      hintText: '用一句话记下刚发现的问题',
                      errorText: _titleError,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _evidenceController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: '现场表现 / Evidence *',
                      hintText: '记下题目、行为或课堂中可观察到的表现',
                      errorText: _evidenceError,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '保存后会生成一条 finalized Evidence；错误需要用后续修正事实表达，不会静默覆盖原记录。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _WorkspaceContextLine(
                    label: '保存后',
                    value:
                        '待整理 Case · ${_selectedCaseType.label} · 下一步“补充证据并确认下一步” · 日期待安排',
                  ),
                  if (_saveError != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _WorkspaceErrorText(message: _saveError!),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _confirmDiscard,
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? '保存中…' : '保存问题'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaseTypeDraft {
  const _CaseTypeDraft({required this.displayName, required this.baseType});

  final String displayName;
  final LearningCaseType baseType;
}

class _WorkspaceCaseTypeEditorDialog extends StatefulWidget {
  const _WorkspaceCaseTypeEditorDialog({
    this.initialName = '',
    this.initialBaseType = LearningCaseType.knowledge,
    this.allowBaseTypeChange = true,
  });

  final String initialName;
  final LearningCaseType initialBaseType;
  final bool allowBaseTypeChange;

  @override
  State<_WorkspaceCaseTypeEditorDialog> createState() =>
      _WorkspaceCaseTypeEditorDialogState();
}

class _WorkspaceCaseTypeEditorDialogState
    extends State<_WorkspaceCaseTypeEditorDialog> {
  late final TextEditingController _nameController;
  late LearningCaseType _baseType;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _baseType = widget.initialBaseType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final displayName = _nameController.text.trim();
    if (displayName.isEmpty) {
      setState(() => _error = '请输入问题类型名称。');
      return;
    }
    if (displayName.length > 64) {
      setState(() => _error = '名称不能超过 64 个字符。');
      return;
    }
    Navigator.of(context).pop(
      _CaseTypeDraft(displayName: displayName, baseType: _baseType),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialName.isEmpty ? '新增问题类型' : '重命名问题类型'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                autofocus: true,
                maxLength: 64,
                decoration: InputDecoration(
                  labelText: '显示名称',
                  hintText: '例如：审题习惯、计算步骤',
                  errorText: _error,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (widget.allowBaseTypeChange)
                DropdownButtonFormField<LearningCaseType>(
                  initialValue: _baseType,
                  decoration: const InputDecoration(labelText: '归入基础分类'),
                  items: [
                    for (final type in LearningCaseType.values)
                      DropdownMenuItem<LearningCaseType>(
                        value: type,
                        child: Text(type.label),
                      ),
                  ],
                  onChanged: (type) {
                    if (type != null) {
                      setState(() => _baseType = type);
                    }
                  },
                )
              else
                _WorkspaceContextLine(
                  label: '基础分类',
                  value: _baseType.label,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

class _WorkspaceCaseTypeManager extends StatefulWidget {
  const _WorkspaceCaseTypeManager({
    required this.organizationId,
    required this.caseTypes,
    required this.repository,
    this.onChanged,
    this.showCloseButton = true,
  });

  final String organizationId;
  final List<WorkspaceCaseType> caseTypes;
  final LearningRepository repository;
  final Future<void> Function()? onChanged;
  final bool showCloseButton;

  @override
  State<_WorkspaceCaseTypeManager> createState() =>
      _WorkspaceCaseTypeManagerState();
}

class _WorkspaceCaseTypeManagerState extends State<_WorkspaceCaseTypeManager> {
  late List<WorkspaceCaseType> _caseTypes;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _caseTypes = List<WorkspaceCaseType>.of(widget.caseTypes);
  }

  Future<void> _createCaseType() async {
    final draft = await showDialog<_CaseTypeDraft>(
      context: context,
      builder: (_) => const _WorkspaceCaseTypeEditorDialog(),
    );
    if (!mounted || draft == null) {
      return;
    }
    await _runMutation(
      () => widget.repository.createCaseType(
        organizationId: widget.organizationId,
        displayName: draft.displayName,
        baseType: draft.baseType,
      ),
    );
  }

  Future<void> _renameCaseType(WorkspaceCaseType caseType) async {
    final caseTypeId = caseType.id;
    if (caseTypeId == null) {
      return;
    }
    final draft = await showDialog<_CaseTypeDraft>(
      context: context,
      builder: (_) => _WorkspaceCaseTypeEditorDialog(
        initialName: caseType.label,
        initialBaseType: caseType.baseType,
        allowBaseTypeChange: false,
      ),
    );
    if (!mounted || draft == null) {
      return;
    }
    await _runMutation(
      () => widget.repository.renameCaseType(
        caseTypeId: caseTypeId,
        displayName: draft.displayName,
        expectedVersion: caseType.version,
      ),
    );
  }

  Future<void> _archiveCaseType(WorkspaceCaseType caseType) async {
    final caseTypeId = caseType.id;
    if (caseTypeId == null || !caseType.isActive) {
      return;
    }
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('归档这个问题类型？'),
        content: Text(
          '归档后不能用于新记录，但已有“${caseType.label}”的问题历史仍会保留。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('归档'),
          ),
        ],
      ),
    );
    if (!mounted || shouldArchive != true) {
      return;
    }
    await _runMutation(
      () => widget.repository.archiveCaseType(
        caseTypeId: caseTypeId,
        expectedVersion: caseType.version,
      ),
    );
  }

  Future<void> _runMutation(
    Future<WorkspaceCaseType> Function() mutation,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await mutation();
      if (!mounted) {
        return;
      }
      setState(() {
        final index = _caseTypes.indexWhere((item) => item.key == updated.key);
        if (index == -1) {
          _caseTypes = [..._caseTypes, updated];
        } else {
          _caseTypes = [
            ..._caseTypes.sublist(0, index),
            updated,
            ..._caseTypes.sublist(index + 1),
          ];
        }
      });
      final onChanged = widget.onChanged;
      if (onChanged != null) {
        await onChanged();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = _describeCaseTypeError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _describeCaseTypeError(Object error) {
    final detail = error.toString().toLowerCase();
    if (detail.contains('case_type_name_taken')) {
      return '这个名称已经存在，请换一个名称。';
    }
    if (detail.contains('invalid_case_type_input')) {
      return '名称不能与系统类型重复，且不能超过 64 个字符。';
    }
    if (detail.contains('version_conflict')) {
      return '类型列表已经更新，请关闭后重新打开再操作。';
    }
    if (detail.contains('case_type_archived')) {
      return '这个类型已经归档，请刷新列表。';
    }
    if (detail.contains('case_type_manager_required') ||
        detail.contains('permission')) {
      return '当前账号没有修改机构问题类型的权限。';
    }
    if (detail.contains('network') ||
        detail.contains('socket') ||
        detail.contains('timeout')) {
      return '网络暂时不可用，列表和输入都保留，请稍后重试。';
    }
    return '操作失败，列表没有被静默改写，请重试。';
  }

  List<WorkspaceCaseType> _customTypes({required bool active}) {
    final result = _caseTypes
        .where((caseType) => !caseType.isBuiltIn && caseType.isActive == active)
        .toList();
    result.sort((left, right) {
      final order = left.sortOrder.compareTo(right.sortOrder);
      if (order != 0) {
        return order;
      }
      return left.label.compareTo(right.label);
    });
    return result;
  }

  Widget _typeRow(WorkspaceCaseType caseType) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.label_outline, color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caseType.label),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '基础分类：${caseType.baseType.label}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (caseType.isActive)
            PopupMenuButton<String>(
              enabled: !_busy,
              tooltip: '更多操作',
              onSelected: (value) {
                if (value == 'rename') {
                  _renameCaseType(caseType);
                } else if (value == 'archive') {
                  _archiveCaseType(caseType);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(value: 'rename', child: Text('重命名')),
                PopupMenuItem<String>(value: 'archive', child: Text('归档')),
              ],
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: Text('已归档'),
            ),
        ],
      ),
    );
  }

  Widget _typeSection({
    required String title,
    required List<WorkspaceCaseType> types,
    required String emptyTitle,
    required String emptyMessage,
    required IconData icon,
  }) {
    return _WorkspaceSection(
      title: title,
      count: '${types.length} 个',
      child: types.isEmpty
          ? _WorkspaceStateNotice(
              title: emptyTitle,
              message: emptyMessage,
              icon: icon,
            )
          : Column(children: [for (final type in types) _typeRow(type)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final activeTypes = _customTypes(active: true);
    final archivedTypes = _customTypes(active: false);
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '问题类型',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (widget.showCloseButton)
                      IconButton(
                        tooltip: '关闭',
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
                Text(
                  '系统类型始终保留。自定义类型只负责分类，仍沿用同一套 Case、证据、行动和验证流程。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_error != null) ...[
                  _WorkspaceErrorText(message: _error!),
                  const SizedBox(height: AppSpacing.sm),
                ],
                _typeSection(
                  title: '可用于新记录',
                  types: activeTypes,
                  emptyTitle: '还没有自定义类型',
                  emptyMessage: '先添加一个贴合你们教学语言的分类，教师记录问题时就能直接选择。',
                  icon: Icons.category_outlined,
                ),
                const SizedBox(height: AppSpacing.md),
                _typeSection(
                  title: '已归档',
                  types: archivedTypes,
                  emptyTitle: '没有已归档类型',
                  emptyMessage: '归档后仍会保留历史名称，不会改变已有 Case。',
                  icon: Icons.archive_outlined,
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _createCaseType,
                    icon: const Icon(Icons.add),
                    label: const Text('新增自定义类型'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceCaseCommandSection extends StatelessWidget {
  const _WorkspaceCaseCommandSection({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.arrow_circle_right_outlined,
            color: AppColors.accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(buttonLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceShell extends StatelessWidget {
  const _WorkspaceShell({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    this.onSignOut,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      builder: (context, sizeClass) {
        if (sizeClass == WindowSizeClass.compact) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('教师工作台'),
              actions: [
                if (onSignOut != null)
                  IconButton(
                    tooltip: '退出登录',
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout),
                  ),
              ],
            ),
            body: SafeArea(child: child),
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: _workspaceDestinations,
            ),
          );
        }
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                _WorkspaceRail(
                  extended: sizeClass == WindowSizeClass.expanded,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  onSignOut: onSignOut,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceRail extends StatelessWidget {
  const _WorkspaceRail({
    required this.extended,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.onSignOut,
  });

  final bool extended;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: extended ? 232 : 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              extended ? AppSpacing.lg : AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: extended
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '学情闭环',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '教师工作台',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  )
                : const Center(child: Icon(Icons.menu_book_outlined, size: 24)),
          ),
          const Divider(height: 1),
          Expanded(
            child: NavigationRail(
              extended: extended,
              minExtendedWidth: 232,
              backgroundColor: Colors.transparent,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.none,
              indicatorColor: AppColors.surfaceAccent,
              selectedIconTheme: const IconThemeData(color: AppColors.accent),
              unselectedIconTheme: const IconThemeData(
                color: AppColors.textSecondary,
              ),
              destinations: _workspaceRailDestinations,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              extended ? AppSpacing.lg : AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.lg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    extended ? '开发数据 · 仅当前权限范围' : '开发数据',
                    textAlign: extended ? TextAlign.start : TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (extended && onSignOut != null)
                  IconButton(
                    tooltip: '退出登录',
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _workspaceDestinations = <NavigationDestination>[
  NavigationDestination(
    icon: Icon(Icons.today_outlined),
    selectedIcon: Icon(Icons.today),
    label: '今日',
  ),
  NavigationDestination(
    icon: Icon(Icons.people_outline),
    selectedIcon: Icon(Icons.people),
    label: '学生',
  ),
];

const _workspaceRailDestinations = <NavigationRailDestination>[
  NavigationRailDestination(
    icon: Icon(Icons.today_outlined),
    selectedIcon: Icon(Icons.today),
    label: Text('今日'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.people_outline),
    selectedIcon: Icon(Icons.people),
    label: Text('学生'),
  ),
];

class _WorkspaceFrame extends StatelessWidget {
  const _WorkspaceFrame({required this.sizeClass, required this.child});

  final WindowSizeClass sizeClass;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = switch (sizeClass) {
      WindowSizeClass.compact => AppSpacing.md,
      WindowSizeClass.medium => AppSpacing.lg,
      WindowSizeClass.expanded => AppSpacing.xl,
    };
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.md,
        horizontalPadding,
        AppSpacing.xxl,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: child,
        ),
      ),
    );
  }
}

class _WorkspacePageHeader extends StatelessWidget {
  const _WorkspacePageHeader({
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canFitActions = constraints.maxWidth >= 560;
          final leadingBlock = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(child: titleBlock),
            ],
          );
          if (!canFitActions && actions.isNotEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leadingBlock,
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: actions,
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: leadingBlock),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: actions,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WorkspaceSection extends StatelessWidget {
  const _WorkspaceSection({
    required this.title,
    required this.child,
    this.count,
    this.action,
    this.showTopDivider = false,
    super.key,
  });

  final String title;
  final Widget child;
  final String? count;
  final Widget? action;
  final bool showTopDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTopDivider) const Divider(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (count != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        count!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              ?action,
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _WorkspaceStudentRow extends StatelessWidget {
  const _WorkspaceStudentRow({required this.student, required this.onOpen});

  final WorkspaceStudent student;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '打开 ${student.name} 的学生详情',
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xxs),
                child: Icon(Icons.person_outline, size: 21),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xxs,
                      children: [
                        _WorkspaceMetadata(
                          '${student.grade} · ${student.subject}',
                        ),
                        _WorkspaceMetadata(student.context),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      student.cases.isEmpty
                          ? '还没有 Learning Case'
                          : '${student.cases.length} 个当前 Learning Case',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceCaseRow extends StatelessWidget {
  const _WorkspaceCaseRow({
    required this.student,
    required this.learningCase,
    required this.onOpen,
  });

  final WorkspaceStudent student;
  final WorkspaceCase learningCase;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final primaryAction = learningCase.primaryAction;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  learningCase.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _WorkspaceStatusMarker(label: learningCase.status.label),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xxs,
            children: [
              _WorkspaceMetadata('${student.name} · ${student.subject}'),
              _WorkspaceMetadata(_priorityLabel(learningCase.priority)),
              if (primaryAction != null)
                _WorkspaceMetadata('下一步：${primaryAction.title}'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(onPressed: onOpen, child: const Text('查看 Case')),
        ],
      ),
    );
  }
}

class _WorkspaceActionGroup extends StatelessWidget {
  const _WorkspaceActionGroup({
    required this.student,
    required this.items,
    required this.onOpenCase,
  });

  final WorkspaceStudent student;
  final List<WorkspaceActionWithContext> items;
  final ValueChanged<WorkspaceCase> onOpenCase;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              '${student.name} · ${student.subject}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_forward_outlined, size: 21),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.action.title,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xxs,
                              children: [
                                _WorkspaceMetadata(item.learningCase.title),
                                _WorkspaceMetadata(
                                  _formatActionDate(item.action),
                                  icon: Icons.event_outlined,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(left: 33),
                    child: OutlinedButton(
                      onPressed: () => onOpenCase(item.learningCase),
                      child: const Text('查看 Case'),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _WorkspaceFacts extends StatelessWidget {
  const _WorkspaceFacts({required this.student, required this.sizeClass});

  final WorkspaceStudent student;
  final WindowSizeClass sizeClass;

  @override
  Widget build(BuildContext context) {
    final facts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final event in student.recentFacts)
          _WorkspaceTimelineItem(event: event),
      ],
    );
    if (sizeClass != WindowSizeClass.expanded) {
      return _WorkspaceSection(title: '最近关键事实', child: facts);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _WorkspaceSection(title: '最近关键事实', child: facts),
        ),
        const SizedBox(width: AppSpacing.xl),
        const Expanded(
          child: _WorkspaceStateNotice(
            title: '历史按需展开',
            message: '先用最近关键事实解释现在，需要时再查看更早 timeline。',
            icon: Icons.history_outlined,
          ),
        ),
      ],
    );
  }
}

class _WorkspaceNarrativeSection extends StatelessWidget {
  const _WorkspaceNarrativeSection({
    required this.title,
    required this.content,
    this.isPrimary = false,
  });

  final String title;
  final String content;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const Divider(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _WorkspaceTimelineItem extends StatelessWidget {
  const _WorkspaceTimelineItem({required this.event});

  final WorkspaceTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              _formatDate(event.occurredAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 8, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.typeLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(event.text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceSubheading extends StatelessWidget {
  const _WorkspaceSubheading({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceStatusMarker extends StatelessWidget {
  const _WorkspaceStatusMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      '已逾期' => AppColors.danger,
      '待验证' => AppColors.info,
      '稳定' => AppColors.success,
      '已关闭' => AppColors.textSecondary,
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _WorkspaceMetadata extends StatelessWidget {
  const _WorkspaceMetadata(this.text, {this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xxs),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _WorkspaceStateNotice extends StatelessWidget {
  const _WorkspaceStateNotice({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceBoundaryBanner extends StatelessWidget {
  const _WorkspaceBoundaryBanner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '开发环境数据，仅显示当前账号有权访问的内容',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 18,
              color: AppColors.accent,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '开发环境虚构资料 · 只显示当前权限范围 · 保存会写入开发数据库',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceContextLine extends StatelessWidget {
  const _WorkspaceContextLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceStatusScaffold extends StatelessWidget {
  const _WorkspaceStatusScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: child),
    );
  }
}

class _WorkspaceLoadingBody extends StatelessWidget {
  const _WorkspaceLoadingBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(message),
        ],
      ),
    );
  }
}

class _WorkspaceErrorBody extends StatelessWidget {
  const _WorkspaceErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 32),
              const SizedBox(height: AppSpacing.md),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceNoAccessBody extends StatelessWidget {
  const _WorkspaceNoAccessBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: _WorkspaceStateNotice(
          title: '当前账号没有可用的教师教学范围',
          message: '请联系机构管理员确认 active membership、教师角色、学科范围和学生分配。页面不会展示受限学生或 Case 的摘要。',
          icon: Icons.lock_outline,
        ),
      ),
    );
  }
}

class _WorkspaceConfigBody extends StatelessWidget {
  const _WorkspaceConfigBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: _WorkspaceStateNotice(
          title: '开发云端尚未配置',
          message: '请使用 XUEQING_SUPABASE_URL 和 XUEQING_SUPABASE_PUBLISHABLE_KEY 启动开发环境。正式 provider、region 和真实资料仍未启用。',
          icon: Icons.settings_outlined,
        ),
      ),
    );
  }
}

class _WorkspaceLoginBody extends StatelessWidget {
  const _WorkspaceLoginBody({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.busy,
    required this.errorMessage,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool busy;
  final String? errorMessage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('教师工作台')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '登录开发环境',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '仅使用虚构测试账号。登录后，服务端仍会按 membership、角色、学科范围和学生分配限制数据。',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '请输入开发环境账号'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) =>
                          value == null || value.isEmpty ? '请输入开发环境密码' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy ? null : onSubmit,
                        child: Text(busy ? '登录中…' : '登录开发环境'),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _WorkspaceErrorText(message: errorMessage!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceErrorText extends StatelessWidget {
  const _WorkspaceErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}

class WorkspaceActionWithContext {
  const WorkspaceActionWithContext({
    required this.student,
    required this.learningCase,
    required this.action,
  });

  final WorkspaceStudent student;
  final WorkspaceCase learningCase;
  final WorkspaceAction action;
}

class WorkspaceCaseWithContext {
  const WorkspaceCaseWithContext({
    required this.student,
    required this.learningCase,
  });

  final WorkspaceStudent student;
  final WorkspaceCase learningCase;
}

_CaseCommandMode? _caseCommandMode(WorkspaceCase learningCase) {
  return switch (learningCase.status) {
    LearningCaseStatus.newCase => _CaseCommandMode.confirm,
    LearningCaseStatus.confirmed => _CaseCommandMode.intervention,
    LearningCaseStatus.intervening =>
      learningCase.primaryAction?.actionType == 'verify'
          ? _CaseCommandMode.assessment
          : _CaseCommandMode.intervention,
    LearningCaseStatus.pendingVerification => _CaseCommandMode.assessment,
    LearningCaseStatus.stable => null,
    LearningCaseStatus.closed => null,
  };
}

String? _caseCommandLabel(WorkspaceCase learningCase) {
  return switch (_caseCommandMode(learningCase)) {
    _CaseCommandMode.confirm => '确认 Case',
    _CaseCommandMode.intervention => '记录教学动作',
    _CaseCommandMode.assessment => '记录验证结果',
    null => null,
  };
}

String _caseCommandHint(WorkspaceCase learningCase) {
  return switch (_caseCommandMode(learningCase)) {
    _CaseCommandMode.confirm => '确认问题范围、补充判断，然后生成一条可执行的练习行动。',
    _CaseCommandMode.intervention =>
      '把课堂中实际发生的教学动作记下来，系统会把下一步变成 verify action。',
    _CaseCommandMode.assessment => '记录一次可观察的验证结果；通过后仍会停在待确认，不会自动关闭。',
    null => '',
  };
}

String _caseStatusLabelFromWire(String value) {
  return switch (value) {
    'new' => '待整理',
    'confirmed' => '已确认',
    'intervening' => '干预中',
    'pending_verification' => '待验证',
    'stable' => '稳定',
    'closed' => '已关闭',
    _ => value,
  };
}

String _describeCaseCommandError(Object error) {
  final detail = error.toString().toLowerCase();
  if (detail.contains('case_version_conflict') ||
      detail.contains('version_conflict')) {
    return '这个 Case 已经被更新。输入仍保留，请先刷新后确认最新状态再重试。';
  }
  if (detail.contains('no active session') ||
      detail.contains('not authenticated') ||
      detail.contains('signed out')) {
    return '登录状态已失效。请重新登录后再保存，这次输入仍保留在表单中。';
  }
  if (detail.contains('not authorized') ||
      detail.contains('permission') ||
      detail.contains('teaching membership')) {
    return '当前账号已经不能执行这一步，可能是权限或 Case 状态发生了变化。请刷新后再试。';
  }
  if (detail.contains('network') ||
      detail.contains('socket') ||
      detail.contains('timeout')) {
    return '网络暂时不可用。输入仍保留在这里，请检查网络后重试。';
  }
  return '保存失败。输入仍保留在这里，请重试；未确认成功前不会生成重复事实。';
}

String _formatDateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _priorityLabel(String value) {
  return switch (value) {
    'urgent' => '紧急',
    'high' => '重点跟进',
    'low' => '低优先级',
    _ => '普通优先级',
  };
}

String _assessmentLabel(String value) {
  return switch (value) {
    'passed' => '通过',
    'partial' => '部分通过',
    'not_passed' => '未通过',
    _ => '待判断',
  };
}

String _formatDate(DateTime value) => '${value.month} 月 ${value.day} 日';

String _formatActionDate(WorkspaceAction action) {
  if (action.dueAt == null) {
    return action.bucket.label;
  }
  return '${action.bucket.label} · ${_formatDate(action.dueAt!)}';
}
