import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

void showLearningRecordExportSuccess(
  BuildContext context, {
  required String savedPath,
  String summary = '学情记录表已生成',
}) {
  final isWindows = Platform.isWindows;
  final message = isWindows ? '$summary。\n保存位置：$savedPath' : '$summary。';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 8),
      content: Text(message),
      action: isWindows
          ? SnackBarAction(
              label: '打开文件夹',
              onPressed: () => unawaited(_revealWindowsFile(savedPath)),
            )
          : null,
    ),
  );
}

Future<void> _revealWindowsFile(String savedPath) async {
  if (!Platform.isWindows) return;
  final file = File(savedPath).absolute;
  try {
    await Process.start('explorer.exe', <String>[
      '/select,',
      file.path,
    ], mode: ProcessStartMode.detached);
  } catch (_) {
    try {
      await Process.start('explorer.exe', <String>[
        file.parent.path,
      ], mode: ProcessStartMode.detached);
    } catch (_) {
      // Export already succeeded. Explorer reveal is convenience only.
    }
  }
}
