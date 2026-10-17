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
    # Two processes share one directory. The second launch must show milk
    # without adding it. The Windows runner does not pass environment variables
    # into the app, so the directory is a dart-define.
    $cold = Join-Path $env:TEMP 'grocery_drive_cold'
    if (Test-Path $cold) {
        Remove-Item -Recurse -Force $cold
    }
    New-Item -ItemType Directory -Path $cold | Out-Null
    $coldDefine = $cold.Replace('\', '/')
    $coldTest = @(
        'test',
        'integration_test/cold_start_test.dart',
        '-d', 'windows',
        '--dart-define=CLOUD=fake',
        "--dart-define=GROCERY_CACHE_DIR=$coldDefine"
    )
    flutter @coldTest
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (-not (Test-Path (Join-Path $cold 'phase.txt'))) {
        Write-Output 'cold start: first process did not save milk'
        exit 1
    }
    flutter @coldTest
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Output 'OK'
exit 0
