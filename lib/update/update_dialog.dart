import 'package:flutter/material.dart';

import 'update_models.dart';

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({required this.result, super.key});

  final UpdateCheckResult result;

  @override
  Widget build(BuildContext context) {
    final title = switch (result.state) {
      UpdateCheckState.upToDate => '已是最新版本',
      UpdateCheckState.available => '发现新版本',
      UpdateCheckState.unsupportedPlatform => '发现新版本',
    };
    final content = switch (result.state) {
      UpdateCheckState.upToDate => '当前版本 \${result.currentVersion} 已是最新版本。',
      UpdateCheckState.unsupportedPlatform =>
        '服务器已有 \${result.manifest.version}，但当前平台暂未提供可安装的更新包。',
      UpdateCheckState.available => _availableContent(),
    };

    return AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Text(content),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(result.isMandatory ? '稍后处理' : '关闭'),
        ),
        if (result.hasUpdate)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('下载并安装'),
          ),
      ],
    );
  }

  String _availableContent() {
    final lines = <String>[
      '当前版本：\${result.currentVersion}',
      '新版本：\${result.manifest.version}',
      if (result.isMandatory) '这是必须更新的版本。',
      ...result.manifest.notes.map((note) => '• $note'),
    ];
    return lines.join('\n');
  }
}
