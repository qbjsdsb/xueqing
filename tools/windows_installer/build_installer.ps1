param(
  [Parameter(Mandatory = $true)]
  [string]$AppVersion,
  [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "../.."))
)

$ErrorActionPreference = "Stop"

if ($AppVersion -notmatch '^(?<BinaryVersion>\d+\.\d+\.\d+)(?:-[0-9A-Za-z.-]+)?$') {
  throw "Installer AppVersion must match major.minor.patch[-prerelease]."
}
$binaryVersion = $Matches['BinaryVersion']

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

function Find-InnoSetupCompiler {
  $command = Get-Command iscc.exe -ErrorAction SilentlyContinue
  if ($null -ne $command) {
    return $command.Source
  }

  $candidatePaths = @(
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6/ISCC.exe"),
    (Join-Path $env:ProgramFiles "Inno Setup 6/ISCC.exe"),
    (Join-Path $env:ProgramFiles "Inno Setup 7/ISCC.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 7/ISCC.exe")
  )
  foreach ($candidatePath in $candidatePaths) {
    if (Test-Path $candidatePath) {
      return $candidatePath
    }
  }
  return $null
}

$isccPath = Find-InnoSetupCompiler
if ($null -eq $isccPath) {
  if ($null -eq (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
    throw "Inno Setup compiler and Chocolatey are both unavailable."
  }
  choco install innosetup --no-progress --yes
  if ($LASTEXITCODE -ne 0) {
    throw "Chocolatey failed to install Inno Setup with exit code $LASTEXITCODE."
  }
  $isccPath = Find-InnoSetupCompiler
  if ($null -eq $isccPath) {
    throw "Inno Setup compiler was not found after installation."
  }
}

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
& $isccPath "/Qp" "/DAppVersion=$AppVersion" "/DBinaryVersion=$binaryVersion" "/DBuildRoot=$buildRoot" "/DOutputDir=$outputDirectory" $scriptPath
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
Write-Host "Installer display version: $AppVersion; binary version: $binaryVersion"
