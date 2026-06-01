param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $FlutterArgs
)

$ErrorActionPreference = 'Stop'

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$toolRoot = Split-Path $projectRoot -Parent
$driveRoot = [IO.Path]::GetPathRoot($projectRoot)

function Select-ExistingPath {
  param(
    [string[]] $Candidates,
    [string] $RequiredChild
  )

  foreach ($candidate in $Candidates) {
    if ([string]::IsNullOrWhiteSpace($candidate)) {
      continue
    }

    $requiredPath = if ([string]::IsNullOrWhiteSpace($RequiredChild)) {
      $candidate
    } else {
      Join-Path $candidate $RequiredChild
    }

    if (Test-Path $requiredPath) {
      return $candidate
    }
  }

  return $Candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
}

$flutterRoot = $env:FLUTTER_ROOT
if ([string]::IsNullOrWhiteSpace($flutterRoot)) {
  $flutterRoot = Select-ExistingPath @(
    (Join-Path $toolRoot 'flutter-sdk'),
    (Join-Path $driveRoot 'flutter-sdk'),
    'D:\flutter-sdk'
  ) 'bin\flutter.bat'
}

$flutter = Join-Path $flutterRoot 'bin\flutter.bat'
if (-not (Test-Path $flutter)) {
  throw "Flutter SDK not found: $flutter"
}

$env:PUB_CACHE = Join-Path $toolRoot 'PubCache'
$env:GRADLE_USER_HOME = Join-Path $toolRoot 'GradleCache'
$env:JAVA_HOME = 'C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot'
$env:ANDROID_HOME = Select-ExistingPath @(
  (Join-Path $toolRoot 'AndroidSdk'),
  (Join-Path $driveRoot 'AndroidSdk'),
  'D:\AndroidSdk'
) 'platform-tools'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME

$tempRoot = Join-Path $toolRoot 'Temp'
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
$env:TEMP = $tempRoot
$env:TMP = $tempRoot
$javaTempOption = "-Djava.io.tmpdir=`"$tempRoot`""
if ([string]::IsNullOrWhiteSpace($env:JAVA_TOOL_OPTIONS)) {
  $env:JAVA_TOOL_OPTIONS = $javaTempOption
} elseif ($env:JAVA_TOOL_OPTIONS -notmatch 'java\.io\.tmpdir') {
  $env:JAVA_TOOL_OPTIONS = "$javaTempOption $env:JAVA_TOOL_OPTIONS"
}
$env:Path = @(
  (Join-Path $flutterRoot 'bin')
  (Join-Path $env:ANDROID_HOME 'platform-tools')
  (Join-Path $env:ANDROID_HOME 'cmdline-tools\latest\bin')
  (Join-Path $env:JAVA_HOME 'bin')
  $env:Path
) -join [IO.Path]::PathSeparator

& $flutter @FlutterArgs
exit $LASTEXITCODE
