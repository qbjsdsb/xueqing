import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../update/update_dialog.dart';
import '../../update/update_installer.dart';
import '../../update/update_service.dart';

Future<void> runV2UpdateFlow(
  BuildContext context, {
  required UpdateService service,
  required UpdateInstaller installer,
}) async {
  try {
    final result = await service.checkForUpdate();
    if (!context.mounted) return;

    final shouldInstall = await showDialog<bool>(
      context: context,
      builder: (_) => UpdateDialog(result: result),
    );
    if (shouldInstall != true || !context.mounted) return;

    final artifact = result.artifact;
    if (artifact == null) return;
    final progress = ValueNotifier<_V2UpdateProgressState>(
      _V2UpdateProgressState(
        downloadedBytes: 0,
        totalBytes: artifact.sizeBytes,
        status: '正在下载更新…',
      ),
    );
    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope<void>(
        canPop: false,
        child: _V2UpdateProgressDialog(progress: progress),
      ),
    );

    UpdateInstallResult? installResult;
    try {
      // Let the progress route render before network I/O begins.
      await Future<void>.delayed(Duration.zero);
      final downloaded = await service.download(
        result,
        onProgress: (downloadedBytes, totalBytes) {
          progress.value = _V2UpdateProgressState(
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
            status: '正在下载更新…',
          );
        },
      );
      progress.value = _V2UpdateProgressState(
        downloadedBytes: artifact.sizeBytes,
        totalBytes: artifact.sizeBytes,
        status: '下载完成并已校验，正在打开安装程序…',
      );
      installResult = await installer.install(downloaded);
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        await dialogFuture;
      }
      progress.dispose();
    }

    if (!context.mounted) return;
    if (installResult.shouldExit) {
      await SystemNavigator.pop();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('更新包已下载并校验，已打开系统安装界面，请按提示完成更新。')),
    );
  } on UpdateException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  } on UpdateInstallException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('更新失败，请稍后重试。')));
    }
  }
}

class _V2UpdateProgressState {
  const _V2UpdateProgressState({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.status,
  });

  final int downloadedBytes;
  final int totalBytes;
  final String status;

  double? get fraction {
    if (totalBytes <= 0) return null;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }
}

class _V2UpdateProgressDialog extends StatelessWidget {
  const _V2UpdateProgressDialog({required this.progress});

  final ValueListenable<_V2UpdateProgressState> progress;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('正在更新学情'),
      content: ValueListenableBuilder<_V2UpdateProgressState>(
        valueListenable: progress,
        builder: (context, value, _) {
          final fraction = value.fraction;
          final percent = fraction == null ? null : (fraction * 100).round();
          return SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value.status),
                const SizedBox(height: 14),
                LinearProgressIndicator(value: fraction),
                const SizedBox(height: 10),
                Text(
                  percent == null
                      ? '${_formatBytes(value.downloadedBytes)} 已下载'
                      : '$percent% · ${_formatBytes(value.downloadedBytes)} / ${_formatBytes(value.totalBytes)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '下载完成后会自动校验文件并打开安装程序，请不要关闭应用。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 10 ? 1 : 2)} MB';
}
