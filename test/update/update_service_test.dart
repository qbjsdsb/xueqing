import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/update/update_models.dart';
import 'package:xueqing/update/update_service.dart';

void main() {
  const hash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  Map<String, Object?> artifact({
    String url =
        'https://github.com/qbjsdsb/xueqing/releases/download/v0.2.0/'
        'xueqing-windows.zip',
    String format = 'zip',
    String fileName = 'xueqing-windows.zip',
  }) {
    return <String, Object?>{
      'url': url,
      'sha256': hash,
      'size_bytes': 42,
      'format': format,
      'file_name': fileName,
    };
  }

  Map<String, Object?> manifest({
    String version = '0.2.0+2',
    String minimumSupported = '0.1.5+1',
    Map<String, Object?>? platforms,
  }) {
    return <String, Object?>{
      'schema': 1,
      'channel': 'stable',
      'version': version,
      'minimum_supported': minimumSupported,
      'notes': <String>['提升稳定性', '修复更新流程'],
      'platforms': platforms ?? <String, Object?>{'windows': artifact()},
    };
  }

  test('compares Flutter versions including prerelease and build number', () {
    expect(
      AppVersion.parse('1.2.3-beta.2+4'),
      lessThan(AppVersion.parse('1.2.3+1')),
    );
    expect(
      AppVersion.parse('1.2.3+5'),
      greaterThan(AppVersion.parse('1.2.3+4')),
    );
    expect(
      AppVersion.parse('1.2.4+1'),
      greaterThan(AppVersion.parse('1.2.3+99')),
    );
  });

  test('rejects malformed artifact security fields', () {
    expect(
      () => UpdateManifest.fromJson(
        manifest(
          platforms: <String, Object?>{
            'windows': artifact(url: 'http://example.com/update.zip'),
          },
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects platform artifact formats before download', () {
    expect(
      () => UpdateManifest.fromJson(
        manifest(
          platforms: <String, Object?>{
            'windows': artifact(format: 'apk', fileName: 'xueqing-windows.apk'),
          },
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => UpdateManifest.fromJson(
        manifest(
          platforms: <String, Object?>{
            'android': artifact(
              url: 'https://example.com/xueqing-android.zip',
              format: 'zip',
              fileName: 'xueqing-android.zip',
            ),
          },
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects an explicit file name that disagrees with platform format', () {
    expect(
      () => UpdateManifest.fromJson(
        manifest(
          platforms: <String, Object?>{
            'windows': artifact(fileName: 'xueqing-windows.exe'),
          },
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('accepts the expected Android APK contract', () {
    final parsed = UpdateManifest.fromJson(
      manifest(
        platforms: <String, Object?>{
          'android': artifact(
            url: 'https://example.com/xueqing-android.apk',
            format: 'apk',
            fileName: 'xueqing-android.apk',
          ),
        },
      ),
    );

    expect(parsed.artifacts[UpdatePlatform.android]?.format, 'apk');
  });

  test('rejects non-canonical platform aliases in the manifest', () {
    expect(
      () => UpdateManifest.fromJson(
        manifest(
          platforms: <String, Object?>{
            'apk': artifact(
              url: 'https://example.com/xueqing-android.apk',
              format: 'apk',
              fileName: 'xueqing-android.apk',
            ),
          },
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects minimum_supported above the offered version', () {
    expect(
      () => UpdateManifest.fromJson(
        manifest(version: '0.2.0+2', minimumSupported: '0.3.0+1'),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'prunes stale update files but keeps current target and directories',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'xueqing-update-cache-test-',
      );
      try {
        final stale = File(
          '${directory.path}${Platform.pathSeparator}xueqing-v0.1.0.apk',
        );
        final current = File(
          '${directory.path}${Platform.pathSeparator}xueqing-v0.2.0.apk',
        );
        final nested = Directory(
          '${directory.path}${Platform.pathSeparator}keep-directory',
        );
        await stale.writeAsBytes(<int>[1]);
        await current.writeAsBytes(<int>[2]);
        await nested.create();

        await pruneStaleUpdateDownloads(
          directory,
          keepFileName: 'xueqing-v0.2.0.apk',
        );

        expect(await stale.exists(), isFalse);
        expect(await current.exists(), isTrue);
        expect(await nested.exists(), isTrue);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'rejects an artifact larger than the configured download limit',
    () async {
      final service = UpdateService(
        currentVersion: '0.1.0+1',
        platform: UpdatePlatform.windows,
        maxDownloadBytes: 10,
        manifestLoader: (_) async => jsonEncode(manifest()),
      );

      final result = await service.checkForUpdate();

      expect(service.download(result), throwsA(isA<UpdateException>()));
    },
  );

  test('reports an available mandatory Windows update', () async {
    final service = UpdateService(
      currentVersion: '0.1.0+1',
      platform: UpdatePlatform.windows,
      manifestLoader: (_) async => jsonEncode(manifest()),
    );

    final result = await service.checkForUpdate();

    expect(result.state, UpdateCheckState.available);
    expect(result.isMandatory, isTrue);
    expect(result.artifact?.platform, UpdatePlatform.windows);
  });

  test('reports up to date without downloading an older manifest', () async {
    final service = UpdateService(
      currentVersion: '0.2.0+2',
      platform: UpdatePlatform.windows,
      manifestLoader: (_) async => jsonEncode(manifest()),
    );

    final result = await service.checkForUpdate();

    expect(result.state, UpdateCheckState.upToDate);
    expect(result.hasUpdate, isFalse);
  });

  test('reports unsupported platforms explicitly', () async {
    final service = UpdateService(
      currentVersion: '0.1.0+1',
      platform: UpdatePlatform.android,
      manifestLoader: (_) async => jsonEncode(manifest()),
    );

    final result = await service.checkForUpdate();

    expect(result.state, UpdateCheckState.unsupportedPlatform);
    expect(result.artifact, isNull);
  });

  test('rejects a mismatched update channel', () async {
    final service = UpdateService(
      currentVersion: '0.1.0+1',
      platform: UpdatePlatform.windows,
      manifestLoader: (_) async =>
          jsonEncode(manifest()..['channel'] = 'preview'),
    );

    expect(service.checkForUpdate(), throwsA(isA<UpdateException>()));
  });

  test(
    'GitHub Pilot catalog selects newest complete prerelease and digest',
    () async {
      final releases = <Object?>[
        <String, Object?>{
          'tag_name': 'v0.2.0-pilot.2',
          'draft': false,
          'prerelease': true,
          'assets': <Object?>[
            <String, Object?>{
              'name': 'xueqing-v0.2.0-pilot.2-android.apk',
              'browser_download_url': 'https://github.com/example/android2.apk',
              'size': 20,
              'digest': 'sha256:${'a' * 64}',
            },
            <String, Object?>{
              'name': 'xueqing-v0.2.0-pilot.2-windows.zip',
              'browser_download_url': 'https://github.com/example/windows2.zip',
              'size': 30,
              'digest': 'sha256:${'b' * 64}',
            },
          ],
        },
        <String, Object?>{
          'tag_name': 'v0.2.0-pilot.3',
          'draft': false,
          'prerelease': true,
          'assets': <Object?>[
            <String, Object?>{
              'name': 'xueqing-v0.2.0-pilot.3-android.apk',
              'browser_download_url': 'https://github.com/example/android3.apk',
              'size': 40,
              'digest': 'sha256:${'c' * 64}',
            },
            <String, Object?>{
              'name': 'xueqing-v0.2.0-pilot.3-windows.zip',
              'browser_download_url': 'https://github.com/example/windows3.zip',
              'size': 50,
              'digest': 'sha256:${'d' * 64}',
            },
          ],
        },
      ];

      final raw = UpdateService.pilotManifestFromGitHubReleasesForTest(
        releases,
      );
      final service = UpdateService.githubPilot(
        currentVersion: '0.2.0-pilot.2+3',
        platform: UpdatePlatform.android,
        manifestLoader: (_) async => raw,
      );
      final result = await service.checkForUpdate();

      expect(service.channel, 'pilot');
      expect(service.manifestUri, UpdateService.githubPilotReleasesUri);
      expect(result.hasUpdate, isTrue);
      expect(result.manifest.version, AppVersion.parse('0.2.0-pilot.3+0'));
      expect(result.artifact?.sha256, 'c' * 64);
    },
  );

  test(
    'GitHub Pilot catalog fails closed when latest release is incomplete',
    () {
      final releases = <Object?>[
        <String, Object?>{
          'tag_name': 'v0.2.0-pilot.3',
          'draft': false,
          'prerelease': true,
          'assets': <Object?>[
            <String, Object?>{
              'name': 'xueqing-v0.2.0-pilot.3-android.apk',
              'browser_download_url': 'https://github.com/example/android3.apk',
              'size': 40,
              'digest': 'sha256:${'c' * 64}',
            },
          ],
        },
      ];

      expect(
        () => UpdateService.pilotManifestFromGitHubReleasesForTest(releases),
        throwsFormatException,
      );
    },
  );

  test('stable updater explains a missing manifest without raw HTTP details', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) {
      request.response.statusCode = HttpStatus.notFound;
      unawaited(request.response.close());
    });
    try {
      final service = UpdateService(
        currentVersion: '0.2.0+4',
        platform: UpdatePlatform.android,
        manifestUri: Uri.parse(
          'http://${server.address.address}:${server.port}/update-manifest.json',
        ),
      );

      await expectLater(
        service.checkForUpdate(),
        throwsA(
          isA<UpdateException>().having(
            (error) => error.userMessage,
            'userMessage',
            '当前还没有可用的稳定更新。',
          ),
        ),
      );
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
