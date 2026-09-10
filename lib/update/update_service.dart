import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'update_models.dart';

typedef UpdateManifestLoader = Future<String> Function(Uri uri);
typedef UpdateDownloadProgress = void Function(
  int downloadedBytes,
  int totalBytes,
);

class UpdateException implements Exception {
  const UpdateException(this.userMessage, {this.cause});

  final String userMessage;
  final Object? cause;

  @override
  String toString() => userMessage;
}

class UpdateDownloadedArtifact {
  const UpdateDownloadedArtifact({required this.artifact, required this.file});

  final UpdateArtifact artifact;
  final File file;
}

Future<void> pruneStaleUpdateDownloads(
  Directory directory, {
  required String keepFileName,
}) async {
  try {
    if (!await directory.exists()) {
      return;
    }
    final keepPath = File(
      '${directory.path}${Platform.pathSeparator}$keepFileName',
    ).absolute.path;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || entity.absolute.path == keepPath) {
        continue;
      }
      try {
        await entity.delete();
      } catch (_) {
        // Cache cleanup is best effort and must never block an update.
      }
    }
  } catch (_) {
    // A broken or temporarily unavailable cache directory must not turn a
    // valid update into a failure. The verified destination is still safe.
  }
}

class UpdateService {
  static const defaultMaxDownloadBytes = 1024 * 1024 * 1024;

  UpdateService({
    required String currentVersion,
    UpdatePlatform? platform,
    Uri? manifestUri,
    UpdateManifestLoader? manifestLoader,
    this.channel = 'stable',
    this.requestTimeout = const Duration(seconds: 12),
    this.maxDownloadBytes = defaultMaxDownloadBytes,
  }) : currentVersion = AppVersion.parse(currentVersion),
       platform = platform ?? currentPlatform,
       manifestUri = manifestUri ?? defaultManifestUri,
       _manifestLoader = manifestLoader ?? _loadManifestFromNetwork;

  factory UpdateService.githubPilot({
    required String currentVersion,
    UpdatePlatform? platform,
    UpdateManifestLoader? manifestLoader,
    Duration requestTimeout = const Duration(seconds: 12),
    int maxDownloadBytes = defaultMaxDownloadBytes,
  }) {
    return UpdateService(
      currentVersion: currentVersion,
      platform: platform,
      manifestUri: githubPilotReleasesUri,
      manifestLoader: manifestLoader ?? _loadPilotManifestFromGitHub,
      channel: 'pilot',
      requestTimeout: requestTimeout,
      maxDownloadBytes: maxDownloadBytes,
    );
  }

  static final Uri defaultManifestUri = Uri.parse(
    'https://github.com/qbjsdsb/xueqing/releases/latest/download/'
    'update-manifest.json',
  );

  static final Uri githubPilotReleasesUri = Uri.parse(
    'https://api.github.com/repos/qbjsdsb/xueqing/releases?per_page=20',
  );

  static UpdatePlatform? get currentPlatform {
    if (Platform.isWindows) return UpdatePlatform.windows;
    if (Platform.isAndroid) return UpdatePlatform.android;
    return null;
  }

  final AppVersion currentVersion;
  final UpdatePlatform? platform;
  final Uri manifestUri;
  final String channel;
  final Duration requestTimeout;
  final int maxDownloadBytes;
  final UpdateManifestLoader _manifestLoader;

  Future<UpdateCheckResult> checkForUpdate() async {
    final rawManifest = await _loadManifest();
    late final UpdateManifest manifest;
    try {
      final decoded = jsonDecode(rawManifest);
      if (decoded is! Map) {
        throw const FormatException('更新清单根节点必须是对象。');
      }
      manifest = UpdateManifest.fromJson(Map<String, Object?>.from(decoded));
    } on FormatException catch (error) {
      throw UpdateException('更新清单格式无效，已停止本次更新。', cause: error);
    } on Object catch (error) {
      throw UpdateException('更新清单无法解析，已停止本次更新。', cause: error);
    }

    if (manifest.channel != channel) {
      throw UpdateException('当前更新通道为“$channel”，服务器清单通道为“${manifest.channel}”。');
    }

    final comparison = manifest.version.compareTo(currentVersion);
    if (comparison <= 0) {
      return UpdateCheckResult(
        state: UpdateCheckState.upToDate,
        currentVersion: currentVersion,
        manifest: manifest,
        platform: platform,
      );
    }
    if (manifest.artifactFor(platform) == null) {
      return UpdateCheckResult(
        state: UpdateCheckState.unsupportedPlatform,
        currentVersion: currentVersion,
        manifest: manifest,
        platform: platform,
      );
    }
    return UpdateCheckResult(
      state: UpdateCheckState.available,
      currentVersion: currentVersion,
      manifest: manifest,
      platform: platform,
    );
  }

  Future<UpdateDownloadedArtifact> download(
    UpdateCheckResult result, {
    UpdateDownloadProgress? onProgress,
  }) async {
    if (!result.hasUpdate || result.artifact == null) {
      throw const UpdateException('当前没有可下载的更新。');
    }

    final artifact = result.artifact!;
    if (artifact.sizeBytes > maxDownloadBytes) {
      throw const UpdateException('更新包超过允许的最大大小，已停止下载。');
    }
    onProgress?.call(0, artifact.sizeBytes);
    final temporaryDirectory = await getTemporaryDirectory();
    final updatesDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}xueqing-updates',
    );
    await updatesDirectory.create(recursive: true);

    final fileName = _safeFileName(artifact);
    await pruneStaleUpdateDownloads(updatesDirectory, keepFileName: fileName);
    final destination = File(
      '${updatesDirectory.path}${Platform.pathSeparator}$fileName',
    );
    final client = HttpClient()
      ..connectionTimeout = requestTimeout
      ..idleTimeout = requestTimeout;

    IOSink? sink;
    var verified = false;
    try {
      final request = await client.getUrl(Uri.parse(artifact.url));
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(HttpHeaders.acceptHeader, '*/*');
      final response = await request.close().timeout(requestTimeout);
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException('下载更新失败（HTTP ${response.statusCode}）。');
      }

      final digestSink = AccumulatorSink<Digest>();
      final digestInput = sha256.startChunkedConversion(digestSink);
      sink = destination.openWrite();
      var downloadedBytes = 0;
      await for (final chunk in response) {
        downloadedBytes += chunk.length;
        if (downloadedBytes > artifact.sizeBytes) {
          throw const UpdateException('下载内容超过清单声明大小，已停止。');
        }
        onProgress?.call(downloadedBytes, artifact.sizeBytes);
        digestInput.add(chunk);
        sink.add(chunk);
      }
      digestInput.close();
      await sink.flush();
      await sink.close();
      sink = null;

      final digest = digestSink.events.single.toString();
      if (downloadedBytes != artifact.sizeBytes || digest != artifact.sha256) {
        throw const UpdateException('更新包校验失败，已删除不完整文件。');
      }
      verified = true;
      onProgress?.call(artifact.sizeBytes, artifact.sizeBytes);
      return UpdateDownloadedArtifact(artifact: artifact, file: destination);
    } on UpdateException {
      rethrow;
    } on TimeoutException {
      throw const UpdateException('下载更新超时，请稍后重试。');
    } on Object catch (error) {
      throw UpdateException('下载更新失败，请检查网络后重试。', cause: error);
    } finally {
      await sink?.close();
      client.close(force: true);
      if (!verified && await destination.exists()) {
        try {
          await destination.delete();
        } catch (_) {
          // A later attempt will replace the file after re-verifying the digest.
        }
      }
    }
  }

  Future<String> _loadManifest() async {
    try {
      return await _manifestLoader(manifestUri).timeout(requestTimeout);
    } on UpdateException {
      rethrow;
    } on TimeoutException {
      throw const UpdateException('检查更新超时，请稍后重试。');
    } on Object catch (error) {
      throw UpdateException('检查更新失败，请检查网络后重试。', cause: error);
    }
  }

  static Future<String> _loadPilotManifestFromGitHub(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set(HttpHeaders.userAgentHeader, 'Xueqing-Updater');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException('检查 Pilot 更新失败（HTTP ${response.statusCode}）。');
      }
      if (body.length > 2 * 1024 * 1024) {
        throw const UpdateException('GitHub Release 列表过大，已停止处理。');
      }
      final decoded = jsonDecode(body);
      if (decoded is! List) {
        throw const UpdateException('GitHub Release 返回格式无效。');
      }
      return _pilotManifestFromGitHubReleases(decoded);
    } on UpdateException {
      rethrow;
    } on FormatException catch (error) {
      throw UpdateException('GitHub Pilot Release 信息无效。', cause: error);
    } finally {
      client.close(force: true);
    }
  }

  static String pilotManifestFromGitHubReleasesForTest(List<Object?> releases) {
    return _pilotManifestFromGitHubReleases(releases);
  }

  static String _pilotManifestFromGitHubReleases(List<dynamic> releases) {
    Map<dynamic, dynamic>? selected;
    AppVersion? selectedVersion;
    String? selectedTag;

    for (final rawRelease in releases) {
      if (rawRelease is! Map ||
          rawRelease['draft'] == true ||
          rawRelease['prerelease'] != true) {
        continue;
      }
      final rawTag = rawRelease['tag_name'];
      if (rawTag is! String || rawTag.trim().isEmpty) continue;
      final tag = rawTag.trim();
      final versionText = tag.startsWith('v') ? tag.substring(1) : tag;
      late final AppVersion version;
      try {
        version = AppVersion.parse(versionText);
      } on FormatException {
        continue;
      }
      if (version.prerelease.length < 2 ||
          version.prerelease.first != 'pilot') {
        continue;
      }
      if (selectedVersion == null || version > selectedVersion) {
        selected = rawRelease;
        selectedVersion = version;
        selectedTag = tag;
      }
    }

    if (selected == null || selectedVersion == null || selectedTag == null) {
      throw const FormatException('没有找到可用的 Pilot Release。');
    }

    final rawAssets = selected['assets'];
    if (rawAssets is! List) {
      throw const FormatException('Pilot Release 没有资产列表。');
    }

    Map<String, Object?>? assetFor(String expectedName, String format) {
      for (final rawAsset in rawAssets) {
        if (rawAsset is! Map || rawAsset['name'] != expectedName) continue;
        final url = rawAsset['browser_download_url'];
        final size = rawAsset['size'];
        final rawDigest = rawAsset['digest'];
        if (url is! String ||
            size is! int ||
            size <= 0 ||
            rawDigest is! String) {
          throw FormatException('$expectedName 缺少可验证的 Release 元数据。');
        }
        final digest = rawDigest.trim().toLowerCase();
        if (!digest.startsWith('sha256:')) {
          throw FormatException('$expectedName 缺少 SHA-256 digest。');
        }
        final sha256 = digest.substring('sha256:'.length);
        if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
          throw FormatException('$expectedName 的 SHA-256 digest 无效。');
        }
        return <String, Object?>{
          'url': url,
          'sha256': sha256,
          'size_bytes': size,
          'format': format,
          'file_name': expectedName,
        };
      }
      return null;
    }

    final androidName = 'xueqing-$selectedTag-android.apk';
    final windowsName = 'xueqing-$selectedTag-windows.zip';
    final android = assetFor(androidName, 'apk');
    final windows = assetFor(windowsName, 'zip');
    if (android == null || windows == null) {
      throw const FormatException(
        '最新 Pilot Release 缺少 Android APK 或 Windows 更新 ZIP。',
      );
    }

    return jsonEncode(<String, Object?>{
      'schema': 1,
      'channel': 'pilot',
      'version': selectedVersion.toString(),
      'notes': const <String>['Xueqing 内部 Pilot 更新'],
      'platforms': <String, Object?>{'android': android, 'windows': windows},
    });
  }

  static Future<String> _loadManifestFromNetwork(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == HttpStatus.notFound) {
        throw const UpdateException('当前还没有可用的稳定更新。');
      }
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException('检查更新失败（HTTP ${response.statusCode}）。');
      }
      if (body.length > 1024 * 1024) {
        throw const UpdateException('更新清单过大，已停止处理。');
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }

  static String _safeFileName(UpdateArtifact artifact) {
    final fileName =
        artifact.fileName ??
        Uri.parse(artifact.url).pathSegments.lastWhere(
          (segment) => segment.isNotEmpty,
          orElse: () => 'xueqing-update.${artifact.format}',
        );
    if (fileName.isEmpty ||
        fileName == '.' ||
        fileName == '..' ||
        fileName.contains('/') ||
        fileName.contains(r'\')) {
      throw const UpdateException('更新文件名无效，已停止下载。');
    }
    return fileName;
  }
}
