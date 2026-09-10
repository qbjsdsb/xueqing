import 'package:flutter/material.dart';

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
