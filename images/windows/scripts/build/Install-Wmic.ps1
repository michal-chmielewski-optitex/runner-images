################################################################################
##  File:  Install-Wmic.ps1
##  Desc:  Install WMIC FoD (removed by default on Win11 24H2+)
################################################################################

$capabilityName = 'WMIC~~~~'

$installed = dism /Online /Get-Capabilities /Format:Table | Out-String
if ($installed -match 'WMIC~~~~.*Installed') {
    Write-Host 'WMIC capability is already installed.'
}
else {
    Write-Host "Installing WMIC capability ($capabilityName)..."
    dism /Online /Add-Capability /CapabilityName:$capabilityName /NoRestart | Out-String | Write-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install WMIC capability. DISM exit code: $LASTEXITCODE"
    }
}

if (-not (Get-Command wmic.exe -ErrorAction SilentlyContinue)) {
    throw 'wmic.exe is not available after WMIC capability install.'
}

Invoke-PesterTests -TestFile 'Wmic'
