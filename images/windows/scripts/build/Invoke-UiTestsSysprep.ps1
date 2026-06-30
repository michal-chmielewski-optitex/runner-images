################################################################################
##  File:  Invoke-UiTestsSysprep.ps1
##  Desc:  Generalize UI test image with timeout and sysprep log on failure
################################################################################

function Get-SysprepLogTail {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [int] $Lines = 40
    )

    if (-not (Test-Path $Path)) {
        return "$Path not found"
    }

    return (Get-Content $Path -Tail $Lines -ErrorAction SilentlyContinue) -join [Environment]::NewLine
}

$unattendPath = Join-Path $env:SystemRoot 'System32\Sysprep\unattend.xml'
if (Test-Path $unattendPath) {
    Remove-Item $unattendPath -Force
}

Write-Host 'Starting sysprep /generalize...'
$sysprepExe = Join-Path $env:SystemRoot 'System32\Sysprep\Sysprep.exe'
$p = Start-Process -FilePath $sysprepExe -ArgumentList @('/oobe', '/generalize', '/mode:vm', '/quiet', '/quit') -PassThru -Wait -NoNewWindow
if ($p.ExitCode -ne 0) {
    throw "Sysprep.exe exited with code $($p.ExitCode)"
}

$timeoutMinutes = 45
$deadline = (Get-Date).AddMinutes($timeoutMinutes)
while ((Get-Date) -lt $deadline) {
    $imageState = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State').ImageState
    if ($imageState -eq 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') {
        Write-Host "Sysprep completed: $imageState"
        return
    }

    Write-Host "Waiting for sysprep: $imageState"
    Start-Sleep -Seconds 10
}

$pantherDir = Join-Path $env:SystemRoot 'System32\Sysprep\Panther'
$setupErr = Join-Path $pantherDir 'setuperr.log'
$setupAct = Join-Path $pantherDir 'setupact.log'
$lastState = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State').ImageState

throw @"
Sysprep did not reach IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE within ${timeoutMinutes} minutes.
Last ImageState: $lastState

--- setuperr.log (tail) ---
$(Get-SysprepLogTail -Path $setupErr)

--- setupact.log (tail) ---
$(Get-SysprepLogTail -Path $setupAct)
"@
