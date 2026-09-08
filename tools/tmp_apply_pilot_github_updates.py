from pathlib import Path


def once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, got {count}')
    return text.replace(old, new, 1)


service = Path('lib/update/update_service.dart')
text = service.read_text()
text = once(
    text,
    "  UpdateService({\n    required String currentVersion,\n    this.platform,\n    Uri? manifestUri,\n    UpdateManifestLoader? manifestLoader,\n    this.channel = 'stable',\n    this.requestTimeout = const Duration(seconds: 12),\n    this.maxDownloadBytes = defaultMaxDownloadBytes,\n  }) : currentVersion = AppVersion.parse(currentVersion),\n       manifestUri = manifestUri ?? defaultManifestUri,\n       _manifestLoader = manifestLoader ?? _loadManifestFromNetwork;",
    "  UpdateService({\n    required String currentVersion,\n    UpdatePlatform? platform,\n    Uri? manifestUri,\n    UpdateManifestLoader? manifestLoader,\n    this.channel = 'stable',\n    this.requestTimeout = const Duration(seconds: 12),\n    this.maxDownloadBytes = defaultMaxDownloadBytes,\n  }) : currentVersion = AppVersion.parse(currentVersion),\n       platform = platform ?? currentPlatform,\n       manifestUri = manifestUri ?? defaultManifestUri,\n       _manifestLoader = manifestLoader ?? _loadManifestFromNetwork;\n\n  factory UpdateService.githubPilot({\n    required String currentVersion,\n    UpdatePlatform? platform,\n    UpdateManifestLoader? manifestLoader,\n    Duration requestTimeout = const Duration(seconds: 12),\n    int maxDownloadBytes = defaultMaxDownloadBytes,\n  }) {\n    return UpdateService(\n      currentVersion: currentVersion,\n      platform: platform,\n      manifestUri: githubPilotReleasesUri,\n      manifestLoader: manifestLoader ?? _loadPilotManifestFromGitHub,\n      channel: 'pilot',\n      requestTimeout: requestTimeout,\n      maxDownloadBytes: maxDownloadBytes,\n    );\n  }",
    'constructor',
)
text = once(
    text,
    "  static final Uri pilotManifestUri = Uri.parse(\n    'https://github.com/qbjsdsb/xueqing/releases/download/'\n    'pilot-channel/update-manifest.json',\n  );",
    "  static final Uri githubPilotReleasesUri = Uri.parse(\n    'https://api.github.com/repos/qbjsdsb/xueqing/releases?per_page=20',\n  );\n\n  static UpdatePlatform? get currentPlatform {\n    if (Platform.isWindows) return UpdatePlatform.windows;\n    if (Platform.isAndroid) return UpdatePlatform.android;\n    return null;\n  }",
    'pilot URI',
)
anchor = "  static Future<String> _loadManifestFromNetwork(Uri uri) async {\n"
loader = r'''  static Future<String> _loadPilotManifestFromGitHub(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
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
      if (version.prerelease.length < 2 || version.prerelease.first != 'pilot') {
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
        if (url is! String || size is! int || size <= 0 || rawDigest is! String) {
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
      throw const FormatException('最新 Pilot Release 缺少 Android APK 或 Windows 更新 ZIP。');
    }

    return jsonEncode(<String, Object?>{
      'schema': 1,
      'channel': 'pilot',
      'version': selectedVersion.toString(),
      'notes': const <String>['Xueqing 内部 Pilot 更新'],
      'platforms': <String, Object?>{
        'android': android,
        'windows': windows,
      },
    });
  }

'''
if text.count(anchor) != 1:
    raise SystemExit('network loader anchor mismatch')
text = text.replace(anchor, loader + anchor, 1)
service.write_text(text)

workspace = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
text = workspace.read_text()
text = once(
    text,
    "    _updateService = UpdateService(currentVersion: widget.config.appVersion);",
    "    _updateService = widget.config.environment.isProduction\n        ? UpdateService(currentVersion: widget.config.appVersion)\n        : UpdateService.githubPilot(currentVersion: widget.config.appVersion);",
    'workspace update service',
)
workspace.write_text(text)

test = Path('test/update/update_service_test.dart')
text = test.read_text()
insert = """

  test('GitHub Pilot catalog selects newest complete prerelease and digest', () async {
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

    final raw = UpdateService.pilotManifestFromGitHubReleasesForTest(releases);
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
  });

  test('GitHub Pilot catalog fails closed when latest release is incomplete', () {
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
  });
"""
# Insert before the final closing brace of main(). This test file has one top-level main block.
last = text.rfind('\n}')
if last < 0:
    raise SystemExit('test main closing brace not found')
text = text[:last] + insert + text[last:]
test.write_text(text)
