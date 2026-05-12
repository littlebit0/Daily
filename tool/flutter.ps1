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

& $flutter @FlutterArgs
exit $LASTEXITCODE
