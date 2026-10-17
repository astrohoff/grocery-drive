$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

dart run tool/deslop.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$tests = @(Get-ChildItem -Path (Join-Path $root 'test') -Recurse -Filter *_test.dart -ErrorAction SilentlyContinue)
if ($tests.Count -eq 0) {
    Write-Output 'flutter test: no test files yet'
} else {
    flutter test
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if (Test-Path (Join-Path $root 'integration_test')) {
    flutter test integration_test -d windows --dart-define=CLOUD=fake
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Output 'OK'
exit 0
