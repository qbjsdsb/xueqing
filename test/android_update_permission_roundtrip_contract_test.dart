import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android update permission returns to the same verified APK install', () {
    final native = File(
      'android/app/src/main/kotlin/com/xueqing/app/MainActivity.kt',
    ).readAsStringSync();
    final installer = File('lib/update/update_installer.dart').readAsStringSync();

    expect(native, contains('UNKNOWN_SOURCES_REQUEST'));
    expect(native, contains('pendingInstallPath'));
    expect(native, contains('pendingInstallResult'));
    expect(native, contains('startActivityForResult('));
    expect(native, contains('override fun onActivityResult'));
    expect(native, contains('packageManager.canRequestPackageInstalls()'));
    expect(native, contains('validateUpdateApk(path, result)'));
    expect(native, contains('startApkInstaller(apk, result)'));
    expect(native, contains('File(cacheDir, "xueqing-updates").canonicalFile'));
    expect(native, contains('FLAG_GRANT_READ_URI_PERMISSION'));

    final validateBeforePermission = native.indexOf(
      'val apk = validateUpdateApk(path, result) ?: return',
    );
    final permissionCheck = native.indexOf(
      '!packageManager.canRequestPackageInstalls()',
    );
    expect(validateBeforePermission, greaterThanOrEqualTo(0));
    expect(permissionCheck, greaterThan(validateBeforePermission));

    expect(installer, contains("if (status == 'permission_required')"));
    expect(installer, contains('尚未允许学情安装更新'));
  });
}
