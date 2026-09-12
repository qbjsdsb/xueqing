param(
  [Parameter(Mandatory = $true)]
  [string]$AppVersion,
  [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "../.."))
)

$ErrorActionPreference = "Stop"

$buildScript = Join-Path $PSScriptRoot "build_installer.ps1"
$outputDirectory = Join-Path $RepositoryRoot "build/windows/installer"
$currentInstaller = Join-Path $outputDirectory "xueqing-setup-$AppVersion.exe"
$priorVersion = "0.0.1-preupgrade"
$priorInstaller = Join-Path $outputDirectory "xueqing-setup-$priorVersion.exe"
$installDir = Join-Path $env:LOCALAPPDATA "Programs/Xueqing"
$desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "学情.lnk"
$startMenuShortcut = Join-Path $env:APPDATA "Microsoft/Windows/Start Menu/Programs/学情.lnk"
$probePath = Join-Path $installDir "upgrade-preserve-probe.txt"

function Invoke-Setup {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Installer,
    [string[]]$ExtraArguments = @()
  )

  if (-not (Test-Path $Installer)) {
    throw "Installer was not found: $Installer"
  }

  $arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-') + $ExtraArguments
  $process = Start-Process `
    -FilePath $Installer `
    -ArgumentList $arguments `
    -Wait `
    -PassThru
  if ($process.ExitCode -ne 0) {
    throw "Installer exited with code $($process.ExitCode): $Installer"
  }
}

function Get-XueqingUninstallEntries {
  $root = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
  if (-not (Test-Path $root)) {
    return @()
  }
  return @(
    Get-ChildItem $root |
      ForEach-Object { Get-ItemProperty $_.PSPath } |
      Where-Object {
        $_.DisplayName -eq "学情" -and
        -not [string]::IsNullOrWhiteSpace($_.InstallLocation) -and
        $_.InstallLocation.TrimEnd('\') -eq $installDir.TrimEnd('\')
      }
  )
}

function Assert-InstalledFiles {
  foreach ($requiredFile in @(
    "xueqing.exe",
    "xueqing_updater.exe",
    "xueqing_updater_bootstrap.exe",
    "msvcp140.dll",
    "vcruntime140.dll",
    "vcruntime140_1.dll"
  )) {
    $installedPath = Join-Path $installDir $requiredFile
    if (-not (Test-Path $installedPath)) {
      throw "Installer did not install required file: $installedPath"
    }
    if ((Get-Item $installedPath).Length -le 0) {
      throw "Installer produced an empty required file: $installedPath"
    }
  }
}

function Remove-ExistingInstall {
  $uninstaller = Join-Path $installDir "unins000.exe"
  if (Test-Path $uninstaller) {
    $process = Start-Process `
      -FilePath $uninstaller `
      -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') `
      -Wait `
      -PassThru
    if ($process.ExitCode -ne 0) {
      throw "Existing Xueqing uninstall failed with code $($process.ExitCode)."
    }
  }
  if (Test-Path $installDir) {
    Remove-Item -Recurse -Force $installDir
  }
  foreach ($shortcut in @($desktopShortcut, $startMenuShortcut)) {
    if (Test-Path $shortcut) {
      Remove-Item -Force $shortcut
    }
  }
}

if (-not (Test-Path $currentInstaller)) {
  throw "Current installer was not found: $currentInstaller"
}

try {
  Remove-ExistingInstall

  & $buildScript `
    -AppVersion $priorVersion `
    -RepositoryRoot $RepositoryRoot `
    -SkipSmoke
  if ($LASTEXITCODE -ne 0) {
    throw "Prior-version installer fixture failed to build."
  }

  # A teacher may opt out of a desktop shortcut. The upgrade must remember
  # that choice instead of recreating the icon every time.
  Invoke-Setup `
    -Installer $priorInstaller `
    -ExtraArguments @('/MERGETASKS=!desktopicon')
  Assert-InstalledFiles

  if (-not (Test-Path $startMenuShortcut)) {
    throw "Fresh install did not create the Start Menu shortcut."
  }
  if (Test-Path $desktopShortcut) {
    throw "Fresh install ignored the explicit desktop-shortcut opt-out."
  }

  Set-Content -Path $probePath -Value "preserve-on-upgrade" -Encoding utf8

  # Upgrade in place with no task override. Inno Setup should reuse the prior
  # installation directory and the previous task selection for the same AppId.
  Invoke-Setup -Installer $currentInstaller
  Assert-InstalledFiles

  if (-not (Test-Path $probePath)) {
    throw "Upgrade did not preserve an existing installation-directory probe."
  }
  if (Test-Path $desktopShortcut) {
    throw "Upgrade recreated a desktop shortcut the user had opted out of."
  }
  if (-not (Test-Path $startMenuShortcut)) {
    throw "Upgrade lost the Start Menu shortcut."
  }

  $entries = @(Get-XueqingUninstallEntries)
  if ($entries.Count -ne 1) {
    throw "Expected one Xueqing uninstall entry after upgrade; found $($entries.Count)."
  }
  if ($entries[0].DisplayVersion -ne $AppVersion) {
    throw "Upgrade registry version mismatch: expected $AppVersion, got $($entries[0].DisplayVersion)."
  }

  Remove-Item -Force $probePath
  $uninstaller = Join-Path $installDir "unins000.exe"
  if (-not (Test-Path $uninstaller)) {
    throw "Windows uninstaller was not installed."
  }
  $uninstallProcess = Start-Process `
    -FilePath $uninstaller `
    -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') `
    -Wait `
    -PassThru
  if ($uninstallProcess.ExitCode -ne 0) {
    throw "Windows uninstaller smoke failed with exit code $($uninstallProcess.ExitCode)."
  }

  foreach ($removedFile in @(
    "xueqing.exe",
    "xueqing_updater.exe",
    "xueqing_updater_bootstrap.exe"
  )) {
    if (Test-Path (Join-Path $installDir $removedFile)) {
      throw "Windows uninstaller left application file behind: $removedFile"
    }
  }
  if (@(Get-XueqingUninstallEntries).Count -ne 0) {
    throw "Windows uninstaller left the Xueqing uninstall registry entry behind."
  }

  Write-Host "Windows installer fresh-install, task persistence, in-place upgrade, and uninstall smoke passed."
}
finally {
  if (Test-Path $probePath) {
    Remove-Item -Force $probePath -ErrorAction SilentlyContinue
  }
  if (Test-Path $priorInstaller) {
    Remove-Item -Force $priorInstaller -ErrorAction SilentlyContinue
  }
  if (Test-Path $installDir) {
    Remove-Item -Recurse -Force $installDir -ErrorAction SilentlyContinue
  }
  foreach ($shortcut in @($desktopShortcut, $startMenuShortcut)) {
    if (Test-Path $shortcut) {
      Remove-Item -Force $shortcut -ErrorAction SilentlyContinue
    }
  }
}
