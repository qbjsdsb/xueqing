; Xueqing Windows installer.
; The installer is per-user on purpose: the app can update its own files
; without requiring elevation after the first install. The existing updater
; still performs atomic backup/replace/rollback for in-app ZIP updates.

#ifndef AppVersion
#define AppVersion "0.1.0"
#endif

#ifndef OutputDir
#define OutputDir "..\..\build\windows\installer"
#endif

#define AppName "Xueqing"
#define AppPublisher "Xueqing project"
#define AppExeName "xueqing.exe"
#define AppId "{9B18D3F1-4E17-4C2E-9D71-2E8C0A1E5B4A}"
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
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=xueqing-setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
Uninstallable=yes
UninstallDisplayIcon={app}\{#AppExeName}
CloseApplications=yes
RestartApplications=no
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Windows installer
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}
VersionInfoCopyright=Copyright (C) 2026 Xueqing project

[Files]
Source: "{#BuildRoot}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"

[Run]
Filename: "{app}\{#AppExeName}"; Description: "启动 {#AppName}"; Flags: nowait postinstall skipifsilent
