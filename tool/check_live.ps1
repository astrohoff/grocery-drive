$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$google = Join-Path $root 'secrets\google.json'
$microsoft = Join-Path $root 'secrets\microsoft.json'
if (-not (Test-Path $google) -or -not (Test-Path $microsoft)) {
    Write-Output 'NEEDS_HUMAN_CREDENTIALS'
    exit 2
}

dart run tool/live/google_roundtrip.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

dart run tool/live/onedrive_roundtrip.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter test integration_test/live_test.dart -d windows --dart-define=CLOUD=live
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Output 'OK'
exit 0
