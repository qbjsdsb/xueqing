param(
  [Parameter(Mandatory = $true)]
  [string]$AppVersion,
  [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "../.."))
)

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $RepositoryRoot "installer/windows/xueqing.iss"
$buildRoot = Join-Path $RepositoryRoot "build/windows/x64/runner/Release"
$outputDirectory = Join-Path $RepositoryRoot "build/windows/installer"
$expectedInstaller = Join-Path $outputDirectory "xueqing-setup-$AppVersion.exe"

if (-not (Test-Path $scriptPath)) {
  throw "Inno Setup script was not found: $scriptPath"
}
if (-not (Test-Path (Join-Path $buildRoot "xueqing.exe"))) {
  throw "Windows release bundle was not found: $buildRoot"
}

$isccCommand = Get-Command iscc.exe -ErrorAction SilentlyContinue
if ($null -eq $isccCommand) {
  $knownPath = Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6/ISCC.exe"
  if (Test-Path $knownPath) {
    $isccPath = $knownPath
  } else {
    if ($null -eq (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
      throw "Inno Setup compiler and Chocolatey are both unavailable."
    }
    choco install innosetup --no-progress --yes
    $installedPath = Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6/ISCC.exe"
    if (-not (Test-Path $installedPath)) {
      throw "Inno Setup compiler was not installed."
    }
    $isccPath = $installedPath
  }
} else {
  $isccPath = $isccCommand.Source
}

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
& $isccPath "/Qp" "/DAppVersion=$AppVersion" "/DBuildRoot=$buildRoot" "/DOutputDir=$outputDirectory" $scriptPath
if ($LASTEXITCODE -ne 0) {
  throw "Inno Setup compilation failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path $expectedInstaller)) {
  throw "Expected installer was not produced: $expectedInstaller"
}
if ((Get-Item $expectedInstaller).Length -le 0) {
  throw "Produced installer is empty: $expectedInstaller"
}

Write-Host "Windows installer: $expectedInstaller"
