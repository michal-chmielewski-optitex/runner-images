################################################################################
##  File:  Install-Wmic.ps1
##  Desc:  Install WMIC FoD (removed by default on Win11 24H2+)
################################################################################

$wmicExe = Join-Path $env:Windir 'System32\wbem\WMIC.exe'
$wbemDir = Split-Path $wmicExe -Parent

function Test-WmicInstalled {
    return Test-Path $wmicExe
}

if (Test-WmicInstalled) {
    Write-Host "WMIC is already available at $wmicExe"
}
else {
    $capabilities = @(Get-WindowsCapability -Online | Where-Object { $_.Name -like 'WMIC*' })
    if ($capabilities.Count -eq 0) {
        throw 'WMIC capability was not found in the online FoD catalog for this Windows build.'
    }

    foreach ($capability in $capabilities) {
        Write-Host "Found capability: $($capability.Name) (State: $($capability.State))"
    }

    $target = $capabilities | Where-Object { $_.State -ne 'Installed' } | Select-Object -First 1
    if (-not $target) {
        throw "WMIC capabilities are marked installed but $wmicExe is missing."
    }

    Write-Host "Installing WMIC capability via DISM: $($target.Name)"
    $dismOutput = & dism.exe /Online /Add-Capability /CapabilityName:$($target.Name) /NoRestart 2>&1 | Out-String
    Write-Host $dismOutput
    if ($LASTEXITCODE -ne 0) {
        throw "DISM failed to install WMIC capability '$($target.Name)'. Exit code: $LASTEXITCODE"
    }
}

if (-not (Test-WmicInstalled)) {
    throw "wmic.exe not found at $wmicExe after WMIC capability install."
}

if ($env:Path -notlike "*$wbemDir*") {
    Add-MachinePathItem $wbemDir
}

Update-Environment

Invoke-PesterTests -TestFile 'Wmic'
