import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

int _be32(List<int> bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

void main() {
  test('Android and Windows ship the selected 学情 app icon', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));

    final sourceMark = File('branding/xueqing_app_icon.svg').readAsStringSync();
    expect(sourceMark, contains('#F7F8F6'));
    expect(sourceMark, contains('#2F8E79'));
    expect(sourceMark, contains('#C9EBC4'));
    expect(sourceMark, contains('<circle cx="512" cy="303"'));

    final adaptive26 = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    expect(adaptive26, contains('@drawable/ic_launcher_background'));
    expect(adaptive26, contains('@drawable/ic_launcher_foreground'));
    expect(adaptive26, isNot(contains('<monochrome')));

    final background = File(
      'android/app/src/main/res/drawable/ic_launcher_background.xml',
    ).readAsStringSync();
    expect(background, contains('#F7F8F6'));
    expect(background, contains('#EEF7F2'));

    final foreground = File(
      'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
    ).readAsStringSync();
    expect(foreground, contains('android:viewportWidth="108"'));
    // The selected mark is intentionally one quiet symbol: learner / growth
    // point over two book-page or leaf forms, using the product green family.
    expect(foreground, contains('#72C86E'));
    expect(foreground, contains('#0C8B78'));
    expect(foreground, contains('#2D8A76'));
    expect(foreground, contains('#C8EBC2'));
    expect(foreground, contains('M54,24'));
    expect(foreground, contains('M54,82'));

    final adaptive33 = File(
      'android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml',
    ).readAsStringSync();
    expect(adaptive33, contains('<monochrome'));
    expect(adaptive33, contains('@drawable/ic_launcher_monochrome'));

    final monochrome = File(
      'android/app/src/main/res/drawable/ic_launcher_monochrome.xml',
    ).readAsStringSync();
    expect(monochrome, contains('android:viewportWidth="108"'));
    expect(monochrome, contains('M54,24'));
    expect(monochrome, contains('M54,82'));

    // API 23-25 still gets the same identity instead of falling back to the
    // pre-v0.3.7 book placeholder.
    final fallback23 = File(
      'android/app/src/main/res/mipmap-anydpi-v23/ic_launcher.xml',
    ).readAsStringSync();
    expect(fallback23, contains('#F7F8F6'));
    expect(fallback23, contains('#146F63'));
    expect(fallback23, contains('#8ED2AA'));

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

    // Windows keeps several native icon sizes so Explorer, Start, taskbar and
    // the installer do not have to stretch one bitmap at every scale.
    final ico = File('windows/runner/resources/app_icon.ico').readAsBytesSync();
    expect(ico.length, greaterThan(4096));
    expect(ico.take(4).toList(), <int>[0, 0, 1, 0]);
    final imageCount = ico[4] | (ico[5] << 8);
    expect(imageCount, greaterThanOrEqualTo(8));
    final icoSizes = <int>{};
    for (var index = 0; index < imageCount; index += 1) {
      final entryOffset = 6 + (index * 16);
      expect(entryOffset + 15, lessThan(ico.length));
      final width = ico[entryOffset] == 0 ? 256 : ico[entryOffset];
      final height = ico[entryOffset + 1] == 0 ? 256 : ico[entryOffset + 1];
      if (width == height) {
        icoSizes.add(width);
      }
    }
    expect(icoSizes, containsAll(<int>[16, 32, 48, 128, 256]));

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
