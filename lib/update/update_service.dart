import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'update_models.dart';

typedef UpdateManifestLoader = Future<String> Function(Uri uri);

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

class UpdateService {
  UpdateService({
    required String currentVersion,
    this.platform,
    Uri? manifestUri,
    UpdateManifestLoader? manifestLoader,
    this.channel = 'stable',
    this.requestTimeout = const Duration(seconds: 12),
  }) : currentVersion = AppVersion.parse(currentVersion),
       manifestUri = manifestUri ?? defaultManifestUri,
       _manifestLoader = manifestLoader ?? _loadManifestFromNetwork;

  static final Uri defaultManifestUri = Uri.parse(
    'https://github.com/qbjsdsb/xueqing/releases/latest/download/'
    'update-manifest.json',
  );

  final AppVersion currentVersion;
  final UpdatePlatform? platform;
  final Uri manifestUri;
  final String channel;
  final Duration requestTimeout;
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

  Future<UpdateDownloadedArtifact> download(UpdateCheckResult result) async {
    if (!result.hasUpdate || result.artifact == null) {
      throw const UpdateException('当前没有可下载的更新。');
    }

    final artifact = result.artifact!;
    final temporaryDirectory = await getTemporaryDirectory();
    final updatesDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}xueqing-updates',
    );
    await updatesDirectory.create(recursive: true);

    final fileName = _safeFileName(artifact);
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

  static Future<String> _loadManifestFromNetwork(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
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
