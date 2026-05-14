param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $FlutterArgs
)

$ErrorActionPreference = 'Stop'

$flutterRoot = $env:FLUTTER_ROOT
if ([string]::IsNullOrWhiteSpace($flutterRoot)) {
  $flutterRoot = 'D:\flutter-sdk'
}

$flutter = Join-Path $flutterRoot 'bin\flutter.bat'
if (-not (Test-Path $flutter)) {
  throw "Flutter SDK not found: $flutter"
}

$env:PUB_CACHE = 'D:\PubCache'
$env:GRADLE_USER_HOME = 'D:\GradleCache'
$env:JAVA_HOME = 'C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot'
$env:ANDROID_HOME = 'D:\AndroidSdk'
$env:ANDROID_SDK_ROOT = 'D:\AndroidSdk'

$tempRoot = 'D:\Temp'
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
$env:TEMP = $tempRoot
$env:TMP = $tempRoot
if ([string]::IsNullOrWhiteSpace($env:JAVA_TOOL_OPTIONS)) {
  $env:JAVA_TOOL_OPTIONS = "-Djava.io.tmpdir=$tempRoot"
} elseif ($env:JAVA_TOOL_OPTIONS -notmatch 'java\.io\.tmpdir') {
  $env:JAVA_TOOL_OPTIONS = "-Djava.io.tmpdir=$tempRoot $env:JAVA_TOOL_OPTIONS"
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
