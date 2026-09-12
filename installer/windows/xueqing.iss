; Xueqing Windows installer.
; The installer is per-user on purpose: the app can update its own files
; without requiring elevation after the first install. The existing updater
; still performs atomic backup/replace/rollback for in-app ZIP updates.

#ifndef AppVersion
#define AppVersion "0.1.0"
#endif
#ifndef BinaryVersion
#define BinaryVersion "0.1.0"
#endif

#ifndef OutputDir
#define OutputDir "..\..\build\windows\installer"
#endif
#ifndef ChineseMessagesFile
#define ChineseMessagesFile ".\languages\ChineseSimplified.isl"
#endif

#define AppName "学情"
#define AppPublisher "Xueqing"
#define AppExeName "xueqing.exe"
#define AppId "{{9B18D3F1-4E17-4C2E-9D71-2E8C0A1E5B4A}"
#ifndef BuildRoot
#define BuildRoot "..\..\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://github.com/qbjsdsb/xueqing
DefaultDirName={localappdata}\Programs\Xueqing
DisableDirPage=auto
DisableProgramGroupPage=yes
DisableReadyPage=yes
PrivilegesRequired=lowest
UsePreviousAppDir=yes
UsePreviousTasks=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=xueqing-setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
Uninstallable=yes
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#AppExeName}
CloseApplications=yes
CloseApplicationsFilter=xueqing.exe,xueqing_updater.exe,xueqing_updater_bootstrap.exe
RestartApplications=no
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Windows installer
VersionInfoProductName={#AppName}
VersionInfoVersion={#BinaryVersion}
VersionInfoProductVersion={#BinaryVersion}
VersionInfoProductTextVersion={#AppVersion}
VersionInfoCopyright=Copyright (C) 2026 Xueqing project

[Languages]
; build_installer.ps1 provides a pinned, integrity-checked translation path.
Name: "chinesesimplified"; MessagesFile: "{#ChineseMessagesFile}"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务："; Flags: checkedonce

[Files]
Source: "{#BuildRoot}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "THIRD_PARTY_NOTICES.txt"; DestDir: "{app}\licenses"; DestName: "windows-installer-translation.txt"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "启动 {#AppName}"; Flags: nowait postinstall skipifsilent
