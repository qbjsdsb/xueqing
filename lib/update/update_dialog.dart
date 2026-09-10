import 'package:flutter/material.dart';

import 'update_models.dart';

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({required this.result, super.key});

  final UpdateCheckResult result;

  @override
  Widget build(BuildContext context) {
    final title = result.isMandatory
        ? '建议立即更新'
        : switch (result.state) {
            UpdateCheckState.upToDate => '已是最新版本',
            UpdateCheckState.available => '发现新版本',
            UpdateCheckState.unsupportedPlatform => '发现新版本',
          };

    return AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(child: _buildContent(context)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(result.isMandatory ? '暂不更新' : '关闭'),
        ),
        if (result.hasUpdate)
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('下载并安装'),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return switch (result.state) {
      UpdateCheckState.upToDate => _StatusMessage(
        icon: Icons.check_circle_outline,
        message: '当前版本 ${result.currentVersion} 已是最新版本。',
      ),
      UpdateCheckState.unsupportedPlatform => _StatusMessage(
        icon: Icons.info_outline,
        message:
            '服务器已有 ${result.manifest.version}，但当前平台暂未提供可安装的更新包。',
      ),
      UpdateCheckState.available => _availableContent(context),
    };
  }

  Widget _availableContent(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final notes = result.manifest.notes;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VersionLine(label: '当前版本', value: '${result.currentVersion}'),
              const SizedBox(height: 6),
              _VersionLine(
                label: '新版本',
                value: '${result.manifest.version}',
                emphasized: true,
              ),
            ],
          ),
        ),
        if (result.isMandatory) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  size: 20,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '当前版本已低于服务端声明的最低支持版本，建议现在更新以避免后续功能不兼容。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('本次更新', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(note)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _VersionLine extends StatelessWidget {
  const _VersionLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: emphasized ? scheme.primary : scheme.onSurface,
              fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    );
  }
}
