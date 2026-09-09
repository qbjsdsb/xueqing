import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release source version stays aligned and newer than v0.2.1 stable', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final appConfig = File('lib/config/app_config.dart').readAsStringSync();

    final pubspecMatch = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+\+\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(pubspecMatch, isNotNull);
    final sourceVersion = pubspecMatch!.group(1)!;

    final runtimeDefaults = RegExp(
      r"(?:defaultValue:\s*|String appVersion = )'([^']+)'",
    ).allMatches(appConfig).map((match) => match.group(1)).whereType<String>();

    expect(runtimeDefaults, isNotEmpty);
    expect(runtimeDefaults, everyElement(sourceVersion));

    final buildNumber = int.parse(sourceVersion.split('+').last);
    expect(
      buildNumber,
      greaterThan(7),
      reason: 'v0.2.1 Stable was published with Android versionCode 7.',
    );
  });
}
