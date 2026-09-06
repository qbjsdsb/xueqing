import 'dart:io';

import 'package:flutter/services.dart';

import 'update_models.dart';
import 'update_service.dart';

abstract interface class UpdateInstaller {
  Future<UpdateInstallResult> install(UpdateDownloadedArtifact update);
}

class UpdateInstallResult {
  const UpdateInstallResult({required this.shouldExit});

  final bool shouldExit;
}

class UpdateInstallException implements Exception {
  const UpdateInstallException(this.userMessage, {this.cause});

  final String userMessage;
  final Object? cause;

  @override
  String toString() => userMessage;
}

class PlatformUpdateInstaller implements UpdateInstaller {
  PlatformUpdateInstaller({MethodChannel? androidChannel})
    : androidChannel =
          androidChannel ?? const MethodChannel(_androidChannelName);

  static const _androidChannelName = 'com.xueqing.app/update';

  final MethodChannel androidChannel;

  @override
  Future<UpdateInstallResult> install(UpdateDownloadedArtifact update) {
    switch (update.artifact.platform) {
      case UpdatePlatform.windows:
        return _installWindows(update);
      case UpdatePlatform.android:
        return _installAndroid(update);
    }
  }

  Future<UpdateInstallResult> _installWindows(
    UpdateDownloadedArtifact update,
  ) async {
    if (!Platform.isWindows) {
      throw const UpdateInstallException('当前设备不是 Windows，无法安装 Windows 更新。');
    }

    final executable = File(Platform.resolvedExecutable);
    final installDirectory = executable.parent;
    final helper = File(
      '${installDirectory.path}${Platform.pathSeparator}xueqing_updater.exe',
    );
    if (!await helper.exists()) {
      throw const UpdateInstallException('当前安装包缺少更新组件，请重新安装最新完整版本后再试。');
    }

    try {
      await Process.start(
        helper.path,
        [
          '--pid',
          '$pid',
          '--package',
          update.file.path,
          '--install-dir',
          installDirectory.path,
          '--launch',
          executable.path,
          '--sha256',
          update.artifact.sha256,
        ],
        workingDirectory: installDirectory.path,
        mode: ProcessStartMode.detached,
      );
    } on Object catch (error) {
      throw UpdateInstallException('无法启动 Windows 更新组件。', cause: error);
    }
    return const UpdateInstallResult(shouldExit: true);
  }

  Future<UpdateInstallResult> _installAndroid(
    UpdateDownloadedArtifact update,
  ) async {
    if (!Platform.isAndroid) {
      throw const UpdateInstallException('当前设备不是 Android，无法安装 APK 更新。');
    }

    try {
      final status = await androidChannel.invokeMethod<String>(
        'installApk',
        <String, Object?>{'path': update.file.path},
      );
      if (status == 'permission_required') {
        throw const UpdateInstallException('系统已打开“允许安装未知应用”设置，请允许本应用后返回重试。');
      }
      if (status != 'started') {
        throw UpdateInstallException(
          '系统没有启动 APK 安装器（状态：${status ?? 'unknown'}）。',
        );
      }
      return const UpdateInstallResult(shouldExit: false);
    } on PlatformException catch (error) {
      throw UpdateInstallException('系统安装器启动失败，请稍后重试。', cause: error);
    }
  }
}
