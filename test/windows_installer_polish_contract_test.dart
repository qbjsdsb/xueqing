import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows installer stays teacher-friendly and upgrade-safe', () {
    final installer = File('installer/windows/xueqing.iss').readAsStringSync();

    expect(installer, contains('PrivilegesRequired=lowest'));
    expect(installer, contains('DefaultDirName={localappdata}\\Programs\\Xueqing'));
    expect(installer, contains('DisableDirPage=auto'));
    expect(installer, contains('DisableReadyPage=yes'));
    expect(installer, contains('UsePreviousAppDir=yes'));
    expect(installer, contains('UsePreviousTasks=yes'));
    expect(
      installer,
      contains(
        'Name: "chinesesimplified"; MessagesFile: '
        '"compiler:Languages\\ChineseSimplified.isl"',
      ),
    );
    expect(
      installer,
      contains(
        'Name: "desktopicon"; Description: "创建桌面快捷方式"; '
        'GroupDescription: "附加任务："; Flags: checkedonce',
      ),
    );
    expect(
      installer,
      contains(
        'Name: "{autodesktop}\\{#AppName}"; '
        'Filename: "{app}\\{#AppExeName}"; WorkingDir: "{app}"; '
        'Tasks: desktopicon',
      ),
    );
    expect(
      installer,
      contains(
        'CloseApplicationsFilter=xueqing.exe,xueqing_updater.exe,'
        'xueqing_updater_bootstrap.exe',
      ),
    );
    expect(installer, contains('RestartApplications=no'));
  });

  test('every CI installer build runs an in-place upgrade smoke', () {
    final buildScript = File(
      'tools/windows_installer/build_installer.ps1',
    ).readAsStringSync();
    final smokeScript = File(
      'tools/windows_installer/smoke_installer.ps1',
    ).readAsStringSync();

    expect(buildScript, contains(r'$env:CI -eq "true"'));
    expect(buildScript, contains('smoke_installer.ps1'));
    expect(buildScript, contains('-SkipSmoke'));

    expect(smokeScript, contains('0.0.1-preupgrade'));
    expect(smokeScript, contains('/MERGETASKS=\"!desktopicon\"'));
    expect(smokeScript, contains('upgrade-preserve-probe.txt'));
    expect(smokeScript, contains('DisplayVersion -ne \$AppVersion'));
    expect(
      smokeScript,
      contains(
        'Windows installer fresh-install, task persistence, in-place upgrade, '
        'and uninstall smoke passed.',
      ),
    );
  });
}
