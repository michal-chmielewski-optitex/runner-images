################################################################################
##  File:  Install-Wmic.ps1
##  Desc:  Install WMIC FoD (removed by default on Win11 24H2+)
################################################################################

$wmicExe = Join-Path $env:Windir 'System32\wbem\WMIC.exe'
$wbemDir = Split-Path $wmicExe -Parent

function Test-WmicInstalled {
    return Test-Path $wmicExe
}

function Get-WmicCapabilities {
    return @(Get-WindowsCapability -Online | Where-Object { $_.Name -like 'WMIC*' })
}

function Install-WmicCapability {
    param(
        [Parameter(Mandatory = $true)]
        [string] $CapabilityName
    )

    Write-Host "Installing WMIC capability via DISM: $CapabilityName"
    $dismOutput = & dism.exe /Online /Add-Capability /CapabilityName:$CapabilityName /NoRestart 2>&1 | Out-String
    Write-Host $dismOutput
    if ($LASTEXITCODE -ne 0) {
        throw "DISM failed to install WMIC capability '$CapabilityName'. Exit code: $LASTEXITCODE"
    }
}

function Remove-WmicCapability {
    param(
        [Parameter(Mandatory = $true)]
        [string] $CapabilityName
    )

    Write-Host "Removing WMIC capability via DISM: $CapabilityName"
    $dismOutput = & dism.exe /Online /Remove-Capability /CapabilityName:$CapabilityName /NoRestart 2>&1 | Out-String
    Write-Host $dismOutput
    if ($LASTEXITCODE -ne 0) {
        throw "DISM failed to remove WMIC capability '$CapabilityName'. Exit code: $LASTEXITCODE"
    }
}

if (Test-WmicInstalled) {
    Write-Host "WMIC is already available at $wmicExe"
}
else {
    $capabilities = Get-WmicCapabilities
    if ($capabilities.Count -eq 0) {
        throw 'WMIC capability was not found in the online FoD catalog for this Windows build.'
    }

    foreach ($capability in $capabilities) {
        Write-Host "Found capability: $($capability.Name) (State: $($capability.State))"
    }

    $pendingInstall = $capabilities | Where-Object { $_.State -ne 'Installed' } | Select-Object -First 1
    if (-not $pendingInstall) {
        Write-Host 'WMIC capability is marked installed but wmic.exe is missing; reinstalling FoD.'
        foreach ($installedCapability in ($capabilities | Where-Object { $_.State -eq 'Installed' })) {
            Remove-WmicCapability -CapabilityName $installedCapability.Name
        }

        $capabilities = Get-WmicCapabilities
        $pendingInstall = $capabilities | Where-Object { $_.State -ne 'Installed' } | Select-Object -First 1
        if (-not $pendingInstall) {
            $pendingInstall = $capabilities | Select-Object -First 1
        }
    }

    Install-WmicCapability -CapabilityName $pendingInstall.Name
}

if (-not (Test-WmicInstalled)) {
    throw "wmic.exe not found at $wmicExe after WMIC capability install."
}

if ($env:Path -notlike "*$wbemDir*") {
    Add-MachinePathItem $wbemDir
}

Update-Environment

Invoke-PesterTests -TestFile 'Wmic'
