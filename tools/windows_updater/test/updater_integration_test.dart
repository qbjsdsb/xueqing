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
    if (helperPath == null ||
        shortFixturePath == null ||
        longFixturePath == null) {
      return;
    }

    final helper = File(helperPath);
    final shortFixture = File(shortFixturePath);
    final longFixture = File(longFixturePath);
    if (!await helper.exists() ||
        !await shortFixture.exists() ||
        !await longFixture.exists()) {
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

    try {
      await File(launchPath).writeAsBytes(oldExecutableBytes, flush: true);
      await File(
        _join(installDirectory.path, 'old-version.txt'),
      ).writeAsString('old\n', flush: true);

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
        await File(
          _join(installDirectory.path, 'old-version.txt'),
        ).readAsString(),
        'old\n',
      );
      expect(
        await File(
          _join(installDirectory.path, 'new-version.txt'),
        ).exists(),
        isFalse,
        reason: 'Rollback must remove files from the failed package.',
      );
      await Future<void>.delayed(const Duration(seconds: 6));

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
        await File(
          _join(installDirectory.path, 'new-version.txt'),
        ).readAsString(),
        'installed\n',
      );
      expect(
        await File(
          _join(installDirectory.path, 'old-version.txt'),
        ).exists(),
        isFalse,
        reason: 'A successful replacement must remove old files.',
      );
      await Future<void>.delayed(const Duration(seconds: 6));
    } finally {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    }
  });
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
      ArchiveFile(
        'xueqing.exe',
        executableBytes.length,
        executableBytes,
      ),
    )
    ..addFile(
      ArchiveFile(
        'xueqing_updater.exe',
        helperBytes.length,
        helperBytes,
      ),
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
  );
}

String _join(String parent, String child) {
  return '$parent${Platform.pathSeparator}$child';
}
