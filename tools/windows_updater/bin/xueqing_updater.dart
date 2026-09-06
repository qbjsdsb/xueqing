import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:xueqing_windows_updater/updater_safety.dart';

const _canonicalHelperFileName = 'xueqing_updater.exe';
const _bootstrapHelperFileName = 'xueqing_updater_bootstrap.exe';
const _bootstrapMigrationMarkerName = '.xueqing_updater_bootstrap_migrated';
const _waitTimeout = Duration(seconds: 90);
const _launchGracePeriod = Duration(seconds: 2);

Future<void> main(List<String> args) async {
  _UpdaterOptions? options;
  try {
    options = _UpdaterOptions.parse(args);
    await _runUpdate(options);
    stdout.writeln('Xueqing update installed successfully.');
    exitCode = 0;
  } catch (error, stackTrace) {
    stderr.writeln('Xueqing update failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  } finally {
    final cleanupPath = options?.cleanupPath;
    if (cleanupPath != null) {
      await _scheduleSelfCleanup(cleanupPath);
    }
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
  final skipFileNames = <String>{
    _baseName(Platform.resolvedExecutable),
    _bootstrapMigrationMarkerName,
  };

  try {
    await _extractZip(options.packageFile, stagingDirectory);
    _requireStagedExecutable(stagingDirectory, options.launchPath);
    _requireStagedUpdater(stagingDirectory);

    final installDirectory = Directory(options.installDirectory);
    if (!await installDirectory.exists()) {
      throw StateError('安装目录不存在：${options.installDirectory}');
    }

    await _copyTree(
      installDirectory,
      backupDirectory,
      skipFileNames: skipFileNames,
    );
    backupReady = true;

    int? launchedPid;
    try {
      await _clearInstallDirectory(
        installDirectory,
        skipFileNames: skipFileNames,
      );
      await _copyTree(
        stagingDirectory,
        installDirectory,
        skipFileNames: skipFileNames,
      );
      final installedExecutable = File(options.launchPath);
      if (!await installedExecutable.exists()) {
        throw StateError('更新包没有生成主程序：${options.launchPath}');
      }

      launchedPid = await _launchInstalledExecutable(
        installedExecutable.path,
        installDirectory.path,
      );
      await _markBootstrapMigrationComplete(installDirectory);
      launchedPid = null;
    } catch (error) {
      if (!backupReady) {
        rethrow;
      }
      if (launchedPid != null) {
        try {
          await _terminateProcess(launchedPid);
        } catch (terminationError) {
          preserveBackup = true;
          throw StateError(
            '更新失败且无法终止新程序；请保留备份目录 ${backupDirectory.path}。'
            ' 原始错误：$error；终止错误：$terminationError',
          );
        }
      } else if (error is _UpdaterLaunchFailure &&
          error.terminationError != null) {
        preserveBackup = true;
        throw StateError(
          '更新失败且无法终止新程序；请保留备份目录 ${backupDirectory.path}。'
          ' 原始错误：${error.cause}；终止错误：${error.terminationError}',
        );
      }
      try {
        await _restoreFromBackup(
          installDirectory,
          backupDirectory,
          skipFileNames: skipFileNames,
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

Future<int> _launchInstalledExecutable(
  String executablePath,
  String workingDirectory,
) async {
  final process = await Process.start(
    executablePath,
    const <String>[],
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.detached,
  );
  try {
    final deadline = DateTime.now().add(_launchGracePeriod);
    var observedRunning = false;
    while (DateTime.now().isBefore(deadline)) {
      if (await _isProcessRunning(process.pid)) {
        observedRunning = true;
      } else if (observedRunning) {
        throw StateError('更新后的程序启动后立即退出（pid ${process.pid}）。');
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (!observedRunning || !await _isProcessRunning(process.pid)) {
      throw StateError('更新后的程序未能在宽限期内保持运行（pid ${process.pid}）。');
    }
    return process.pid;
  } catch (error) {
    Object? terminationError;
    try {
      await _terminateProcess(process.pid);
    } catch (caughtTerminationError) {
      terminationError = caughtTerminationError;
    }
    throw _UpdaterLaunchFailure(
      processId: process.pid,
      cause: error,
      terminationError: terminationError,
    );
  }
}

class _UpdaterLaunchFailure implements Exception {
  const _UpdaterLaunchFailure({
    required this.processId,
    required this.cause,
    required this.terminationError,
  });

  final int processId;
  final Object cause;
  final Object? terminationError;

  @override
  String toString() {
    final termination = terminationError == null
        ? '启动进程已终止。'
        : '无法终止启动进程：$terminationError。';
    return '更新后的程序启动失败（pid $processId）：$cause；$termination';
  }
}

const _terminateTimeout = Duration(seconds: 10);

Future<void> _terminateProcess(int processId) async {
  if (!await _isProcessRunning(processId)) {
    return;
  }
  final result = await Process.run('taskkill.exe', <String>[
    '/PID',
    '$processId',
    '/T',
    '/F',
  ]);
  if (result.exitCode != 0) {
    if (!await _isProcessRunning(processId)) {
      return;
    }
    throw StateError('无法终止 Windows 进程 $processId：${result.stderr}');
  }

  final deadline = DateTime.now().add(_terminateTimeout);
  while (DateTime.now().isBefore(deadline)) {
    if (!await _isProcessRunning(processId)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw StateError(
    'Windows 进程 $processId 在 ${_terminateTimeout.inSeconds} 秒内没有退出。',
  );
}

Future<void> _scheduleSelfCleanup(String path) async {
  if (!Platform.isWindows) {
    return;
  }
  try {
    final escapedPath = path.replaceAll('"', '""');
    await Process.start('cmd.exe', <String>[
      '/d',
      '/c',
      'ping.exe 127.0.0.1 -n 3 > nul & del /f /q "$escapedPath"',
    ], mode: ProcessStartMode.detached);
  } on Object catch (error) {
    stderr.writeln('无法清理临时更新组件：$error');
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

void _requireStagedUpdater(Directory stagingDirectory) {
  final canonicalHelper = File(
    _join(stagingDirectory.path, _canonicalHelperFileName),
  );
  final bootstrapHelper = File(
    _join(stagingDirectory.path, _bootstrapHelperFileName),
  );
  if (!canonicalHelper.existsSync() && !bootstrapHelper.existsSync()) {
    throw StateError(
      '压缩包缺少 Windows 更新组件：$_canonicalHelperFileName 或 '
      '$_bootstrapHelperFileName',
    );
  }
}

Future<void> _markBootstrapMigrationComplete(Directory installDirectory) async {
  if (_baseName(Platform.resolvedExecutable).toLowerCase() !=
      _bootstrapHelperFileName) {
    return;
  }
  final marker = File(
    _join(installDirectory.path, _bootstrapMigrationMarkerName),
  );
  await marker.writeAsString('migrated\n', flush: true);
}

bool _shouldSkip(String name, Set<String> skipFileNames) {
  final lowerName = name.toLowerCase();
  return skipFileNames.any((candidate) => candidate.toLowerCase() == lowerName);
}

Future<void> _clearInstallDirectory(
  Directory installDirectory, {
  required Set<String> skipFileNames,
}) async {
  await for (final entity in installDirectory.list(followLinks: false)) {
    if (_shouldSkip(_baseName(entity.path), skipFileNames)) {
      continue;
    }
    await entity.delete(recursive: true);
  }
}

Future<void> _copyTree(
  Directory source,
  Directory destination, {
  required Set<String> skipFileNames,
}) async {
  await destination.create(recursive: true);
  await for (final entity in source.list(followLinks: false)) {
    final name = _baseName(entity.path);
    if (entity is File) {
      if (_shouldSkip(name, skipFileNames)) {
        continue;
      }
      final target = File(_join(destination.path, name));
      await target.parent.create(recursive: true);
      await entity.copy(target.path);
    } else if (entity is Directory) {
      await _copyTree(
        entity,
        Directory(_join(destination.path, name)),
        skipFileNames: skipFileNames,
      );
    } else if (entity is Link) {
      throw StateError('安装目录包含不支持的符号链接：${entity.path}');
    }
  }
}

Future<void> _restoreFromBackup(
  Directory installDirectory,
  Directory backupDirectory, {
  required Set<String> skipFileNames,
}) async {
  await for (final entity in installDirectory.list(followLinks: false)) {
    final name = _baseName(entity.path);
    if (_shouldSkip(name, skipFileNames)) {
      continue;
    }
    await entity.delete(recursive: true);
  }
  await _copyTree(
    backupDirectory,
    installDirectory,
    skipFileNames: skipFileNames,
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
    this.cleanupPath,
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
    final cleanupPath = values['cleanup-path'];
    if (packagePath == null ||
        installDirectory == null ||
        launchPath == null ||
        sha256Value == null ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256Value) ||
        (cleanupPath != null && !_isSafeCleanupPath(cleanupPath))) {
      throw const FormatException('更新参数缺失、临时组件路径无效或 SHA-256 无效。');
    }

    return _UpdaterOptions(
      pid: pid,
      packagePath: packagePath,
      installDirectory: installDirectory,
      launchPath: launchPath,
      sha256: sha256Value,
      cleanupPath: cleanupPath,
    );
  }

  final int pid;
  final String packagePath;
  final String installDirectory;
  final String launchPath;
  final String sha256;
  final String? cleanupPath;

  File get packageFile => File(packagePath);
}

bool _isSafeCleanupPath(String path) {
  final tempDirectory = Directory.systemTemp.absolute.path;
  final candidate = File(path).absolute.path;
  final prefix = tempDirectory.endsWith(Platform.pathSeparator)
      ? tempDirectory
      : '$tempDirectory${Platform.pathSeparator}';
  final fileName = _baseName(candidate).toLowerCase();
  return candidate.toLowerCase().startsWith(prefix.toLowerCase()) &&
      fileName.startsWith('xueqing-updater-') &&
      fileName.endsWith('.exe');
}
