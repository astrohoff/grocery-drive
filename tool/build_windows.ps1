$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$google = Join-Path $root 'secrets\google.json'
$microsoft = Join-Path $root 'secrets\microsoft.json'
if (-not (Test-Path $google) -or -not (Test-Path $microsoft)) {
    Write-Output 'Create secrets/google.json and secrets/microsoft.json first. See docs/oauth_setup.md.'
    exit 1
}

$googleJson = Get-Content -Raw -Path $google | ConvertFrom-Json
$microsoftJson = Get-Content -Raw -Path $microsoft | ConvertFrom-Json
if ("$($googleJson.client_id)" -eq '' -or "$($microsoftJson.client_id)" -eq '') {
    Write-Output 'A secrets file is missing client_id. See docs/oauth_setup.md.'
    exit 1
}

# Client ids are compile-time. The release exe keeps them, so a later launch
# does not take --dart-define. The script does not print the values.
$buildArgs = @(
    'build',
    'windows',
    "--dart-define=GOOGLE_CLIENT_ID=$($googleJson.client_id)",
    "--dart-define=MICROSOFT_CLIENT_ID=$($microsoftJson.client_id)"
)
if ($null -ne $googleJson.client_secret -and "$($googleJson.client_secret)" -ne '') {
    $buildArgs += "--dart-define=GOOGLE_DESKTOP_SECRET=$($googleJson.client_secret)"
}

flutter @buildArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Output 'build\windows\x64\runner\Release\grocery_drive.exe'
exit 0
