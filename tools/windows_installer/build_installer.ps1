param(
  [Parameter(Mandatory = $true)]
  [string]$AppVersion,
  [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")),
  [switch]$SkipSmoke
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

function Get-GitBlobSha1 {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  [byte[]]$content = [System.IO.File]::ReadAllBytes($Path)
  [byte[]]$header = [System.Text.Encoding]::UTF8.GetBytes("blob $($content.Length)`0")
  [byte[]]$payload = New-Object byte[] ($header.Length + $content.Length)
  [Array]::Copy($header, 0, $payload, 0, $header.Length)
  [Array]::Copy($content, 0, $payload, $header.Length, $content.Length)

  $sha1 = [System.Security.Cryptography.SHA1]::Create()
  try {
    $hash = $sha1.ComputeHash($payload)
  }
  finally {
    $sha1.Dispose()
  }
  return (($hash | ForEach-Object { $_.ToString("x2") }) -join "")
}

function Resolve-ChineseMessagesFile {
  $translationCommit = "1ff90acc4ed4aee82b1cda43253243deee3daed4"
  $translationBlobSha = "30d997321197c7c96d8e111e9ddd6c0ca8da5f09"
  $translationDirectory = Join-Path $RepositoryRoot "build/windows/installer-support"
  $translationPath = Join-Path $translationDirectory "ChineseSimplified.isl"
  $translationUrl = "https://raw.githubusercontent.com/kira-96/Inno-Setup-Chinese-Simplified-Translation/$translationCommit/ChineseSimplified.isl"

  New-Item -ItemType Directory -Force -Path $translationDirectory | Out-Null

  if (Test-Path $translationPath) {
    $existingBlobSha = Get-GitBlobSha1 -Path $translationPath
    if ($existingBlobSha -eq $translationBlobSha) {
      return $translationPath
    }
    Remove-Item -Force $translationPath
  }

  $temporaryPath = "$translationPath.download"
  try {
    Invoke-WebRequest `
      -Uri $translationUrl `
      -OutFile $temporaryPath `
      -UseBasicParsing

    $downloadedBlobSha = Get-GitBlobSha1 -Path $temporaryPath
    if ($downloadedBlobSha -ne $translationBlobSha) {
      throw "Chinese installer translation integrity check failed: expected Git blob $translationBlobSha, got $downloadedBlobSha."
    }

    Move-Item -Force $temporaryPath $translationPath
  }
  finally {
    if (Test-Path $temporaryPath) {
      Remove-Item -Force $temporaryPath -ErrorAction SilentlyContinue
    }
  }

  return $translationPath
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

$chineseMessagesFile = Resolve-ChineseMessagesFile

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
& $isccPath "/Qp" "/DAppVersion=$AppVersion" "/DBinaryVersion=$binaryVersion" "/DBuildRoot=$buildRoot" "/DOutputDir=$outputDirectory" "/DChineseMessagesFile=$chineseMessagesFile" $scriptPath
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

# All existing GitHub Actions installer builds flow through this helper. Running
# the upgrade smoke here means PR smoke, manual Windows packaging, and the
# stable publisher all verify the same fresh-install -> upgrade -> uninstall
# contract without duplicating workflow logic.
if (-not $SkipSmoke -and $env:CI -eq "true") {
  $smokeScript = Join-Path $PSScriptRoot "smoke_installer.ps1"
  if (-not (Test-Path $smokeScript)) {
    throw "Windows installer smoke script was not found: $smokeScript"
  }
  & $smokeScript -AppVersion $AppVersion -RepositoryRoot $RepositoryRoot
  if ($LASTEXITCODE -ne 0) {
    throw "Windows installer upgrade smoke failed with exit code $LASTEXITCODE."
  }
}
