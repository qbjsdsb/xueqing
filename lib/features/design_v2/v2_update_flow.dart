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

    final downloaded = await service.download(result);
    final installResult = await installer.install(downloaded);
    if (!context.mounted) return;
    if (installResult.shouldExit) {
      await SystemNavigator.pop();
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已打开系统安装界面，请按提示完成更新。')));
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
