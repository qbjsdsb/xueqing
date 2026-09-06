import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  test('Windows updater rolls back an invalid launch and installs a stable replacement', () async {
    if (!Platform.isWindows) {
      return;
    }

    final helperPath = Platform.environment['XUEQING_UPDATER_HELPER'];
    final shortFixturePath =
        Platform.environment['XUEQING_UPDATER_SHORT_FIXTURE'];
    final longFixturePath =
        Platform.environment['XUEQING_UPDATER_LONG_FIXTURE'];
    final bootstrapHelperPath =
        Platform.environment['XUEQING_UPDATER_BOOTSTRAP_HELPER'];
    if (helperPath == null ||
        shortFixturePath == null ||
        longFixturePath == null ||
        bootstrapHelperPath == null) {
      return;
    }

    final helper = File(helperPath);
    final shortFixture = File(shortFixturePath);
    final longFixture = File(longFixturePath);
    final bootstrapHelper = File(bootstrapHelperPath);
    if (!await helper.exists() ||
        !await shortFixture.exists() ||
        !await longFixture.exists() ||
        !await bootstrapHelper.exists()) {
      return;
    }

    final root = await Directory.systemTemp.createTemp(
      'xueqing-updater-integration-',
    );
    final installDirectory = Directory(_join(root.path, 'install'));
    await installDirectory.create();
    final launchPath = _join(installDirectory.path, 'xueqing.exe');
    final oldExecutableBytes = await longFixture.readAsBytes();
    final helperBytes = await helper.readAsBytes();
    final bootstrapHelperBytes = await bootstrapHelper.readAsBytes();

    try {
      await File(launchPath).writeAsBytes(oldExecutableBytes, flush: true);
      await File(_join(installDirectory.path, 'old-version.txt'))
          .writeAsString('old\n', flush: true);

      final rollbackPackage = await _createPackage(
        root: root,
        fileName: 'rollback.zip',
        executableBytes: await shortFixture.readAsBytes(),
        helperBytes: helperBytes,
        marker: 'rollback',
      );
      final rollbackResult = await _runUpdater(
        helperPath: helper.path,
        packageFile: rollbackPackage,
        installDirectory: installDirectory,
        launchPath: launchPath,
      );

      expect(
        rollbackResult.exitCode,
        isNot(0),
        reason: 'The short-lived replacement must trigger rollback.',
      );
      expect(
        await File(launchPath).readAsBytes(),
        oldExecutableBytes,
        reason: 'Rollback must restore the previous executable.',
      );
      expect(
        await File(_join(installDirectory.path, 'old-version.txt'))
            .readAsString(),
        'old\n',
      );
      expect(
        await File(_join(installDirectory.path, 'new-version.txt')).exists(),
        isFalse,
        reason: 'Rollback must remove files from the failed package.',
      );
      await Future<void>.delayed(const Duration(seconds: 10));

      final bootstrapMarkerPath = _join(
        installDirectory.path,
        '.xueqing_updater_bootstrap_migrated',
      );
      await Directory(bootstrapMarkerPath).create();

      final bootstrapPackage = await _createPackage(
        root: root,
        fileName: 'bootstrap-migration.zip',
        executableBytes: await longFixture.readAsBytes(),
        helperBytes: bootstrapHelperBytes,
        marker: 'bootstrap-migration',
      );
      final bootstrapResult = await _runUpdater(
        helperPath: bootstrapHelper.path,
        packageFile: bootstrapPackage,
        installDirectory: installDirectory,
        launchPath: launchPath,
      );

      expect(
        bootstrapResult.exitCode,
        isNot(0),
        reason: 'A failed bootstrap marker write must trigger rollback.',
      );
      expect(
        await File(launchPath).readAsBytes(),
        oldExecutableBytes,
        reason: 'Bootstrap rollback must restore the previous executable.',
      );
      expect(
        await File(_join(installDirectory.path, 'old-version.txt'))
            .readAsString(),
        'old\n',
      );
      expect(
        await File(_join(installDirectory.path, 'new-version.txt')).exists(),
        isFalse,
        reason: 'Bootstrap rollback must remove files from the failed package.',
      );
      expect(
        await Directory(bootstrapMarkerPath).exists(),
        isTrue,
        reason: 'The marker directory must remain to force the write failure.',
      );
      await Future<void>.delayed(const Duration(seconds: 10));
      await Directory(bootstrapMarkerPath).delete();

      final installPackage = await _createPackage(
        root: root,
        fileName: 'install.zip',
        executableBytes: await longFixture.readAsBytes(),
        helperBytes: helperBytes,
        marker: 'installed',
      );
      final installResult = await _runUpdater(
        helperPath: helper.path,
        packageFile: installPackage,
        installDirectory: installDirectory,
        launchPath: launchPath,
      );

      expect(
        installResult.exitCode,
        0,
        reason: 'A stable replacement should complete successfully.',
      );
      expect(
        await File(_join(installDirectory.path, 'new-version.txt'))
            .readAsString(),
        'installed\n',
      );
      expect(
        await File(_join(installDirectory.path, 'old-version.txt')).exists(),
        isFalse,
        reason: 'A successful replacement must remove old files.',
      );
      await Future<void>.delayed(const Duration(seconds: 10));
    } finally {
      if (await root.exists()) {
        await _deleteDirectoryWithRetries(root);
      }
    }
  });
}

Future<void> _deleteDirectoryWithRetries(Directory directory) async {
  Object? lastError;
  for (var attempt = 0; attempt < 20; attempt++) {
    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException catch (error) {
      lastError = error;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }
  Error.throwWithStackTrace(
    lastError ?? StateError('无法清理 Windows 更新集成测试目录。'),
    StackTrace.current,
  );
}

Future<File> _createPackage({
  required Directory root,
  required String fileName,
  required List<int> executableBytes,
  required List<int> helperBytes,
  required String marker,
}) async {
  final archive = Archive()
    ..addFile(
      ArchiveFile('xueqing.exe', executableBytes.length, executableBytes),
    )
    ..addFile(
      ArchiveFile('xueqing_updater.exe', helperBytes.length, helperBytes),
    )
    ..addFile(
      ArchiveFile(
        'xueqing_updater_bootstrap.exe',
        helperBytes.length,
        helperBytes,
      ),
    )
    ..addFile(ArchiveFile.string('new-version.txt', '$marker\n'));
  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('Unable to encode the updater integration package.');
  }
  final packageFile = File(_join(root.path, fileName));
  await packageFile.writeAsBytes(encoded, flush: true);
  return packageFile;
}

Future<ProcessResult> _runUpdater({
  required String helperPath,
  required File packageFile,
  required Directory installDirectory,
  required String launchPath,
}) async {
  final packageBytes = await packageFile.readAsBytes();
  return Process.run(helperPath, <String>[
    '--pid',
    '2147483647',
    '--package',
    packageFile.path,
    '--install-dir',
    installDirectory.path,
    '--launch',
    launchPath,
    '--sha256',
    sha256.convert(packageBytes).toString(),
  ]);
}

String _join(String parent, String child) {
  return '$parent${Platform.pathSeparator}$child';
}
