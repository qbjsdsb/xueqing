import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/update/update_models.dart';
import 'package:xueqing/update/update_service.dart';

void main() {
  const hash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

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
      'platforms':
          platforms ??
          <String, Object?>{
            'windows': <String, Object?>{
              'url': 'https://github.com/qbjsdsb/xueqing/releases/download/v0.2.0/xueqing-windows.zip',
              'sha256': hash,
              'size_bytes': 42,
              'format': 'zip',
              'file_name': 'xueqing-windows.zip',
            },
          },
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
        manifest()
          ..['platforms'] = <String, Object?>{
            'windows': <String, Object?>{
              'url': 'http://example.com/update.zip',
              'sha256': hash,
              'size_bytes': 42,
              'format': 'zip',
            },
          },
      ),
      throwsA(isA<FormatException>()),
    );
  });

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
}
