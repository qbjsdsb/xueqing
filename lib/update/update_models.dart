import 'dart:collection';

enum UpdatePlatform {
  windows('windows'),
  android('android');

  const UpdatePlatform(this.manifestKey);

  final String manifestKey;

  static UpdatePlatform? tryParse(String value) {
    switch (value.trim().toLowerCase()) {
      case 'windows':
      case 'win':
        return UpdatePlatform.windows;
      case 'android':
      case 'apk':
        return UpdatePlatform.android;
      default:
        return null;
    }
  }
}

class AppVersion implements Comparable<AppVersion> {
  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.build = 0,
    this.prerelease = const <String>[],
  });

  factory AppVersion.parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      throw const FormatException('版本号不能为空。');
    }

    final plusParts = value.split('+');
    if (plusParts.length > 2) {
      throw FormatException('版本号的 build 部分无效：$raw');
    }
    final build = plusParts.length == 2
        ? _parseNonNegativeInt(plusParts[1], 'build', raw)
        : 0;

    final coreAndPrerelease = plusParts.first.split('-');
    if (coreAndPrerelease.length > 2) {
      throw FormatException('版本号的预发布部分无效：$raw');
    }
    final core = coreAndPrerelease.first.split('.');
    if (core.length != 3) {
      throw FormatException('版本号必须是 major.minor.patch：$raw');
    }

    final prerelease = coreAndPrerelease.length == 2
        ? coreAndPrerelease[1]
              .split('.')
              .map((part) => part.trim())
              .toList(growable: false)
        : const <String>[];
    if (prerelease.any((part) => part.isEmpty)) {
      throw FormatException('版本号的预发布标识不能为空：$raw');
    }

    return AppVersion(
      major: _parseNonNegativeInt(core[0], 'major', raw),
      minor: _parseNonNegativeInt(core[1], 'minor', raw),
      patch: _parseNonNegativeInt(core[2], 'patch', raw),
      build: build,
      prerelease: prerelease,
    );
  }

  final int major;
  final int minor;
  final int patch;
  final int build;
  final List<String> prerelease;

  static int _parseNonNegativeInt(String raw, String label, String source) {
    final value = raw.trim();
    if (value.isEmpty || !RegExp(r'^[0-9]+$').hasMatch(value)) {
      throw FormatException('版本号的 $label 部分无效：$source');
    }
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw FormatException('版本号的 $label 部分过大：$source');
    }
    return parsed;
  }

  @override
  int compareTo(AppVersion other) {
    final coreComparison = _compareIntegers(major, other.major);
    if (coreComparison != 0) {
      return coreComparison;
    }
    final minorComparison = _compareIntegers(minor, other.minor);
    if (minorComparison != 0) {
      return minorComparison;
    }
    final patchComparison = _compareIntegers(patch, other.patch);
    if (patchComparison != 0) {
      return patchComparison;
    }

    if (prerelease.isEmpty && other.prerelease.isNotEmpty) {
      return 1;
    }
    if (prerelease.isNotEmpty && other.prerelease.isEmpty) {
      return -1;
    }
    for (var index = 0;
        index < prerelease.length && index < other.prerelease.length;
        index++) {
      final left = prerelease[index];
      final right = other.prerelease[index];
      final leftNumber = int.tryParse(left);
      final rightNumber = int.tryParse(right);
      if (leftNumber != null && rightNumber != null) {
        final comparison = _compareIntegers(leftNumber, rightNumber);
        if (comparison != 0) {
          return comparison;
        }
      } else if (leftNumber != null) {
        return -1;
      } else if (rightNumber != null) {
        return 1;
      } else {
        final comparison = left.compareTo(right);
        if (comparison != 0) {
          return comparison;
        }
      }
    }
    final prereleaseLengthComparison =
        _compareIntegers(prerelease.length, other.prerelease.length);
    if (prereleaseLengthComparison != 0) {
      return prereleaseLengthComparison;
    }
    return _compareIntegers(build, other.build);
  }

  static int _compareIntegers(int left, int right) {
    return left == right ? 0 : (left < right ? -1 : 1);
  }

  @override
  String toString() {
    final pre = prerelease.isEmpty ? '' : '-\${prerelease.join('.')}';
    return '$major.$minor.$patch$pre+$build';
  }

  @override
  bool operator ==(Object other) {
    return other is AppVersion && compareTo(other) == 0;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch, build, prerelease);

  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator <=(AppVersion other) => compareTo(other) <= 0;
  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator >=(AppVersion other) => compareTo(other) >= 0;
}

class UpdateArtifact {
  const UpdateArtifact({
    required this.platform,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
    required this.format,
    this.fileName,
  });

  factory UpdateArtifact.fromJson(
    UpdatePlatform platform,
    Map<String, Object?> json,
  ) {
    final urlValue = json['url'];
    final url = urlValue is String ? urlValue.trim() : '';
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw FormatException(
        '\${platform.manifestKey} 更新地址必须是 HTTPS URL。',
      );
    }

    final hashValue = json['sha256'];
    final sha256 = hashValue is String ? hashValue.trim().toLowerCase() : '';
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw FormatException(
        '\${platform.manifestKey} 更新包 sha256 必须是 64 位十六进制字符串。',
      );
    }

    final sizeValue = json['size_bytes'];
    if (sizeValue is! int || sizeValue <= 0) {
      throw FormatException(
        '\${platform.manifestKey} 更新包 size_bytes 必须是正整数。',
      );
    }

    final formatValue = json['format'];
    final format = formatValue is String ? formatValue.trim().toLowerCase() : '';
    if (format.isEmpty) {
      throw FormatException('\${platform.manifestKey} 更新包 format 不能为空。');
    }

    final fileNameValue = json['file_name'];
    final fileName = fileNameValue is String ? fileNameValue.trim() : null;
    if (fileName != null &&
        (fileName.isEmpty ||
            fileName.contains('/') ||
            fileName.contains(r'\') ||
            fileName == '.' ||
            fileName == '..')) {
      throw const FormatException('更新包 file_name 无效。');
    }

    return UpdateArtifact(
      platform: platform,
      url: url,
      sha256: sha256,
      sizeBytes: sizeValue,
      format: format,
      fileName: fileName,
    );
  }

  final UpdatePlatform platform;
  final String url;
  final String sha256;
  final int sizeBytes;
  final String format;
  final String? fileName;
}

class UpdateManifest {
  const UpdateManifest({
    required this.schema,
    required this.channel,
    required this.version,
    required this.artifacts,
    this.minimumSupportedVersion,
    this.notes = const <String>[],
  });

  factory UpdateManifest.fromJson(Map<String, Object?> json) {
    final schemaValue = json['schema'];
    if (schemaValue is! int || schemaValue != 1) {
      throw FormatException('不支持的更新清单 schema：$schemaValue');
    }
    const schema = 1;

    final channelValue = json['channel'];
    final channel = channelValue is String ? channelValue.trim() : '';
    if (channel.isEmpty) {
      throw const FormatException('更新清单 channel 不能为空。');
    }

    final versionValue = json['version'];
    if (versionValue is! String) {
      throw const FormatException('更新清单 version 缺失。');
    }
    final version = AppVersion.parse(versionValue);

    AppVersion? minimumSupportedVersion;
    final minimumValue = json['minimum_supported'];
    if (minimumValue != null) {
      if (minimumValue is! String) {
        throw const FormatException('更新清单 minimum_supported 无效。');
      }
      minimumSupportedVersion = AppVersion.parse(minimumValue);
    }

    final rawNotes = json['notes'];
    final notes = rawNotes is List
        ? rawNotes
              .whereType<String>()
              .map((note) => note.trim())
              .where((note) => note.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    final rawPlatforms = json['platforms'];
    if (rawPlatforms is! Map) {
      throw const FormatException('更新清单 platforms 缺失。');
    }
    final artifacts = <UpdatePlatform, UpdateArtifact>{};
    for (final entry in rawPlatforms.entries) {
      final platform = UpdatePlatform.tryParse(entry.key.toString());
      if (platform == null) {
        continue;
      }
      if (entry.value is! Map) {
        throw FormatException('\${platform.manifestKey} 更新资产不是对象。');
      }
      artifacts[platform] = UpdateArtifact.fromJson(
        platform,
        Map<String, Object?>.from(entry.value as Map),
      );
    }
    if (artifacts.isEmpty) {
      throw const FormatException('更新清单没有可用的平台资产。');
    }

    return UpdateManifest(
      schema: schema,
      channel: channel,
      version: version,
      minimumSupportedVersion: minimumSupportedVersion,
      notes: UnmodifiableListView<String>(notes),
      artifacts: UnmodifiableMapView<UpdatePlatform, UpdateArtifact>(
        artifacts,
      ),
    );
  }

  final int schema;
  final String channel;
  final AppVersion version;
  final AppVersion? minimumSupportedVersion;
  final List<String> notes;
  final Map<UpdatePlatform, UpdateArtifact> artifacts;

  UpdateArtifact? artifactFor(UpdatePlatform? platform) {
    if (platform == null) {
      return null;
    }
    return artifacts[platform];
  }
}

enum UpdateCheckState {
  upToDate,
  available,
  unsupportedPlatform,
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.state,
    required this.currentVersion,
    required this.manifest,
    required this.platform,
  });

  final UpdateCheckState state;
  final AppVersion currentVersion;
  final UpdateManifest manifest;
  final UpdatePlatform? platform;

  bool get hasUpdate => state == UpdateCheckState.available;

  bool get isMandatory {
    final minimum = manifest.minimumSupportedVersion;
    return hasUpdate && minimum != null && currentVersion < minimum;
  }

  UpdateArtifact? get artifact => manifest.artifactFor(platform);
}
