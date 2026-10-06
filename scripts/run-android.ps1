param(
    [string]$DeviceId,
    [string]$EmulatorId = 'Pixel_10_Pro_XL'
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter is not on PATH. Install Flutter and reopen the terminal.'
}
if (-not (Test-Path -LiteralPath 'config/development.json')) {
    Copy-Item -LiteralPath 'config/development.example.json' -Destination 'config/development.json'
}
$config = Get-Content -LiteralPath 'config/development.json' -Raw | ConvertFrom-Json
if (-not $config.APPS_SCRIPT_URL -or -not $config.GOOGLE_SERVER_CLIENT_ID) {
    Write-Host 'Starting in setup mode. Real login needs APPS_SCRIPT_URL and GOOGLE_SERVER_CLIENT_ID in config/development.json.' -ForegroundColor Yellow
}
function Get-AndroidDevices {
    $raw = & flutter devices --machine
    if ($LASTEXITCODE -ne 0) { throw 'Cannot list Flutter devices.' }
    @((($raw -join "`n") | ConvertFrom-Json) | Where-Object { $_.targetPlatform -like 'android*' })
}
if (-not $DeviceId) {
    $devices = @(Get-AndroidDevices)
    if ($devices.Count -eq 0) {
        & flutter emulators --launch $EmulatorId
        if ($LASTEXITCODE -ne 0) { throw "Cannot start emulator $EmulatorId. Run flutter emulators to list available emulators." }
        $deadline = (Get-Date).AddMinutes(2)
        do {
            Start-Sleep -Seconds 3
            $devices = @(Get-AndroidDevices)
        } while ($devices.Count -eq 0 -and (Get-Date) -lt $deadline)
    }
    if ($devices.Count -eq 0) { throw 'No Android device became available. Start an emulator or connect a phone with USB debugging.' }
    $DeviceId = $devices[0].id
}
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }
& flutter run -d $DeviceId --dart-define-from-file=config/development.json
exit $LASTEXITCODE
