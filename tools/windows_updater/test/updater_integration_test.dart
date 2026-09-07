import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

const _lifecycleEnvironmentKey =
    'XUEQING_UPDATER_LONG_FIXTURE_LIFECYCLE';
const _fixtureExitTimeout = Duration(seconds: 15);
const _fixtureExitRetryInterval = Duration(milliseconds: 200);
const _cleanupTimeout = Duration(seconds: 10);
const _cleanupRetryInterval = Duration(milliseconds: 250);

void main() {
  test(
    'Windows updater rolls back an invalid launch and installs a stable replacement',
    () async {
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
      final lifecycleFile = File(_join(root.path, 'long-fixture-lifecycle.txt'));
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
          lifecycleFile: lifecycleFile,
        );
        await _waitForLongFixtureExit(lifecycleFile);

        expect(
          rollbackResult.exitCode,
          isNot(0),
          reason:
              'The short-lived replacement must trigger rollback. '
              'stdout: ${rollbackResult.stdout} stderr: ${rollbackResult.stderr}',
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
          lifecycleFile: lifecycleFile,
        );
        await _waitForLongFixtureExit(lifecycleFile);

        expect(
          bootstrapResult.exitCode,
          isNot(0),
          reason:
              'A failed bootstrap marker write must trigger rollback. '
              'stdout: ${bootstrapResult.stdout} stderr: ${bootstrapResult.stderr}',
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
          lifecycleFile: lifecycleFile,
        );
        await _waitForLongFixtureExit(lifecycleFile);

        expect(
          installResult.exitCode,
          0,
          reason:
              'A stable replacement should complete successfully. '
              'stdout: ${installResult.stdout} stderr: ${installResult.stderr}',
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
      } finally {
        await _deleteTestRootWhenReleased(root);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _waitForLongFixtureExit(File lifecycleFile) async {
  final deadline = DateTime.now().add(_fixtureExitTimeout);
  String? lastState;
  while (DateTime.now().isBefore(deadline)) {
    try {
      if (await lifecycleFile.exists()) {
        lastState = (await lifecycleFile.readAsString()).trim();
        if (lastState.startsWith('exited:')) {
          return;
        }
      }
    } on FileSystemException {
      // The fixture may be replacing the marker between running/exited states.
    }
    await Future<void>.delayed(_fixtureExitRetryInterval);
  }
  throw StateError(
    'The restored or installed long-lived fixture did not report exit within '
    '${_fixtureExitTimeout.inSeconds} seconds. Last state: $lastState',
  );
}

Future<void> _deleteTestRootWhenReleased(Directory root) async {
  if (!await root.exists()) {
    return;
  }

  final deadline = DateTime.now().add(_cleanupTimeout);
  FileSystemException? lastAccessError;
  while (DateTime.now().isBefore(deadline)) {
    try {
      await root.delete(recursive: true);
      return;
    } on FileSystemException catch (error) {
      lastAccessError = error;
      await Future<void>.delayed(_cleanupRetryInterval);
    }
  }

  if (!await root.exists()) {
    return;
  }
  throw StateError(
    'Updater integration cleanup stayed locked for '
    '${_cleanupTimeout.inSeconds} seconds: $lastAccessError',
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
  required File lifecycleFile,
}) async {
  if (await lifecycleFile.exists()) {
    await lifecycleFile.delete();
  }
  final packageBytes = await packageFile.readAsBytes();
  return Process.run(
    helperPath,
    <String>[
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
    ],
    environment: <String, String>{
      _lifecycleEnvironmentKey: lifecycleFile.path,
    },
    includeParentEnvironment: true,
  );
}

String _join(String parent, String child) {
  return '$parent${Platform.pathSeparator}$child';
}
