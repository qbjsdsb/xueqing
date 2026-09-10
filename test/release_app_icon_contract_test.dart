import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

int _be32(List<int> bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

void main() {
  test('Android and Windows ship the real 学情 app icon', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));

    final adaptive26 = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    expect(adaptive26, contains('@color/ic_launcher_background'));
    expect(adaptive26, contains('@drawable/ic_launcher_foreground'));
    expect(adaptive26, isNot(contains('<monochrome')));

    final foreground = File(
      'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
    ).readAsStringSync();
    expect(foreground, contains('android:viewportWidth="108"'));
    expect(foreground, contains('#F8F6EF'));
    // Keep the mark optically smaller than v0.3.0 and soften the book-page
    // silhouette with curves instead of restoring the old sharp polygon.
    expect(foreground, contains('M51.2,35.0'));
    expect(foreground, contains('L77.2,31.5'));
    expect(foreground, contains('Q41.8,72.0'));
    expect(foreground, contains('Q67.8,33.0'));
    expect(foreground, isNot(contains('M50.9,34.2')));
    expect(foreground, isNot(contains('L80.0,29.2')));

    final adaptive33 = File(
      'android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml',
    ).readAsStringSync();
    expect(adaptive33, contains('<monochrome'));
    expect(adaptive33, contains('@drawable/ic_launcher_foreground'));

    const androidIcons = <String, int>{
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final entry in androidIcons.entries) {
      final bytes = File(
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
      ).readAsBytesSync();
      expect(bytes.take(8).toList(), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
      expect(_be32(bytes, 16), entry.value);
      expect(_be32(bytes, 20), entry.value);
    }

    final ico = File('windows/runner/resources/app_icon.ico').readAsBytesSync();
    expect(ico.length, greaterThan(4096));
    expect(ico.take(4).toList(), <int>[0, 0, 1, 0]);
    final imageCount = ico[4] | (ico[5] << 8);
    expect(imageCount, greaterThanOrEqualTo(8));

    final rc = File('windows/runner/Runner.rc').readAsStringSync();
    expect(
      rc,
      contains(
        r'IDI_APP_ICON            ICON                    "resources\\app_icon.ico"',
      ),
    );
    final installer = File('installer/windows/xueqing.iss').readAsStringSync();
    expect(
      installer,
      contains(r'SetupIconFile=..\..\windows\runner\resources\app_icon.ico'),
    );
  });
}
