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

# The Windows test refreshes the token stored by the app. Client ids are
# compile-time, so they come from the same gitignored JSON.
$googleJson = Get-Content -Raw -Path $google | ConvertFrom-Json
$microsoftJson = Get-Content -Raw -Path $microsoft | ConvertFrom-Json
$liveArgs = @(
    'test',
    'integration_test/live_test.dart',
    '-d', 'windows',
    '--dart-define=CLOUD=live',
    "--dart-define=GOOGLE_CLIENT_ID=$($googleJson.client_id)",
    "--dart-define=MICROSOFT_CLIENT_ID=$($microsoftJson.client_id)"
)
if ($null -ne $googleJson.client_secret -and "$($googleJson.client_secret)" -ne '') {
    $liveArgs += "--dart-define=GOOGLE_DESKTOP_SECRET=$($googleJson.client_secret)"
}
flutter @liveArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Output 'OK'
exit 0
