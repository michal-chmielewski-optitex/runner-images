################################################################################
##  File:  Install-Wmic.ps1
##  Desc:  Install WMIC FoD (removed by default on Win11 24H2+)
################################################################################

$capabilityName = 'WMIC~~~~'

$state = Get-WindowsCapability -Online -Name $capabilityName -ErrorAction SilentlyContinue
if ($state -and $state.State -eq 'Installed') {
    Write-Host 'WMIC capability is already installed.'
}
else {
    Write-Host "Installing WMIC capability ($capabilityName)..."
    $result = Add-WindowsCapability -Online -Name $capabilityName -NoRestart
    if ($result.RestartNeeded) {
        Write-Host 'WMIC capability installed; restart may be required before wmic.exe is available.'
    }
    if ($result.State -ne 'Installed') {
        throw "Failed to install WMIC capability. State: $($result.State)"
    }
}

Update-Environment

if (-not (Get-Command wmic.exe -ErrorAction SilentlyContinue)) {
    throw 'wmic.exe is not available after WMIC capability install.'
}

Invoke-PesterTests -TestFile 'Wmic'
