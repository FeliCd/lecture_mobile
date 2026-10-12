param(
    [string]$DeviceId,
    [string]$EmulatorId,
    [string]$Config = 'config/lab2.free.json'
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter is not on PATH. Install Flutter and reopen the terminal.'
}
if (-not (Test-Path -LiteralPath $Config)) { throw "Missing configuration: $Config" }
function Get-AndroidDevices {
    $raw = & flutter devices --machine
    if ($LASTEXITCODE -ne 0) { throw 'Cannot list Flutter devices.' }
    @((($raw -join "`n") | ConvertFrom-Json) | Where-Object { $_.targetPlatform -like 'android*' })
}
if (-not $DeviceId) {
    $devices = @(Get-AndroidDevices)
    if ($devices.Count -eq 0) {
        if (-not $EmulatorId) { throw 'Connect an Android phone or supply -EmulatorId from flutter emulators. This machine currently has no configured AVD.' }
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
$taskConfig = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
$taskExtraArgs = @()
if ($taskConfig.USE_EMULATORS -eq 'true') {
    $taskDevice = @(Get-AndroidDevices) | Where-Object { $_.id -eq $DeviceId } | Select-Object -First 1
    if (-not $taskDevice) { throw "Android device not found: $DeviceId" }
    if (-not $taskDevice.emulator) {
        $taskAdbCommand = Get-Command adb -ErrorAction SilentlyContinue
        $taskAdb = if ($taskAdbCommand) { $taskAdbCommand.Source } else { Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe' }
        if (-not (Test-Path -LiteralPath $taskAdb)) { throw 'adb not found. Add Android SDK platform-tools to PATH.' }
        foreach ($taskPort in @(9099,8080,5001)) {
            & $taskAdb -s $DeviceId reverse "tcp:$taskPort" "tcp:$taskPort"
            if ($LASTEXITCODE -ne 0) { throw "Cannot forward emulator port $taskPort to device $DeviceId" }
        }
        $taskExtraArgs = @('--dart-define=EMULATOR_HOST=127.0.0.1')
    }
}
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }
& flutter run -d $DeviceId --dart-define-from-file=$Config @taskExtraArgs
exit $LASTEXITCODE
