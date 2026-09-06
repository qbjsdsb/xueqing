import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/layout/responsive.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../cloud/auth_repository.dart';
import '../../../cloud/cloud_client.dart';
import '../../../cloud/case_reopen_draft_store.dart';
import '../../../cloud/learning_repository.dart';
import '../../../cloud/organization_management_repository.dart';
import '../../../cloud/organization_member_provisioning_repository.dart';
import '../../../config/app_config.dart';
import '../../organization_management/presentation/organization_invitation_acceptance_card.dart';
import '../../organization_management/presentation/organization_management_page.dart';
import 'member_onboarding_page.dart';
import '../../../core/logging/app_logger.dart';
import '../../../update/update_dialog.dart';
import '../../../update/update_installer.dart';
import '../../../update/update_service.dart';

class TeacherWorkspaceEntryPage extends StatefulWidget {
  const TeacherWorkspaceEntryPage({
    required this.config,
    this.authRepository,
    this.learningRepository,
    this.organizationManagementRepository,
    this.invitationAcceptanceRepository,
    this.organizationMemberProvisioningRepository,
    this.organizationMemberLifecycleRepository,
    this.caseReopenDraftStore,
    super.key,
  });

  final AppConfig config;
  final AuthRepository? authRepository;
  final LearningRepository? learningRepository;
  final OrganizationManagementRepository? organizationManagementRepository;
  final OrganizationInvitationAcceptanceRepository?
  invitationAcceptanceRepository;
  final OrganizationMemberProvisioningRepository?
  organizationMemberProvisioningRepository;
  final OrganizationMemberLifecycleRepository?
  organizationMemberLifecycleRepository;
  final CaseReopenDraftStore? caseReopenDraftStore;

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
  OrganizationManagementRepository? _organizationManagementRepository;
  OrganizationInvitationAcceptanceRepository? _invitationAcceptanceRepository;
  OrganizationMemberProvisioningRepository?
  _organizationMemberProvisioningRepository;
  OrganizationMemberLifecycleRepository? _organizationMemberLifecycleRepository;
  String? _errorMessage;
  String? _activeUserId;
  bool _signedIn = false;
  bool _busy = false;
  late final UpdateService _updateService;
  late final UpdateInstaller _updateInstaller;
  bool _checkingMembershipState = false;
  OrganizationMembershipState? _membershipState;
  bool _onboardingTransition = false;
  late final CaseReopenDraftStore _caseReopenDraftStore;

  @override
  void initState() {
    super.initState();
    _caseReopenDraftStore =
        widget.caseReopenDraftStore ?? SecureCaseReopenDraftStore();
    _updateService = UpdateService(currentVersion: widget.config.appVersion);
    _updateInstaller = PlatformUpdateInstaller();
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
      _organizationManagementRepository =
          widget.organizationManagementRepository;
      _invitationAcceptanceRepository = widget.invitationAcceptanceRepository;
      _organizationMemberProvisioningRepository =
          widget.organizationMemberProvisioningRepository;
      _organizationMemberLifecycleRepository =
          widget.organizationMemberLifecycleRepository;
    } else {
      widget.config.cloudConfig.validate(
        requireConfigured: widget.config.environment.isProduction,
        requireHttps: widget.config.environment.isProduction,
        requireAllowedHost: widget.config.environment.isProduction,
      );
      if (!widget.config.cloudConfig.isConfigured) {
        return;
      }
      await CloudClient.initialize(
        widget.config.cloudConfig,
        requireSecureEndpoint: widget.config.environment.isProduction,
      );
      _authRepository = SupabaseAuthRepository(CloudClient.client);
      _learningRepository = SupabaseLearningRepository(CloudClient.client);
      _organizationManagementRepository =
          SupabaseOrganizationManagementRepository(CloudClient.client);
      _invitationAcceptanceRepository =
          SupabaseOrganizationInvitationAcceptanceRepository(
            CloudClient.client,
          );
      _organizationMemberProvisioningRepository =
          SupabaseOrganizationMemberProvisioningRepository(CloudClient.client);
      _organizationMemberLifecycleRepository =
          SupabaseOrganizationMemberLifecycleRepository(CloudClient.client);
    }

    _activeUserId = _authRepository!.currentUser?.id;
    _signedIn = _activeUserId != null;
    if (_signedIn && _organizationMemberLifecycleRepository != null) {
      _checkingMembershipState = true;
      unawaited(_loadMembershipState());
    }
    _authSubscription = _authRepository!.authStateChanges.listen((state) {
      if (!mounted) {
        return;
      }
      final nextUserId = state.session?.user.id;
      final userChanged = _activeUserId != nextUserId;
      if (_onboardingTransition && nextUserId == null) {
        return;
      }
      setState(() {
        _activeUserId = nextUserId;
        _signedIn = nextUserId != null;
        if (!_signedIn || userChanged) {
          _errorMessage = null;
        }
        if (!_signedIn) {
          _membershipState = null;
        }
      });
      if (nextUserId != null &&
          userChanged &&
          _organizationMemberLifecycleRepository != null) {
        unawaited(_loadMembershipState());
      }
    });
  }

  Future<void> _loadMembershipState() async {
    final repository = _organizationMemberLifecycleRepository;
    if (repository == null) {
      return;
    }
    if (mounted) {
      setState(() {
        _checkingMembershipState = true;
        _membershipState = null;
      });
    }
    try {
      final state = await repository.loadCurrentMembershipState();
      if (mounted) {
        setState(() => _membershipState = state);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = _describeAuthError(error, action: '读取账号状态'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _checkingMembershipState = false);
      }
    }
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
      final nextUserId = _authRepository!.currentUser?.id;
      if (nextUserId == null) {
        throw const AuthException('Authentication did not return a user.');
      }
      if (mounted) {
        setState(() {
          _activeUserId = nextUserId;
          _signedIn = true;
        });
        if (_organizationMemberLifecycleRepository != null) {
          unawaited(_loadMembershipState());
        }
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
        final nextUserId = authRepository.currentUser?.id;
        setState(() {
          _activeUserId = nextUserId;
          _signedIn = nextUserId != null;
          if (!_signedIn) {
            _emailController.clear();
            _passwordController.clear();
          }
        });
      }
    } catch (error) {
      if (mounted) {
        final nextUserId = authRepository.currentUser?.id;
        setState(() {
          _activeUserId = nextUserId;
          _signedIn = nextUserId != null;
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
              title: '工作台初始化失败',
              message: '请检查开发环境配置后重试。',
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
            isDevelopment: !widget.config.environment.isProduction,
            onSubmit: _signIn,
          );
        }
        if (_organizationMemberLifecycleRepository != null &&
            (_checkingMembershipState || _membershipState == null)) {
          return _WorkspaceStatusScaffold(
            title: '教师工作台',
            child: _checkingMembershipState
                ? const _WorkspaceLoadingBody(message: '正在核验账号状态…')
                : _WorkspaceErrorBody(
                    title: '账号状态读取失败',
                    message: _errorMessage ?? '请重试后继续。',
                    onRetry: () => unawaited(_loadMembershipState()),
                  ),
          );
        }
        final membershipState = _membershipState;
        if (membershipState?.isOnboarding == true) {
          final email =
              _authRepository!.currentUser?.email ??
              _emailController.text.trim();
          return MemberOnboardingPage(
            key: ValueKey('onboarding-$_activeUserId'),
            authRepository: _authRepository!,
            lifecycleRepository: _organizationMemberLifecycleRepository!,
            email: email,
            displayName: membershipState?.displayName,
            expiresAt: membershipState?.onboardingExpiresAt,
            onTransitionChanged: _setOnboardingTransition,
            onCompleted: _finishOnboarding,
          );
        }
        if (membershipState?.isDisabled == true) {
          return _WorkspaceStatusScaffold(
            title: '账号已停用',
            child: _WorkspaceErrorBody(
              title: '暂时无法进入工作台',
              message: '当前账号已被机构负责人停用，请联系负责人处理。',
              onRetry: () => unawaited(_signOut()),
            ),
          );
        }
        return TeacherWorkspacePage(
          key: ValueKey(_activeUserId),
          repository: _learningRepository!,
          managementRepository: _organizationManagementRepository,
          memberProvisioningRepository:
              _organizationMemberProvisioningRepository,
          invitationAcceptanceRepository: _invitationAcceptanceRepository,
          updateService: _updateService,
          updateInstaller: _updateInstaller,
          onSignOut: _busy ? null : _signOut,
          caseReopenDraftStore: _caseReopenDraftStore,
          sessionUserId: _activeUserId,
        );
      },
    );
  }

  void _setOnboardingTransition(bool value) {
    if (!mounted) {
      return;
    }
    setState(() {
      _onboardingTransition = value;
      if (!value && _authRepository?.currentUser == null) {
        _activeUserId = null;
        _signedIn = false;
        _membershipState = null;
      }
    });
  }

  void _finishOnboarding() {
    if (!mounted) {
      return;
    }
    setState(() {
      _onboardingTransition = false;
      _activeUserId = null;
      _signedIn = false;
      _membershipState = null;
      _emailController.clear();
      _passwordController.clear();
    });
  }
}

class TeacherWorkspacePage extends StatefulWidget {
  const TeacherWorkspacePage({
    required this.repository,
    this.managementRepository,
    this.memberProvisioningRepository,
    this.invitationAcceptanceRepository,
    this.updateService,
    this.updateInstaller,
    this.onSignOut,
    this.caseReopenDraftStore,
    this.sessionUserId,
    super.key,
  });

  final LearningRepository repository;
  final OrganizationManagementRepository? managementRepository;
  final OrganizationMemberProvisioningRepository? memberProvisioningRepository;
  final OrganizationInvitationAcceptanceRepository?
  invitationAcceptanceRepository;
  final UpdateService? updateService;
  final UpdateInstaller? updateInstaller;
  final VoidCallback? onSignOut;
  final CaseReopenDraftStore? caseReopenDraftStore;
  final String? sessionUserId;

  @override
  State<TeacherWorkspacePage> createState() => _TeacherWorkspacePageState();
}

class _TeacherWorkspacePageState extends State<TeacherWorkspacePage> {
  static const _workspaceLogger = AppLogger(
    environment: AppEnvironment.production,
  );

  final _studentSearchController = TextEditingController();
  final _invitationFormKey = GlobalKey<FormState>();
  final _inviteCodeController = TextEditingController();
  final _displayNameController = TextEditingController();
  int _selectedIndex = 0;
  WorkspaceStudent? _selectedStudent;
  WorkspaceCase? _selectedCase;
  late Future<TeacherWorkspace> _workspaceFuture;
  String? _invitationErrorMessage;
  bool _invitationBusy = false;
  String? _reschedulingActionId;
  String? _completingActionId;
  final Map<String, String> _retryOperationIds = <String, String>{};
  TeacherWorkspace? _lastWorkspace;
  bool _isRefreshing = false;
  bool _checkingForUpdates = false;
  int _loadSequence = 0;

  @override
  void initState() {
    super.initState();
    _workspaceFuture = _loadWorkspace();
  }

  Future<TeacherWorkspace> _loadWorkspace() async {
    final requestId = ++_loadSequence;
    try {
      final workspace = await widget.repository.loadWorkspace();
      if (mounted && requestId == _loadSequence) {
        setState(() {
          _lastWorkspace = workspace;
        });
      }
      return workspace;
    } catch (error, stackTrace) {
      _workspaceLogger.error(
        'Teacher workspace load failed.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _checkForUpdates() async {
    final service = widget.updateService;
    final installer = widget.updateInstaller;
    if (service == null || installer == null || _checkingForUpdates) {
      return;
    }

    setState(() => _checkingForUpdates = true);
    try {
      final result = await service.checkForUpdate();
      if (!mounted) {
        return;
      }
      final shouldInstall = await showDialog<bool>(
        context: context,
        builder: (_) => UpdateDialog(result: result),
      );
      if (shouldInstall != true || !mounted) {
        return;
      }

      final downloaded = await service.download(result);
      final installResult = await installer.install(downloaded);
      if (!mounted) {
        return;
      }
      if (installResult.shouldExit) {
        await SystemNavigator.pop();
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已打开系统安装界面，请按提示完成更新。')));
    } on UpdateException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    } on UpdateInstallException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('更新失败，请稍后重试。')));
      }
    } finally {
      if (mounted) {
        setState(() => _checkingForUpdates = false);
      }
    }
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    _inviteCodeController.dispose();
    _displayNameController.dispose();
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

  Future<bool> _reload({
    WorkspaceStudent? preserveStudent,
    String? preserveCaseId,
  }) async {
    final nextFuture = _loadWorkspace();
    if (!mounted) {
      return false;
    }
    setState(() {
      _workspaceFuture = nextFuture;
      _isRefreshing = _lastWorkspace != null;
    });
    try {
      final workspace = await nextFuture;
      if (!mounted || preserveStudent == null) {
        return true;
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
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          // Never leave a write result hidden behind stale workspace data.
          _lastWorkspace = null;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('刷新失败，请点击重试确认最新数据。')));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  String _closeRetryKeyFor(WorkspaceCase learningCase) {
    return 'close:${learningCase.id}:${learningCase.version}';
  }

  String _operationIdForRetry(String retryKey) {
    return _retryOperationIds.putIfAbsent(retryKey, createOperationId);
  }

  void _clearRetry(String retryKey) {
    _retryOperationIds.remove(retryKey);
  }

  String _rescheduleRetryKeyFor(
    WorkspaceActionWithContext item,
    DateTime picked,
  ) {
    final dateKey =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    return 'reschedule:${item.learningCase.id}:${item.action.id}:'
        '${item.learningCase.version}:${item.action.version}:$dateKey';
  }

  Future<void> _acceptInvitation() async {
    if (_invitationBusy ||
        !(_invitationFormKey.currentState?.validate() ?? false)) {
      return;
    }

    final repository = widget.invitationAcceptanceRepository;
    if (repository == null) {
      return;
    }

    setState(() {
      _invitationBusy = true;
      _invitationErrorMessage = null;
    });
    try {
      await repository.acceptInvitation(
        inviteCode: _inviteCodeController.text.trim(),
        displayName: _displayNameController.text.trim(),
      );
      _inviteCodeController.clear();
      _displayNameController.clear();
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已加入机构，可以开始使用。')));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _invitationErrorMessage = _describeInvitationError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _invitationBusy = false;
        });
      }
    }
  }

  String _describeInvitationError(Object error) {
    final knownMessage = organizationInvitationErrorMessage(error);
    if (knownMessage != null) {
      return '接受邀请失败：$knownMessage';
    }
    return '接受邀请失败，请检查代码、登录邮箱和网络后重试。';
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
    DateTime? businessDate,
  }) {
    final sizeClass = ResponsiveBreakpoints.classify(
      MediaQuery.sizeOf(context).width,
    );
    final form = _WorkspaceCaseCommandForm(
      mode: mode,
      learningCase: learningCase,
      repository: widget.repository,
      businessDate: businessDate,
    );
    return sizeClass == WindowSizeClass.compact
        ? showModalBottomSheet<CaseCommandReceipt>(
            context: context,
            isScrollControlled: true,
            isDismissible: false,
            enableDrag: false,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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

  Future<CaseCommandReceipt?> _showReopenForm({
    required WorkspaceCase learningCase,
    DateTime? businessDate,
    String? draftScopeKey,
  }) {
    final sizeClass = ResponsiveBreakpoints.classify(
      MediaQuery.sizeOf(context).width,
    );
    final form = _WorkspaceReopenCaseForm(
      learningCase: learningCase,
      repository: widget.repository,
      businessDate: businessDate,
      draftStore:
          widget.caseReopenDraftStore ?? const NoopCaseReopenDraftStore(),
      draftScopeKey: draftScopeKey,
    );
    return sizeClass == WindowSizeClass.compact
        ? showModalBottomSheet<CaseCommandReceipt>(
            context: context,
            isScrollControlled: true,
            isDismissible: false,
            enableDrag: false,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
    final workspace = await _workspaceFuture;
    if (!mounted) {
      return;
    }
    final result = await _showCaseForm(
      mode: mode,
      learningCase: learningCase,
      businessDate: workspace.businessDate,
    );
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

  Future<void> _showStabilizeCase(
    WorkspaceStudent student,
    WorkspaceCase learningCase,
  ) async {
    final workspace = await _workspaceFuture;
    if (!mounted) {
      return;
    }
    final result = await _showCaseForm(
      mode: _CaseCommandMode.stabilize,
      learningCase: learningCase,
      businessDate: workspace.businessDate,
    );
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

  Future<void> _showReopenCase(
    WorkspaceStudent student,
    WorkspaceCase learningCase,
  ) async {
    final workspace = await _workspaceFuture;
    if (!mounted) {
      return;
    }
    final result = await _showReopenForm(
      learningCase: learningCase,
      businessDate: workspace.businessDate,
      draftScopeKey: _caseReopenDraftScopeKey(
        sessionUserId: widget.sessionUserId,
        organizationId: workspace.organizationId,
        caseId: learningCase.id,
      ),
    );
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

  Future<void> _closeCase(
    WorkspaceStudent student,
    WorkspaceCase learningCase,
  ) async {
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关闭 Case？'),
        content: const Text('关闭后不再列入当前待跟进事项，但历史记录会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    if (!mounted || shouldClose != true) {
      return;
    }

    final retryKey = _closeRetryKeyFor(learningCase);
    try {
      final receipt = await widget.repository.closeCase(
        CloseCaseCommand(
          operationId: _operationIdForRetry(retryKey),
          caseId: learningCase.id,
          expectedCaseVersion: learningCase.version,
          closedAt: null,
        ),
      );
      if (!mounted) {
        return;
      }
      await _reload(preserveStudent: student, preserveCaseId: learningCase.id);
      if (!mounted) {
        return;
      }
      _clearRetry(retryKey);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已保存，Case 进入${_caseStatusLabelFromWire(receipt.status)}。',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_describeCaseCommandError(error))));
    }
  }

  Future<void> _rescheduleAction(
    TeacherWorkspace workspace,
    WorkspaceActionWithContext item,
  ) async {
    if (_reschedulingActionId != null) {
      return;
    }

    final businessNow = workspace.businessDate ?? DateTime.now();
    final today = DateTime(
      businessNow.year,
      businessNow.month,
      businessNow.day,
    );
    final lastDate = DateTime(today.year + 2, today.month, today.day);
    final existing =
        item.action.businessDueDate ?? item.action.dueAt?.toLocal();
    final existingDate = existing == null
        ? null
        : DateTime(existing.year, existing.month, existing.day);
    final initialDate = existingDate == null || existingDate.isBefore(today)
        ? today
        : existingDate.isAfter(lastDate)
        ? lastDate
        : existingDate;
    final picked = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: lastDate,
      initialDate: initialDate,
      helpText: item.action.dueAt == null ? '安排行动日期' : '改期行动',
      confirmText: '保存',
    );
    if (!mounted || picked == null) {
      return;
    }

    final retryKey = _rescheduleRetryKeyFor(item, picked);
    setState(() {
      _reschedulingActionId = item.action.id;
    });
    try {
      await widget.repository.rescheduleCaseAction(
        RescheduleCaseActionCommand(
          operationId: _operationIdForRetry(retryKey),
          actionId: item.action.id,
          caseId: item.learningCase.id,
          expectedCaseVersion: item.learningCase.version,
          expectedActionVersion: item.action.version,
          dueOn: DateTime(picked.year, picked.month, picked.day),
        ),
      );
      if (!mounted) {
        return;
      }
      await _reload();
      if (!mounted) {
        return;
      }
      _clearRetry(retryKey);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('行动已安排在${_formatDateOnly(picked)}。')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_describeCaseCommandError(error))));
    } finally {
      if (mounted) {
        setState(() {
          _reschedulingActionId = null;
        });
      }
    }
  }

  Future<void> _completeAction(
    TeacherWorkspace workspace,
    WorkspaceActionWithContext item,
  ) async {
    if (_completingActionId != null) {
      return;
    }
    setState(() => _completingActionId = item.action.id);
    try {
      final result = await _showCompleteActionForm(
        item: item,
        businessDate: workspace.businessDate,
      );
      if (!mounted || result == null) {
        return;
      }
      if (!await _reload()) {
        return;
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('行动已完成，并已安排下一步。')));
    } finally {
      if (mounted) {
        setState(() => _completingActionId = null);
      }
    }
  }

  Future<CaseCommandReceipt?> _showCompleteActionForm({
    required WorkspaceActionWithContext item,
    required DateTime? businessDate,
  }) {
    final sizeClass = ResponsiveBreakpoints.classify(
      MediaQuery.sizeOf(context).width,
    );
    final form = _WorkspaceCompleteActionForm(
      action: item.action,
      learningCase: item.learningCase,
      repository: widget.repository,
      businessDate: businessDate,
    );
    return sizeClass == WindowSizeClass.compact
        ? showModalBottomSheet<CaseCommandReceipt>(
            context: context,
            isScrollControlled: true,
            isDismissible: false,
            enableDrag: false,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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

  @override
  Widget build(BuildContext context) {
    final workspace = _lastWorkspace;
    if (workspace != null) {
      return Stack(
        children: [
          _buildLoadedWorkspace(workspace),
          if (_isRefreshing)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      );
    }

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
              title: '暂时无法加载工作台',
              message: _describeWorkspaceLoadError(snapshot.error),
              onRetry: () => _reload(),
            ),
          );
        }
        return _buildLoadedWorkspace(snapshot.data!);
      },
    );
  }

  Widget _buildLoadedWorkspace(TeacherWorkspace workspace) {
    if (!workspace.hasTeachingAccess && !workspace.canManageOrganization) {
      if (workspace.canManageCaseTypes && workspace.organizationId != null) {
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
      return _WorkspaceStatusScaffold(
        title: '教师工作台',
        child: _WorkspaceNoAccessBody(
          invitationAcceptanceCard: _buildInvitationAcceptanceCard(),
        ),
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
        hasTeachingAccess: workspace.hasTeachingAccess,
        showManagement: workspace.canManageOrganization,
        onSignOut: widget.onSignOut,
        onCheckForUpdates:
            widget.updateService == null || widget.updateInstaller == null
            ? null
            : () => unawaited(_checkForUpdates()),
        checkingForUpdates: _checkingForUpdates,
        child: ResponsiveLayout(
          builder: (context, sizeClass) => _WorkspaceFrame(
            sizeClass: sizeClass,
            child: _buildCurrentPage(workspace, sizeClass),
          ),
        ),
      ),
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
    final managementIndex = workspace.hasTeachingAccess ? 2 : 0;
    if (workspace.canManageOrganization && _selectedIndex == managementIndex) {
      return _buildManagement(workspace);
    }
    if (!workspace.hasTeachingAccess) {
      return _WorkspaceNoAccessBody(
        invitationAcceptanceCard: _buildInvitationAcceptanceCard(),
      );
    }
    return _selectedIndex == 0
        ? _buildToday(workspace)
        : _buildStudents(workspace);
  }

  Widget _buildManagement(TeacherWorkspace workspace) {
    final organizationId = workspace.organizationId;
    final managementRepository = widget.managementRepository;
    if (organizationId == null || managementRepository == null) {
      return const _WorkspaceManagementUnavailable();
    }
    return OrganizationManagementPage(
      repository: managementRepository,
      provisioningRepository: widget.memberProvisioningRepository,
      organizationId: organizationId,
      organizationName: workspace.organizationName,
      roles: workspace.roles,
      canManageCaseTypes: workspace.canManageCaseTypes,
      onOpenCaseTypes: workspace.canManageCaseTypes
          ? () => unawaited(_showCaseTypeManager())
          : null,
      onChanged: () => unawaited(_reload()),
    );
  }

  Widget? _buildInvitationAcceptanceCard() {
    if (widget.invitationAcceptanceRepository == null) {
      return null;
    }
    return OrganizationInvitationAcceptanceCard(
      formKey: _invitationFormKey,
      inviteCodeController: _inviteCodeController,
      displayNameController: _displayNameController,
      busy: _invitationBusy,
      initiallyExpanded: true,
      errorMessage: _invitationErrorMessage,
      onAccept: _acceptInvitation,
    );
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
    final recentStudents = _studentsByRecentActivity(workspace.students);

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
                icon: Icon(Icons.category_outlined),
                label: const Text('问题类型'),
              ),
            FilledButton.icon(
              onPressed: () => _showQuickCapture(),
              icon: Icon(Icons.edit_note_outlined),
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
                  _WorkspaceSubheading(
                    label: '已逾期',
                    color: Theme.of(context).colorScheme.error,
                    icon: Icons.warning_amber_outlined,
                  ),
                  ..._buildActionRows(overdue, workspace),
                ],
                if (today.isNotEmpty) ...[
                  if (overdue.isNotEmpty) const Divider(height: AppSpacing.lg),
                  _WorkspaceSubheading(
                    label: '今天到期',
                    color: Theme.of(context).colorScheme.secondary,
                    icon: Icons.today_outlined,
                  ),
                  ..._buildActionRows(today, workspace),
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
            child: Column(children: _buildActionRows(future, workspace)),
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
              : Column(children: _buildActionRows(undated, workspace)),
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
              for (final student in recentStudents.take(5))
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
    return actions.where((item) => item.action.bucket == bucket).toList()
      ..sort(_compareActionsForToday);
  }

  int _compareActionsForToday(
    WorkspaceActionWithContext left,
    WorkspaceActionWithContext right,
  ) {
    final leftDueAt = left.action.businessDueDate ?? left.action.dueAt;
    final rightDueAt = right.action.businessDueDate ?? right.action.dueAt;
    final dueAtComparison = switch ((leftDueAt, rightDueAt)) {
      (final DateTime leftDate, final DateTime rightDate) => leftDate.compareTo(
        rightDate,
      ),
      (null, final DateTime _) => 1,
      (final DateTime _, null) => -1,
      (null, null) => 0,
    };
    if (dueAtComparison != 0) {
      return dueAtComparison;
    }

    final studentComparison = left.student.name.compareTo(right.student.name);
    if (studentComparison != 0) {
      return studentComparison;
    }
    final subjectComparison = left.student.subject.compareTo(
      right.student.subject,
    );
    if (subjectComparison != 0) {
      return subjectComparison;
    }
    final caseComparison = left.learningCase.title.compareTo(
      right.learningCase.title,
    );
    if (caseComparison != 0) {
      return caseComparison;
    }
    return left.action.id.compareTo(right.action.id);
  }

  List<WorkspaceStudent> _studentsByRecentActivity(
    Iterable<WorkspaceStudent> students,
  ) {
    return students.toList()..sort((left, right) {
      final leftOccurredAt = _latestActivityAt(left);
      final rightOccurredAt = _latestActivityAt(right);
      final activityComparison = switch ((leftOccurredAt, rightOccurredAt)) {
        (final DateTime leftDate, final DateTime rightDate) =>
          rightDate.compareTo(leftDate),
        (null, final DateTime _) => 1,
        (final DateTime _, null) => -1,
        (null, null) => 0,
      };
      if (activityComparison != 0) {
        return activityComparison;
      }

      final nameComparison = left.name.compareTo(right.name);
      if (nameComparison != 0) {
        return nameComparison;
      }
      final subjectComparison = left.subject.compareTo(right.subject);
      if (subjectComparison != 0) {
        return subjectComparison;
      }
      return left.profileId.compareTo(right.profileId);
    });
  }

  DateTime? _latestActivityAt(WorkspaceStudent student) {
    DateTime? latest;
    for (final fact in student.recentFacts) {
      if (latest == null || fact.occurredAt.isAfter(latest)) {
        latest = fact.occurredAt;
      }
    }
    return latest;
  }

  List<Widget> _buildActionRows(
    List<WorkspaceActionWithContext> items,
    TeacherWorkspace workspace,
  ) {
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
          onReschedule: (item) => _rescheduleAction(workspace, item),
          onComplete: (item) => _completeAction(workspace, item),
          reschedulingActionId: _reschedulingActionId,
          completingActionId: _completingActionId,
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
                    icon: Icon(Icons.category_outlined),
                    label: const Text('问题类型'),
                  ),
                FilledButton.icon(
                  onPressed: () => _showQuickCapture(),
                  icon: Icon(Icons.edit_note_outlined),
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
    final importantCases = _importantCasesForStudent(student);
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
            icon: Icon(Icons.arrow_back),
          ),
          actions: [
            FilledButton.icon(
              onPressed: () => _showQuickCapture(student: student),
              icon: Icon(Icons.edit_note_outlined),
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

  List<WorkspaceCase> _importantCasesForStudent(WorkspaceStudent student) {
    final cases =
        student.cases
            .where(
              (learningCase) =>
                  learningCase.status != LearningCaseStatus.closed,
            )
            .toList()
          ..sort(_compareCasesForStudentDetail);
    return cases.take(3).toList();
  }

  int _compareCasesForStudentDetail(WorkspaceCase left, WorkspaceCase right) {
    final attentionComparison = _caseAttentionRank(left)
        .compareTo(_caseAttentionRank(right));
    if (attentionComparison != 0) {
      return attentionComparison;
    }

    final leftAction = left.primaryAction;
    final rightAction = right.primaryAction;
    final leftDueAt = leftAction?.businessDueDate ?? leftAction?.dueAt;
    final rightDueAt = rightAction?.businessDueDate ?? rightAction?.dueAt;
    final dueAtComparison = switch ((leftDueAt, rightDueAt)) {
      (final DateTime leftDate, final DateTime rightDate) => leftDate.compareTo(
        rightDate,
      ),
      (null, final DateTime _) => 1,
      (final DateTime _, null) => -1,
      (null, null) => 0,
    };
    if (dueAtComparison != 0) {
      return dueAtComparison;
    }

    final priorityComparison = _casePriorityRank(left.priority)
        .compareTo(_casePriorityRank(right.priority));
    if (priorityComparison != 0) {
      return priorityComparison;
    }

    final observedAtComparison = left.firstObservedAt.compareTo(
      right.firstObservedAt,
    );
    if (observedAtComparison != 0) {
      return observedAtComparison;
    }
    final titleComparison = left.title.compareTo(right.title);
    if (titleComparison != 0) {
      return titleComparison;
    }
    return left.id.compareTo(right.id);
  }

  int _caseAttentionRank(WorkspaceCase learningCase) {
    if (learningCase.status == LearningCaseStatus.pendingVerification) {
      return 2;
    }
    final action = learningCase.primaryAction;
    if (action != null) {
      return switch (action.bucket) {
        WorkspaceActionBucket.overdue => 0,
        WorkspaceActionBucket.today => 1,
        WorkspaceActionBucket.undated => 4,
        WorkspaceActionBucket.future => 5,
      };
    }
    if (learningCase.status == LearningCaseStatus.newCase) {
      return 3;
    }
    return 6;
  }

  int _casePriorityRank(String priority) {
    return switch (priority) {
      'high' => 0,
      'low' => 2,
      _ => 1,
    };
  }

  Widget _buildCaseDetail(
    WorkspaceStudent student,
    WorkspaceCase learningCase,
  ) {
    final primaryAction = learningCase.primaryAction;
    final commandLabel = _caseCommandLabel(learningCase);
    final canStabilize = _canStabilizeCase(learningCase);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorkspacePageHeader(
          title: learningCase.title,
          subtitle: '${student.name} · ${student.subject}',
          leading: IconButton(
            tooltip: '返回学生详情',
            onPressed: _goBack,
            icon: Icon(Icons.arrow_back),
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
        if (canStabilize) ...[
          const SizedBox(height: AppSpacing.md),
          _WorkspaceCaseCommandSection(
            title: '确认 Case 已稳定',
            message: '最新验证结果为通过。确认稳定后会安排一次复查，Case 仍可继续保留历史。',
            buttonLabel: '标记为稳定',
            onPressed: () => _showStabilizeCase(student, learningCase),
          ),
        ],
        if (learningCase.status == LearningCaseStatus.stable) ...[
          const SizedBox(height: AppSpacing.md),
          _WorkspaceCaseCommandSection(
            title: '关闭 Case',
            message: '确认问题已经收口后再关闭；关闭会保留历史，但不再列入当前待跟进事项。',
            buttonLabel: '关闭 Case',
            onPressed: () => _closeCase(student, learningCase),
          ),
        ],
        if (learningCase.status == LearningCaseStatus.closed) ...[
          const SizedBox(height: AppSpacing.md),
          _WorkspaceCaseCommandSection(
            title: '记录复发并重新打开',
            message: '只有关闭后的新 Evidence 才能重新打开；系统会保留原来的关闭历史。',
            buttonLabel: '记录复发并重新打开',
            onPressed: () => _showReopenCase(student, learningCase),
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

class _WorkspaceReopenCaseForm extends StatefulWidget {
  const _WorkspaceReopenCaseForm({
    required this.learningCase,
    required this.repository,
    required this.draftStore,
    this.businessDate,
    this.draftScopeKey,
  });

  final WorkspaceCase learningCase;
  final LearningRepository repository;
  final CaseReopenDraftStore draftStore;
  final DateTime? businessDate;
  final String? draftScopeKey;

  @override
  State<_WorkspaceReopenCaseForm> createState() =>
      _WorkspaceReopenCaseFormState();
}

class _WorkspaceReopenCaseFormState extends State<_WorkspaceReopenCaseForm> {
  static const Map<String, String> _sourceTypeLabels = <String, String>{
    'observation': '课堂观察',
    'homework': '作业',
    'quiz': '小测',
    'exam': '考试',
    'essay': '作文',
    'classwork': '课堂练习',
    'guardian_report': '家长反馈',
    'other': '其他',
  };

  late final TextEditingController _evidenceTitleController;
  late final TextEditingController _evidenceSummaryController;
  late final TextEditingController _nextActionController;
  late String _evidenceOperationId;
  late String _reopenOperationId;
  late int _expectedCaseVersion;

  String _sourceType = 'observation';
  CaseActionType _nextActionType = CaseActionType.verify;
  DateTime _observedAt = DateTime.now();
  DateTime? _nextActionDueOn;
  String? _evidenceId;
  int _evidenceVersion = 1;
  String? _evidenceTitleError;
  String? _evidenceSummaryError;
  String? _nextActionError;
  String? _saveError;
  bool _submissionStarted = false;
  bool _saving = false;
  bool _restoring = false;
  bool _draftStorageFailed = false;

  bool get _inputsLocked =>
      _restoring || _draftStorageFailed || _submissionStarted;
  bool get _isDirty =>
      _submissionStarted ||
      _evidenceTitleController.text.trim().isNotEmpty ||
      _evidenceSummaryController.text.trim().isNotEmpty ||
      _nextActionController.text.trim() != '复发后安排验证' ||
      _nextActionDueOn != null ||
      _sourceType != 'observation';

  @override
  void initState() {
    super.initState();
    _evidenceOperationId = createOperationId();
    _reopenOperationId = createOperationId();
    _expectedCaseVersion = widget.learningCase.version;
    _evidenceTitleController = TextEditingController();
    _evidenceSummaryController = TextEditingController();
    _nextActionController = TextEditingController(text: '复发后安排验证');
    _evidenceTitleController.addListener(_clearInlineErrors);
    _evidenceSummaryController.addListener(_clearInlineErrors);
    _nextActionController.addListener(_clearInlineErrors);
    _restoring = widget.draftScopeKey != null;
    if (_restoring) {
      unawaited(_restoreDraft());
    }
  }

  Future<void> _restoreDraft() async {
    final scopeKey = widget.draftScopeKey;
    if (scopeKey == null) {
      return;
    }
    try {
      final draft = await widget.draftStore.load(scopeKey);
      if (!mounted) {
        return;
      }
      if (draft != null) {
        if (draft.caseId != widget.learningCase.id) {
          throw const FormatException(
            'Persisted case reopen draft targets a different Case.',
          );
        }
        _evidenceOperationId = draft.evidenceOperationId;
        _reopenOperationId = draft.reopenOperationId;
        _expectedCaseVersion = draft.expectedCaseVersion;
        _sourceType = draft.sourceType;
        _evidenceTitleController.text = draft.evidenceTitle;
        _evidenceSummaryController.text = draft.evidenceSummary;
        _observedAt = draft.observedAt;
        _evidenceId = draft.evidenceId;
        _evidenceVersion = draft.evidenceVersion;
        _nextActionType = CaseActionType.values.firstWhere(
          (type) => type.wireValue == draft.nextActionTypeWire,
          orElse: () => CaseActionType.other,
        );
        _nextActionController.text = draft.nextActionTitle;
        _nextActionDueOn = draft.nextActionDueOn;
      }
      setState(() {
        _restoring = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _restoring = false;
        _draftStorageFailed = true;
        _saveError = '无法安全恢复未完成的复发记录。为避免重复提交，暂不能保存；可以关闭窗口后重试。';
      });
    }
  }

  CaseReopenDraft _draftFromForm() {
    return CaseReopenDraft(
      schemaVersion: CaseReopenDraft.currentSchemaVersion,
      caseId: widget.learningCase.id,
      expectedCaseVersion: _expectedCaseVersion,
      evidenceOperationId: _evidenceOperationId,
      reopenOperationId: _reopenOperationId,
      sourceType: _sourceType,
      evidenceTitle: _evidenceTitleController.text.trim(),
      evidenceSummary: _evidenceSummaryController.text.trim(),
      observedAt: _observedAt,
      evidenceId: _evidenceId,
      evidenceVersion: _evidenceVersion,
      nextActionTypeWire: _nextActionType.wireValue,
      nextActionTitle: _nextActionController.text.trim(),
      nextActionDueOn: _nextActionDueOn,
    );
  }

  Future<void> _persistDraft() async {
    final scopeKey = widget.draftScopeKey;
    if (scopeKey == null) {
      return;
    }
    await widget.draftStore.save(scopeKey, _draftFromForm());
  }

  Future<void> _clearPersistedDraft() async {
    final scopeKey = widget.draftScopeKey;
    if (scopeKey == null) {
      return;
    }
    try {
      await widget.draftStore.clear(scopeKey);
    } catch (_) {
      // A committed reopen is safe to retry with the same operation ID.
      // Keeping the draft is safer than masking a successful server result.
    }
  }

  @override
  void dispose() {
    _evidenceTitleController
      ..removeListener(_clearInlineErrors)
      ..dispose();
    _evidenceSummaryController
      ..removeListener(_clearInlineErrors)
      ..dispose();
    _nextActionController
      ..removeListener(_clearInlineErrors)
      ..dispose();
    super.dispose();
  }

  void _clearInlineErrors() {
    if (!mounted) {
      return;
    }
    final titleReady =
        _evidenceTitleError != null &&
        _evidenceTitleController.text.trim().isNotEmpty;
    final summaryReady =
        _evidenceSummaryError != null &&
        _evidenceSummaryController.text.trim().isNotEmpty;
    final actionReady =
        _nextActionError != null &&
        _nextActionController.text.trim().isNotEmpty;
    if (titleReady || summaryReady || actionReady) {
      setState(() {
        if (titleReady) {
          _evidenceTitleError = null;
        }
        if (summaryReady) {
          _evidenceSummaryError = null;
        }
        if (actionReady) {
          _nextActionError = null;
        }
      });
    }
  }

  Future<void> _pickObservedAt() async {
    if (_inputsLocked) {
      return;
    }
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(
        _observedAt.year,
        _observedAt.month,
        _observedAt.day,
      ),
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: '选择实际观察日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (!mounted || pickedDate == null) {
      return;
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_observedAt),
      helpText: '选择实际观察时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (!mounted || pickedTime == null) {
      return;
    }
    setState(() {
      _observedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _pickDueDate() async {
    if (_inputsLocked) {
      return;
    }
    final businessNow = widget.businessDate ?? DateTime.now();
    final today = DateTime(
      businessNow.year,
      businessNow.month,
      businessNow.day,
    );
    final selected = await showDatePicker(
      context: context,
      initialDate: _nextActionDueOn ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 2, 12, 31),
      helpText: '选择下一行动日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _nextActionDueOn = DateTime(selected.year, selected.month, selected.day);
      if (_nextActionType == CaseActionType.review) {
        _nextActionError = null;
      }
    });
  }

  Future<void> _save() async {
    if (_saving || _restoring || _draftStorageFailed) {
      return;
    }
    final title = _evidenceTitleController.text.trim();
    final summary = _evidenceSummaryController.text.trim();
    final nextActionTitle = _nextActionController.text.trim();
    var valid = true;
    if (title.isEmpty) {
      _evidenceTitleError = '请写下这次复发证据的标题';
      valid = false;
    }
    if (summary.isEmpty) {
      _evidenceSummaryError = '请写下可观察到的复发表现';
      valid = false;
    }
    if (nextActionTitle.isEmpty) {
      _nextActionError = '请保留或改写下一行动';
      valid = false;
    }
    if (_nextActionType == CaseActionType.review && _nextActionDueOn == null) {
      _nextActionError = '复查行动需要安排日期';
      valid = false;
    }
    if (!valid) {
      setState(() {});
      return;
    }

    try {
      await _persistDraft();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saveError = '无法安全保存恢复记录，未提交到服务器。请重试或关闭窗口后再试。';
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _submissionStarted = true;
      _saving = true;
      _saveError = null;
    });
    try {
      if (_evidenceId == null) {
        final evidenceReceipt = await widget.repository.addCaseEvidence(
          AddCaseEvidenceCommand(
            operationId: _evidenceOperationId,
            caseId: widget.learningCase.id,
            expectedCaseVersion: _expectedCaseVersion,
            sourceType: _sourceType,
            title: title,
            observedAt: _observedAt,
            summary: summary,
          ),
        );
        final evidenceId = evidenceReceipt.recordId;
        if (evidenceId == null || evidenceId.trim().isEmpty) {
          throw const FormatException(
            'add_case_evidence returned no evidence id.',
          );
        }
        if (!mounted) {
          return;
        }
        setState(() {
          _evidenceId = evidenceId;
          _evidenceVersion = 1;
        });
        try {
          await _persistDraft();
        } catch (error) {
          throw _CaseReopenDraftStorageException(error);
        }
      }
      final evidenceId = _evidenceId;
      if (evidenceId == null) {
        throw const FormatException('Missing committed Evidence id.');
      }
      final receipt = await widget.repository.reopenCase(
        ReopenCaseCommand(
          operationId: _reopenOperationId,
          caseId: widget.learningCase.id,
          expectedCaseVersion: _expectedCaseVersion,
          recurrenceEvidenceIds: <String>[evidenceId],
          expectedEvidenceVersions: <String, int>{evidenceId: _evidenceVersion},
          nextActionType: _nextActionType,
          nextActionTitle: nextActionTitle,
          nextActionDueOn: _nextActionDueOn,
        ),
      );
      await _clearPersistedDraft();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(receipt);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final hasCommittedEvidence = _evidenceId != null;
      final unknownResult = _isUnknownResultFailure(error);
      final saveError = error is _CaseReopenDraftStorageException
          ? hasCommittedEvidence
                ? 'Evidence 已保存，但恢复记录暂时无法保存。请保持页面打开并重试。'
                : '无法安全保存恢复记录，未提交到服务器。请重试。'
          : _describeCaseCommandError(error);
      setState(() {
        _saving = false;
        _saveError = saveError;
        if (!unknownResult && !hasCommittedEvidence) {
          _submissionStarted = false;
        }
      });
    }
  }

  Future<void> _confirmDiscard() async {
    if (_submissionStarted || _saving || _restoring) {
      return;
    }
    if (!_isDirty) {
      await _clearPersistedDraft();
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃这次复发记录？'),
        content: const Text('当前输入还没有保存。放弃后不会产生新的 Evidence。'),
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
      await _clearPersistedDraft();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final caseContext =
        '${widget.learningCase.typeLabel} · ${widget.learningCase.status.label} · version ${widget.learningCase.version}';
    return PopScope<void>(
      canPop: !_restoring && !_submissionStarted && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_restoring && !_submissionStarted && !_saving) {
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
                          '记录复发并重新打开',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: _restoring || _submissionStarted || _saving
                            ? null
                            : _confirmDiscard,
                        icon: Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '提交前会保存安全恢复记录；两步可安全重试，退出应用后也会保留未完成进度。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _WorkspaceContextLine(label: '当前 Case', value: caseContext),
                  const SizedBox(height: AppSpacing.md),
                  if (_restoring)
                    const Text('正在恢复未完成的复发记录…'),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _sourceType,
                    decoration: const InputDecoration(labelText: '证据来源 *'),
                    items: [
                      for (final entry in _sourceTypeLabels.entries)
                        DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: _inputsLocked
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _sourceType = value);
                            }
                          },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('reopen-evidence-title'),
                    controller: _evidenceTitleController,
                    autofocus: true,
                    enabled: !_inputsLocked,
                    decoration: InputDecoration(
                      labelText: '复发证据标题 *',
                      hintText: '例如：关闭后再次跳过通分步骤',
                      errorText: _evidenceTitleError,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('reopen-evidence-summary'),
                    controller: _evidenceSummaryController,
                    enabled: !_inputsLocked,
                    minLines: 3,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: '可观察表现 *',
                      hintText: '写下这次实际看到的复发，而不是只写“又出现了”',
                      errorText: _evidenceSummaryError,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _inputsLocked ? null : _pickObservedAt,
                    icon: Icon(Icons.schedule_outlined),
                    label: Text(
                      '观察时间：${_formatDateTimeForReopen(_observedAt)}',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<CaseActionType>(
                    initialValue: _nextActionType,
                    decoration: const InputDecoration(labelText: '重新打开后的行动类型'),
                    items: [
                      for (final type in CaseActionType.values)
                        DropdownMenuItem<CaseActionType>(
                          value: type,
                          child: Text(type.label),
                        ),
                    ],
                    onChanged: _inputsLocked
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _nextActionType = value;
                                if (value != CaseActionType.review) {
                                  _nextActionError = null;
                                }
                              });
                            }
                          },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('reopen-next-action'),
                    controller: _nextActionController,
                    enabled: !_inputsLocked,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: '重新打开后的下一行动 *',
                      hintText: '例如：复核复发原因并安排验证',
                      errorText: _nextActionError,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _inputsLocked ? null : _pickDueDate,
                          icon: Icon(Icons.event_outlined),
                          label: Text(
                            _nextActionDueOn == null
                                ? _nextActionType == CaseActionType.review
                                      ? '安排日期（必选）'
                                      : '安排日期（可选）'
                                : '行动日期：${_formatDateOnly(_nextActionDueOn!)}',
                          ),
                        ),
                      ),
                      if (_nextActionDueOn != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        IconButton(
                          tooltip: '清除日期',
                          onPressed: _inputsLocked
                              ? null
                              : () => setState(() => _nextActionDueOn = null),
                          icon: Icon(Icons.close),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '服务器会把观察时间和最新关闭边界比较；提交开始后输入会锁定，重试沿用原 operation ID。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_evidenceId != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Evidence 已保存，正在等待重新打开；请继续重试完成第二步。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                  if (_saveError != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _WorkspaceErrorText(message: _saveError!),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _restoring || _submissionStarted || _saving
                              ? null
                              : _confirmDiscard,
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving || _restoring || _draftStorageFailed ? null : _save,
                          child: Text(
                            _saving
                                ? '保存中…'
                                : _evidenceId == null
                                ? '保存 Evidence'
                                : '重新打开 Case',
                          ),
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

enum _CaseCommandMode { confirm, intervention, assessment, stabilize }

class _WorkspaceCaseCommandForm extends StatefulWidget {
  const _WorkspaceCaseCommandForm({
    required this.mode,
    required this.learningCase,
    required this.repository,
    this.businessDate,
  });

  final _CaseCommandMode mode;
  final WorkspaceCase learningCase;
  final LearningRepository repository;
  final DateTime? businessDate;

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
    _CaseCommandMode.stabilize => '安排一次复查',
  };

  String get _title => switch (widget.mode) {
    _CaseCommandMode.confirm => '确认 Case',
    _CaseCommandMode.intervention => '记录教学动作',
    _CaseCommandMode.assessment => '记录验证结果',
    _CaseCommandMode.stabilize => '确认 Case 已稳定',
  };

  String get _subtitle => switch (widget.mode) {
    _CaseCommandMode.confirm => '把原始观察转成一个可执行的学习问题，并安排下一步。',
    _CaseCommandMode.intervention => '记录这次实际做了什么；保存后系统会生成 verify action。',
    _CaseCommandMode.assessment => '记录本次检查看到的结果；不要用结果直接替代后续教师判断。',
    _CaseCommandMode.stabilize => '最新验证已经通过；确认稳定后会安排一次复查，不会删除历史记录。',
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
    final businessNow = widget.businessDate ?? DateTime.now();
    final today = DateTime(
      businessNow.year,
      businessNow.month,
      businessNow.day,
    );
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
      } else if (widget.mode == _CaseCommandMode.stabilize) {
        receipt = await widget.repository.stabilizeCase(
          StabilizeCaseCommand(
            operationId: _operationId,
            caseId: widget.learningCase.id,
            expectedCaseVersion: widget.learningCase.version,
            stabilizedAt: null,
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
                        icon: Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
                  if (widget.mode == _CaseCommandMode.intervention ||
                      widget.mode == _CaseCommandMode.assessment) ...[
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
                          icon: Icon(Icons.event_outlined),
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
                          icon: Icon(Icons.close),
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

  bool _isCompact(BuildContext context) =>
      ResponsiveBreakpoints.classify(MediaQuery.sizeOf(context).width) ==
      WindowSizeClass.compact;

  Widget _buildStudentField(BuildContext context) {
    if (!_isCompact(context)) {
      return DropdownButtonFormField<WorkspaceStudent>(
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
              child: Text([student.name, student.subject].join(' · ')),
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
      );
    }

    final student = _selectedStudent;
    return _WorkspaceChoiceField(
      fieldKey: const Key('quick-capture-student-picker'),
      label: '学生 *',
      value: student == null
          ? '请选择学生'
          : [student.name, student.subject].join(' · '),
      errorText: _studentError,
      onTap: _saving ? null : _openStudentPicker,
    );
  }

  Widget _buildCaseTypeField(BuildContext context) {
    if (!_isCompact(context)) {
      return DropdownButtonFormField<String>(
        key: const Key('quick-capture-case-type-dropdown'),
        initialValue: _selectedCaseTypeKey,
        decoration: const InputDecoration(labelText: '问题类型'),
        items: [
          for (final type in _caseTypeOptions)
            DropdownMenuItem<String>(value: type.key, child: Text(type.label)),
        ],
        onChanged: _saving
            ? null
            : (typeKey) {
                if (typeKey != null) {
                  setState(() => _selectedCaseTypeKey = typeKey);
                }
              },
      );
    }

    return _WorkspaceChoiceField(
      fieldKey: const Key('quick-capture-case-type-dropdown'),
      label: '问题类型',
      value: _selectedCaseType.label,
      onTap: _saving ? null : _openCaseTypePicker,
    );
  }

  Future<void> _openStudentPicker() async {
    if (_saving || widget.students.isEmpty) {
      return;
    }
    final selectedStudent = await showModalBottomSheet<WorkspaceStudent>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _WorkspaceChoiceSheet<WorkspaceStudent>(
        title: '选择学生',
        selectedValue: _selectedStudent,
        options: [
          for (final student in widget.students)
            _WorkspaceChoiceOption<WorkspaceStudent>(
              key: ValueKey<String>(
                'quick-capture-student-option-${student.id}',
              ),
              value: student,
              title: [student.name, student.subject].join(' · '),
            ),
        ],
      ),
    );
    if (!mounted || selectedStudent == null) {
      return;
    }
    setState(() {
      _selectedStudent = selectedStudent;
      _studentError = null;
    });
  }

  Future<void> _openCaseTypePicker() async {
    if (_saving) {
      return;
    }
    final selectedTypeKey = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _WorkspaceChoiceSheet<String>(
        title: '选择问题类型',
        selectedValue: _selectedCaseTypeKey,
        options: [
          for (final type in _caseTypeOptions)
            _WorkspaceChoiceOption<String>(
              key: ValueKey<String>(
                'quick-capture-case-type-option-${type.key}',
              ),
              value: type.key,
              title: type.label,
              subtitle: type.isBuiltIn
                  ? '系统类型'
                  : '自定义类型 · ${type.baseType.label}',
            ),
        ],
      ),
    );
    if (!mounted || selectedTypeKey == null) {
      return;
    }
    setState(() => _selectedCaseTypeKey = selectedTypeKey);
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
                        icon: Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '先记录一条真实观察；保存后 Case 会保持“待整理”，不会自动跳过教师判断。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildStudentField(context),
                  const SizedBox(height: AppSpacing.md),
                  _buildCaseTypeField(context),
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

class _WorkspaceChoiceOption<T> {
  const _WorkspaceChoiceOption({
    required this.key,
    required this.value,
    required this.title,
    this.subtitle,
  });

  final Key key;
  final T value;
  final String title;
  final String? subtitle;
}

class _WorkspaceChoiceSheet<T> extends StatelessWidget {
  const _WorkspaceChoiceSheet({
    required this.title,
    required this.options,
    required this.selectedValue,
    super.key,
  });

  final String title;
  final List<_WorkspaceChoiceOption<T>> options;
  final T? selectedValue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              for (final option in options)
                ListTile(
                  key: option.key,
                  selected: selectedValue == option.value,
                  selectedTileColor: colorScheme.secondaryContainer.withValues(
                    alpha: 0.34,
                  ),
                  title: Text(option.title),
                  subtitle: option.subtitle == null
                      ? null
                      : Text(option.subtitle!),
                  trailing: selectedValue == option.value
                      ? Icon(
                          Icons.check,
                          color: colorScheme.onSecondaryContainer,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(option.value),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceChoiceField extends StatelessWidget {
  const _WorkspaceChoiceField({
    required this.label,
    required this.value,
    required this.onTap,
    this.errorText,
    this.fieldKey,
  });

  final String label;
  final String value;
  final String? errorText;
  final VoidCallback? onTap;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final valueStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: onTap == null
          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.60)
          : colorScheme.onSurface,
    );
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      value: value,
      child: InkWell(
        key: fieldKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, errorText: errorText),
          child: Row(
            children: [
              Expanded(child: Text(value, style: valueStyle)),
              Icon(
                Icons.keyboard_arrow_down,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
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
    Navigator.of(context)
        .pop(_CaseTypeDraft(displayName: displayName, baseType: _baseType));
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
                _WorkspaceContextLine(label: '基础分类', value: _baseType.label),
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
        content: Text('归档后不能用于新记录，但已有“${caseType.label}”的问题历史仍会保留。'),
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
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.label_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
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
            Padding(
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
                        icon: Icon(Icons.close),
                      ),
                  ],
                ),
                Text(
                  '系统类型始终保留。自定义类型只负责分类，仍沿用同一套 Case、证据、行动和验证流程。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    icon: Icon(Icons.add),
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
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.arrow_circle_right_outlined,
            color: Theme.of(context).colorScheme.primary,
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
                  icon: Icon(Icons.arrow_forward, size: 18),
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
    required this.hasTeachingAccess,
    required this.showManagement,
    required this.child,
    this.onSignOut,
    this.onCheckForUpdates,
    this.checkingForUpdates = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool hasTeachingAccess;
  final bool showManagement;
  final Widget child;
  final VoidCallback? onSignOut;
  final VoidCallback? onCheckForUpdates;
  final bool checkingForUpdates;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      builder: (context, sizeClass) {
        if (sizeClass == WindowSizeClass.compact) {
          return Scaffold(
            appBar: AppBar(
              title: Text(hasTeachingAccess ? '教师工作台' : '机构管理'),
              actions: [
                if (onCheckForUpdates != null)
                  IconButton(
                    tooltip: '检查更新',
                    onPressed: checkingForUpdates ? null : onCheckForUpdates,
                    icon: checkingForUpdates
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update_alt),
                  ),
                if (onSignOut != null)
                  IconButton(
                    tooltip: '退出登录',
                    onPressed: onSignOut,
                    icon: Icon(Icons.logout),
                  ),
              ],
            ),
            body: SafeArea(child: child),
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: _workspaceDestinations(
                hasTeachingAccess: hasTeachingAccess,
                showManagement: showManagement,
              ),
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
                  hasTeachingAccess: hasTeachingAccess,
                  showManagement: showManagement,
                  onSignOut: onSignOut,
                  onCheckForUpdates: onCheckForUpdates,
                  checkingForUpdates: checkingForUpdates,
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
    required this.hasTeachingAccess,
    required this.showManagement,
    this.onSignOut,
    this.onCheckForUpdates,
    this.checkingForUpdates = false,
  });

  final bool extended;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool hasTeachingAccess;
  final bool showManagement;
  final VoidCallback? onSignOut;
  final VoidCallback? onCheckForUpdates;
  final bool checkingForUpdates;

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
                        hasTeachingAccess ? '教师工作台' : '机构管理',
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
              indicatorColor: Theme.of(context).colorScheme.primaryContainer,
              selectedIconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.primary,
              ),
              unselectedIconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              destinations: _workspaceRailDestinations(
                hasTeachingAccess: hasTeachingAccess,
                showManagement: showManagement,
              ),
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
                if (onCheckForUpdates != null)
                  IconButton(
                    tooltip: '检查更新',
                    onPressed: checkingForUpdates ? null : onCheckForUpdates,
                    icon: checkingForUpdates
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update_alt),
                  ),
                if (extended && onSignOut != null)
                  IconButton(
                    tooltip: '退出登录',
                    onPressed: onSignOut,
                    icon: Icon(Icons.logout),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<NavigationDestination> _workspaceDestinations({
  required bool hasTeachingAccess,
  required bool showManagement,
}) {
  return [
    if (hasTeachingAccess)
      const NavigationDestination(
        icon: Icon(Icons.today_outlined),
        selectedIcon: Icon(Icons.today),
        label: '今日',
      ),
    if (hasTeachingAccess)
      const NavigationDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: '学生',
      ),
    if (showManagement)
      const NavigationDestination(
        icon: Icon(Icons.admin_panel_settings_outlined),
        selectedIcon: Icon(Icons.admin_panel_settings),
        label: '管理',
      ),
  ];
}

List<NavigationRailDestination> _workspaceRailDestinations({
  required bool hasTeachingAccess,
  required bool showManagement,
}) {
  return [
    if (hasTeachingAccess)
      const NavigationRailDestination(
        icon: Icon(Icons.today_outlined),
        selectedIcon: Icon(Icons.today),
        label: Text('今日'),
      ),
    if (hasTeachingAccess)
      const NavigationRailDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: Text('学生'),
      ),
    if (showManagement)
      const NavigationRailDestination(
        icon: Icon(Icons.admin_panel_settings_outlined),
        selectedIcon: Icon(Icons.admin_panel_settings),
        label: Text('管理'),
      ),
  ];
}

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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
              Padding(
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
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
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
    required this.onReschedule,
    required this.onComplete,
    this.reschedulingActionId,
    this.completingActionId,
  });

  final WorkspaceStudent student;
  final List<WorkspaceActionWithContext> items;
  final ValueChanged<WorkspaceCase> onOpenCase;
  final Future<void> Function(WorkspaceActionWithContext item) onReschedule;
  final Future<void> Function(WorkspaceActionWithContext item) onComplete;
  final String? reschedulingActionId;
  final String? completingActionId;

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
                      Icon(Icons.arrow_forward_outlined, size: 21),
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
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (item.learningCase.status !=
                            LearningCaseStatus.newCase)
                          FilledButton.icon(
                            onPressed: completingActionId == item.action.id
                                ? null
                                : () => onComplete(item),
                            icon: const Icon(Icons.check),
                            label: const Text('完成行动'),
                          ),
                        OutlinedButton(
                          onPressed: () => onOpenCase(item.learningCase),
                          child: const Text('查看 Case'),
                        ),
                        TextButton.icon(
                          onPressed: reschedulingActionId == item.action.id
                              ? null
                              : () => onReschedule(item),
                          icon: const Icon(Icons.event_repeat_outlined),
                          label: Text(
                            item.action.dueAt == null ? '安排日期' : '改期',
                          ),
                        ),
                      ],
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

class _WorkspaceCompleteActionForm extends StatefulWidget {
  const _WorkspaceCompleteActionForm({
    required this.action,
    required this.learningCase,
    required this.repository,
    required this.businessDate,
  });

  final WorkspaceAction action;
  final WorkspaceCase learningCase;
  final LearningRepository repository;
  final DateTime? businessDate;

  @override
  State<_WorkspaceCompleteActionForm> createState() =>
      _WorkspaceCompleteActionFormState();
}

class _WorkspaceCompleteActionFormState
    extends State<_WorkspaceCompleteActionForm> {
  late final TextEditingController _nextActionController;
  late final String _operationId;
  late CaseActionType _nextActionType;
  late String _autoGeneratedNextActionTitle;
  DateTime? _nextActionDueOn;
  String? _nextActionError;
  String? _saveError;
  bool _saving = false;
  bool _submissionAttempted = false;
  CompleteCaseActionCommand? _submittedCommand;

  @override
  void initState() {
    super.initState();
    _operationId = createOperationId();
    _nextActionType = _defaultNextActionType(widget.action.actionType);
    _autoGeneratedNextActionTitle = _defaultNextActionTitle(_nextActionType);
    _nextActionController = TextEditingController(
      text: _autoGeneratedNextActionTitle,
    )..addListener(_clearInlineError);
  }

  @override
  void dispose() {
    _nextActionController
      ..removeListener(_clearInlineError)
      ..dispose();
    super.dispose();
  }

  bool get _isDirty =>
      _nextActionController.text.trim() !=
          _defaultNextActionTitle(_nextActionType) ||
      _nextActionDueOn != null;

  void _clearInlineError() {
    if (_nextActionError == null ||
        _nextActionController.text.trim().isEmpty ||
        !mounted) {
      return;
    }
    setState(() => _nextActionError = null);
  }

  Future<void> _pickDueDate() async {
    final businessNow = widget.businessDate ?? DateTime.now();
    final today = DateTime(
      businessNow.year,
      businessNow.month,
      businessNow.day,
    );
    final current = _nextActionDueOn ?? today;
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: today,
      lastDate: DateTime(today.year + 2, 12, 31),
      helpText: '选择下一行动日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      // Keep this as a calendar date; the repository serializes it without
      // applying the device time zone.
      _nextActionDueOn = DateTime(selected.year, selected.month, selected.day);
    });
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    if (_submittedCommand == null) {
      final nextActionTitle = _nextActionController.text.trim();
      if (nextActionTitle.isEmpty) {
        setState(() => _nextActionError = '请保留或改写下一行动');
        return;
      }
      _submittedCommand = CompleteCaseActionCommand(
        operationId: _operationId,
        actionId: widget.action.id,
        caseId: widget.learningCase.id,
        expectedCaseVersion: widget.learningCase.version,
        expectedActionVersion: widget.action.version,
        nextActionType: _nextActionType,
        nextActionTitle: nextActionTitle,
        nextActionDueOn: _nextActionDueOn,
      );
    }

    final command = _submittedCommand!;
    setState(() {
      _submissionAttempted = true;
      _saving = true;
      _saveError = null;
    });
    try {
      final receipt = await widget.repository.completeCaseAction(command);
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
        _saveError =
            '${_describeCaseCommandError(error)}\n本次提交内容已锁定；重试只会查询同一 operation ID。若需修改，请关闭表单并刷新后重新打开。';
      });
    }
  }

  Future<void> _confirmDiscard() async {
    if (_saving) {
      return;
    }
    if (_submissionAttempted) {
      final retry = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提交结果未确认'),
          content: const Text('上一次提交可能已在服务器完成。请先重试原提交；重试会沿用原内容和 operation ID。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('继续查看'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('重试原提交'),
            ),
          ],
        ),
      );
      if (mounted && retry == true) {
        await _save();
      }
      return;
    }
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃完成行动？'),
        content: const Text('当前输入还没有保存。放弃后不会标记行动完成。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃'),
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
        '${widget.learningCase.title} · ${widget.learningCase.status.label} · '
        'version ${widget.learningCase.version}';
    return PopScope<void>(
      canPop: !_isDirty && !_saving && !_submissionAttempted,
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
                          '完成行动',
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
                    '完成“${widget.action.title}”后安排下一步。正式 Case 不会因为勾选完成就失去后续跟进。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _WorkspaceContextLine(label: '当前 Case', value: caseContext),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<CaseActionType>(
                    key: const Key('complete-action-type-dropdown'),
                    initialValue: _nextActionType,
                    decoration: const InputDecoration(labelText: '下一行动类型 *'),
                    items: [
                      for (final type in CaseActionType.values)
                        DropdownMenuItem<CaseActionType>(
                          value: type,
                          child: Text(type.label),
                        ),
                    ],
                    onChanged: _saving || _submissionAttempted
                        ? null
                        : (type) {
                            if (type == null) {
                              return;
                            }
                            setState(() {
                              _nextActionType = type;
                              final currentTitle = _nextActionController.text
                                  .trim();
                              final shouldRefreshGeneratedTitle =
                                  currentTitle.isEmpty ||
                                  currentTitle == _autoGeneratedNextActionTitle;
                              if (shouldRefreshGeneratedTitle) {
                                _autoGeneratedNextActionTitle =
                                    _defaultNextActionTitle(type);
                                _nextActionController.text =
                                    _autoGeneratedNextActionTitle;
                              }
                            });
                          },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _nextActionController,
                    autofocus: true,
                    enabled: !_saving && !_submissionAttempted,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: '下一行动 *',
                      hintText: '明确下一次要做什么',
                      errorText: _nextActionError,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving || _submissionAttempted
                              ? null
                              : _pickDueDate,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            _nextActionDueOn == null
                                ? '安排日期（可选）'
                                : '行动日期：${_formatDateOnly(_nextActionDueOn!)}',
                          ),
                        ),
                      ),
                      if (_nextActionDueOn != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        IconButton(
                          tooltip: '清除日期',
                          onPressed: _saving || _submissionAttempted
                              ? null
                              : () => setState(() => _nextActionDueOn = null),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '日期按机构时区解释；提交失败时原始内容会锁定，重试沿用同一 operation ID。',
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
                          child: Text(
                            _saving
                                ? '保存中…'
                                : _submissionAttempted
                                ? '重试原提交'
                                : '完成并安排下一步',
                          ),
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
          Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(
              Icons.circle,
              size: 8,
              color: Theme.of(context).colorScheme.primary,
            ),
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
      '已逾期' => Theme.of(context).colorScheme.error,
      '待验证' => Theme.of(context).colorScheme.tertiary,
      '稳定' => Theme.of(context).colorScheme.primary,
      '已关闭' => Theme.of(context).colorScheme.onSurfaceVariant,
      _ => Theme.of(context).colorScheme.secondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppRadii.compact),
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
          Icon(
            icon,
            size: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Row(
          children: [
            Icon(
              Icons.shield_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
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
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
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
  const _WorkspaceErrorBody({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 40,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
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
  const _WorkspaceNoAccessBody({this.invitationAcceptanceCard});

  final Widget? invitationAcceptanceCard;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _WorkspaceStateNotice(
                title: '当前账号没有可用的教师教学范围',
                message: '请联系机构管理员确认 active membership、教师角色、学科范围和学生分配。页面不会展示受限学生或 Case 的摘要。',
                icon: Icons.lock_outline,
              ),
              if (invitationAcceptanceCard != null) ...[
                const SizedBox(height: AppSpacing.md),
                invitationAcceptanceCard!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceManagementUnavailable extends StatelessWidget {
  const _WorkspaceManagementUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: _WorkspaceStateNotice(
          title: '机构管理尚未接通',
          message: '当前账号有机构管理角色，但管理数据服务没有配置。请检查应用初始化和开发环境同步状态。',
          icon: Icons.admin_panel_settings_outlined,
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
    required this.isDevelopment,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool busy;
  final String? errorMessage;
  final bool isDevelopment;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学情闭环')),
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
                      '欢迎回来',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      isDevelopment
                          ? '测试版仅使用虚构资料。登录后，系统仍会按机构、角色和教学范围限制数据。'
                          : '请使用机构分配的账号登录，系统会按你的权限显示内容。',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: '邮箱'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '请输入邮箱'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: '密码'),
                      validator: (value) =>
                          value == null || value.isEmpty ? '请输入密码' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy ? null : onSubmit,
                        child: Text(busy ? '登录中…' : '登录'),
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
    _CaseCommandMode.stabilize => '确认 Case 已稳定',
    null => null,
  };
}

String _caseCommandHint(WorkspaceCase learningCase) {
  return switch (_caseCommandMode(learningCase)) {
    _CaseCommandMode.confirm => '确认问题范围、补充判断，然后生成一条可执行的练习行动。',
    _CaseCommandMode.intervention =>
      '把课堂中实际发生的教学动作记下来，系统会把下一步变成 verify action。',
    _CaseCommandMode.assessment => '记录一次可观察的验证结果；通过后仍会停在待确认，不会自动关闭。',
    _CaseCommandMode.stabilize => '最新验证已经通过；确认稳定后会安排一次复查，不会自动关闭。',
    null => '',
  };
}

bool _canStabilizeCase(WorkspaceCase learningCase) {
  if (learningCase.status != LearningCaseStatus.pendingVerification ||
      learningCase.assessments.isEmpty) {
    return false;
  }
  return learningCase.assessments.first.result ==
      CaseAssessmentResult.passed.wireValue;
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

String _describeWorkspaceLoadError(Object? error) {
  final detail = error?.toString().toLowerCase() ?? '';
  const schemaRelations = <String>[
    'organization_case_types',
    'teacher_workspace_context',
    'teacher_workspace_student_enrollments',
    'teacher_workspace_action_queue',
  ];
  if (schemaRelations.any(detail.contains) &&
      (detail.contains('404') ||
          detail.contains('pgrst205') ||
          detail.contains('relation'))) {
    return '开发环境服务还没有完成同步，请稍后重试。';
  }
  if (detail.contains('network') ||
      detail.contains('socket') ||
      detail.contains('timeout')) {
    return '网络暂时不可用，请检查网络后重试。';
  }
  if (detail.contains('no active session') ||
      detail.contains('not authenticated') ||
      detail.contains('signed out')) {
    return '登录状态已失效，请重新登录后再试。';
  }
  return '学生和今日事项暂时没有加载完成。可以重试，已打开的输入不会被删除。';
}

class _CaseReopenDraftStorageException implements Exception {
  const _CaseReopenDraftStorageException(this.cause);

  final Object cause;
}

bool _isUnknownResultFailure(Object error) {
  if (error is TimeoutException || error is SocketException) {
    return true;
  }
  final detail = error.toString().toLowerCase();
  return detail.contains('network') ||
      detail.contains('socket') ||
      detail.contains('timeout') ||
      detail.contains('connection reset') ||
      detail.contains('connection closed') ||
      detail.contains('failed host lookup') ||
      detail.contains('clientexception') ||
      detail.contains('status: 0') ||
      detail.contains('status: 502') ||
      detail.contains('status: 503') ||
      detail.contains('status: 504');
}

String? _caseReopenDraftScopeKey({
  required String? sessionUserId,
  required String? organizationId,
  required String caseId,
}) {
  if (sessionUserId == null ||
      sessionUserId.trim().isEmpty ||
      organizationId == null ||
      organizationId.trim().isEmpty ||
      caseId.trim().isEmpty) {
    return null;
  }
  return 'user:$sessionUserId|organization:$organizationId|case:$caseId';
}

String _describeCaseCommandError(Object error) {
  final detail = error.toString().toLowerCase();
  if (detail.contains('invalid_live_session') ||
      detail.contains('no active session') ||
      detail.contains('not authenticated') ||
      detail.contains('signed out')) {
    return '登录状态已失效。请重新登录后再保存，这次输入仍保留在表单中。';
  }
  if (detail.contains('latest_assessment_not_passed')) {
    return '最新验证还没有通过，暂时不能标记为稳定。';
  }
  if (detail.contains('case_recurrence_before_close')) {
    return '观察时间必须晚于最近一次关闭时间；请调整实际观察时间后重试。';
  }
  if (detail.contains('review_due_date_required')) {
    return '复查行动需要安排日期。';
  }
  if (detail.contains('evidence_not_finalized')) {
    return '这条 Evidence 还没有完成保存，不能用于重新打开 Case。';
  }
  if (detail.contains('evidence_version_conflict')) {
    return '复发 Evidence 已经发生变化，请刷新 Case 后重新选择。';
  }
  if (detail.contains('owner_permission_required')) {
    return '只有这条 Case 的负责教师可以执行这一步。';
  }
  if (detail.contains('case_transition_not_allowed')) {
    return 'Case 状态已经变化，请刷新后再试。';
  }
  if (detail.contains('case_closed')) {
    return '这个 Case 已经关闭，不能再完成其中的行动。请刷新后查看最新状态。';
  }
  if (detail.contains('teaching_fact_gate')) {
    return '当前账号已经失去这名学生的教学权限，请刷新后查看最新分配。';
  }
  if (detail.contains('action_not_pending')) {
    return '这条行动已经被处理，请刷新工作台后查看最新状态。';
  }
  if (detail.contains('action_not_found')) {
    return '这条行动已不存在，请刷新工作台后再试。';
  }
  if (detail.contains('action_version_conflict')) {
    return '这条行动已经被更新，请刷新工作台后再试。';
  }
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

CaseActionType _defaultNextActionType(String wireValue) {
  return switch (wireValue) {
    'reteach' => CaseActionType.practice,
    'practice' => CaseActionType.verify,
    'verify' => CaseActionType.review,
    'communicate' => CaseActionType.review,
    'review' => CaseActionType.review,
    _ => CaseActionType.other,
  };
}

String _defaultNextActionTitle(CaseActionType type) {
  return switch (type) {
    CaseActionType.reteach => '安排一次针对性再教',
    CaseActionType.practice => '安排一次针对性练习',
    CaseActionType.verify => '安排下一次验证',
    CaseActionType.communicate => '安排一次家校沟通',
    CaseActionType.review => '安排一次复查',
    CaseActionType.other => '安排下一步跟进',
  };
}

String _formatDateTimeForReopen(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-$month-$day $hour:$minute';
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
  final dueDate = action.businessDueDate ?? action.dueAt;
  if (dueDate == null) {
    return action.bucket.label;
  }
  return '${action.bucket.label} · ${_formatDate(dueDate)}';
}
