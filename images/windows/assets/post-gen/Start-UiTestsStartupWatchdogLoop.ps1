################################################################################
##  File:  Start-UiTestsStartupWatchdogLoop.ps1 (post-generation)
##  Desc:  Start a single background watchdog loop per user session
################################################################################

if (-not (Test-Path 'C:\imagedata.json')) {
    return
}

$imageData = Get-Content 'C:\imagedata.json' -Raw
if ($imageData -notmatch 'windows-11-x64-ui-tests') {
    return
}

$loopScript = Join-Path $PSScriptRoot 'Disable-UiTestsStartupWatchdogLoop.ps1'
if (-not (Test-Path $loopScript)) {
    throw "Watchdog loop script not found: $loopScript"
}

$markerPath = Join-Path $env:TEMP 'UiTestsStartupWatchdogLoop.pid'
if (Test-Path $markerPath) {
    $existingPid = [int](Get-Content -Path $markerPath -ErrorAction SilentlyContinue)
    if ($existingPid -gt 0 -and (Get-Process -Id $existingPid -ErrorAction SilentlyContinue)) {
        return
    }
}

$process = Start-Process -FilePath 'powershell.exe' -PassThru -WindowStyle Hidden -ArgumentList @(
    '-NoProfile'
    '-WindowStyle'
    'Hidden'
    '-ExecutionPolicy'
    'Bypass'
    '-File'
    $loopScript
)

Set-Content -Path $markerPath -Value $process.Id -Force
