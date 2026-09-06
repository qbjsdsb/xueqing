import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:xueqing_windows_updater/updater_safety.dart';

const _helperFileName = 'xueqing_updater.exe';
const _waitTimeout = Duration(seconds: 90);
const _launchGracePeriod = Duration(seconds: 2);

Future<void> main(List<String> args) async {
  try {
    final options = _UpdaterOptions.parse(args);
    await _runUpdate(options);
    stdout.writeln('Xueqing update installed successfully.');
    exitCode = 0;
  } catch (error, stackTrace) {
    stderr.writeln('Xueqing update failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

Future<void> _runUpdate(_UpdaterOptions options) async {
  await _waitForProcessToExit(options.pid);
  await _verifySha256(options.packageFile, options.sha256);

  final stagingDirectory = await Directory.systemTemp.createTemp(
    'xueqing-update-stage-',
  );
  final backupDirectory = await Directory.systemTemp.createTemp(
    'xueqing-update-backup-',
  );
  var backupReady = false;
  var preserveBackup = false;

  try {
    await _extractZip(options.packageFile, stagingDirectory);
    _requireStagedExecutable(stagingDirectory, options.launchPath);

    final installDirectory = Directory(options.installDirectory);
    if (!await installDirectory.exists()) {
      throw StateError('安装目录不存在：${options.installDirectory}');
    }

    await _copyTree(
      installDirectory,
      backupDirectory,
      skipFileName: _helperFileName,
    );
    backupReady = true;

    try {
      await _clearInstallDirectory(
        installDirectory,
        skipFileName: _helperFileName,
      );
      await _copyTree(
        stagingDirectory,
        installDirectory,
        skipFileName: _helperFileName,
      );
      final installedExecutable = File(options.launchPath);
      if (!await installedExecutable.exists()) {
        throw StateError('更新包没有生成主程序：${options.launchPath}');
      }

      await _launchInstalledExecutable(
        installedExecutable.path,
        installDirectory.path,
      );
    } catch (error) {
      if (!backupReady) {
        rethrow;
      }
      try {
        await _restoreFromBackup(
          installDirectory,
          backupDirectory,
          skipFileName: _helperFileName,
        );
      } catch (restoreError) {
        preserveBackup = true;
        throw StateError(
          '更新失败且回滚失败；请保留备份目录 ${backupDirectory.path}。'
          ' 原始错误：$error；回滚错误：$restoreError',
        );
      }
      try {
        await _launchInstalledExecutable(
          options.launchPath,
          installDirectory.path,
        );
      } catch (relaunchError) {
        preserveBackup = true;
        throw StateError(
          '更新失败，已回滚但旧版本启动失败；请保留备份目录 '
          '${backupDirectory.path}。原始错误：$error；重启错误：$relaunchError',
        );
      }
      rethrow;
    }
  } finally {
    await _deleteDirectory(stagingDirectory);
    if (!preserveBackup) {
      await _deleteDirectory(backupDirectory);
    }
  }
}

Future<void> _launchInstalledExecutable(
  String executablePath,
  String workingDirectory,
) async {
  final process = await Process.start(
    executablePath,
    const <String>[],
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.detached,
  );
  final exitCode = await Future.any<int?>(<Future<int?>>[
    process.exitCode,
    Future<int?>.delayed(_launchGracePeriod, () => null),
  ]);
  if (exitCode != null) {
    throw StateError('更新后的程序启动后立即退出（exit code $exitCode）。');
  }
}

Future<void> _waitForProcessToExit(int processId) async {
  final deadline = DateTime.now().add(_waitTimeout);
  while (DateTime.now().isBefore(deadline)) {
    if (!await _isProcessRunning(processId)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw StateError('主程序在 ${_waitTimeout.inSeconds} 秒内没有退出。');
}

Future<bool> _isProcessRunning(int processId) async {
  final result = await Process.run('tasklist.exe', <String>[
    '/FI',
    'PID eq $processId',
    '/NH',
  ]);
  if (result.exitCode != 0) {
    throw StateError('无法查询 Windows 进程状态：${result.stderr}');
  }
  final output = result.stdout.toString();
  return RegExp(r'(^|\s)$processId(\s|$)').hasMatch(output);
}

Future<void> _verifySha256(File file, String expected) async {
  if (!await file.exists()) {
    throw StateError('更新包不存在：${file.path}');
  }
  final digest = await sha256.bind(file.openRead()).first;
  if (digest.toString() != expected) {
    throw StateError('更新包 SHA-256 校验失败。');
  }
}

Future<void> _extractZip(File zipFile, Directory destination) async {
  final bytes = await zipFile.readAsBytes();
  final archive = ZipDecoder().decodeBytes(bytes);
  validateUpdaterArchivePaths(archive.map((entry) => entry.name));
  for (final entry in archive) {
    final name = normalizeUpdaterArchivePath(entry.name);
    final output = File(_join(destination.path, name));
    if (!entry.isFile) {
      await Directory(output.path).create(recursive: true);
      continue;
    }
    await output.parent.create(recursive: true);
    final content = entry.content;
    if (content is! List<int>) {
      throw StateError('压缩包条目内容无效：$name');
    }
    await output.writeAsBytes(content, flush: true);
  }
}

void _requireStagedExecutable(Directory stagingDirectory, String launchPath) {
  final executableName = _baseName(launchPath);
  final stagedExecutable = File(_join(stagingDirectory.path, executableName));
  if (!stagedExecutable.existsSync()) {
    throw StateError('压缩包根目录没有主程序：$executableName');
  }
}

Future<void> _clearInstallDirectory(
  Directory installDirectory, {
  required String skipFileName,
}) async {
  await for (final entity in installDirectory.list(followLinks: false)) {
    if (_baseName(entity.path) == skipFileName) {
      continue;
    }
    await entity.delete(recursive: true);
  }
}

Future<void> _copyTree(
  Directory source,
  Directory destination, {
  required String skipFileName,
}) async {
  await destination.create(recursive: true);
  await for (final entity in source.list(followLinks: false)) {
    final name = _baseName(entity.path);
    if (entity is File) {
      if (name == skipFileName) {
        continue;
      }
      final target = File(_join(destination.path, name));
      await target.parent.create(recursive: true);
      await entity.copy(target.path);
    } else if (entity is Directory) {
      await _copyTree(
        entity,
        Directory(_join(destination.path, name)),
        skipFileName: skipFileName,
      );
    } else if (entity is Link) {
      throw StateError('安装目录包含不支持的符号链接：${entity.path}');
    }
  }
}

Future<void> _restoreFromBackup(
  Directory installDirectory,
  Directory backupDirectory, {
  required String skipFileName,
}) async {
  await for (final entity in installDirectory.list(followLinks: false)) {
    final name = _baseName(entity.path);
    if (name == skipFileName) {
      continue;
    }
    await entity.delete(recursive: true);
  }
  await _copyTree(
    backupDirectory,
    installDirectory,
    skipFileName: skipFileName,
  );
}

Future<void> _deleteDirectory(Directory directory) async {
  if (await directory.exists()) {
    await directory.delete(recursive: true);
  }
}

String _join(String parent, String child) {
  return '$parent${Platform.pathSeparator}$child';
}

String _baseName(String path) {
  return path.replaceAll(r'\', '/').split('/').last;
}

class _UpdaterOptions {
  const _UpdaterOptions({
    required this.pid,
    required this.packagePath,
    required this.installDirectory,
    required this.launchPath,
    required this.sha256,
  });

  factory _UpdaterOptions.parse(List<String> args) {
    final values = <String, String>{};
    for (var index = 0; index < args.length; index += 2) {
      if (index + 1 >= args.length || !args[index].startsWith('--')) {
        throw const FormatException('更新参数必须是 --name value 形式。');
      }
      values[args[index].substring(2)] = args[index + 1];
    }

    final pid = int.tryParse(values['pid'] ?? '');
    if (pid == null || pid <= 0) {
      throw const FormatException('更新参数 pid 无效。');
    }
    final packagePath = values['package'];
    final installDirectory = values['install-dir'];
    final launchPath = values['launch'];
    final sha256Value = values['sha256']?.toLowerCase();
    if (packagePath == null ||
        installDirectory == null ||
        launchPath == null ||
        sha256Value == null ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256Value)) {
      throw const FormatException('更新参数缺失或 SHA-256 无效。');
    }

    return _UpdaterOptions(
      pid: pid,
      packagePath: packagePath,
      installDirectory: installDirectory,
      launchPath: launchPath,
      sha256: sha256Value,
    );
  }

  final int pid;
  final String packagePath;
  final String installDirectory;
  final String launchPath;
  final String sha256;

  File get packageFile => File(packagePath);
}
