################################################################################
##  File:  Install-InstallShield.ps1
##  Desc:  Install InstallShield 2025 Standalone Build (SAB) on the agent image.
##
##  License (CLS / concurrent) and ISCmdBld builds are handled in the Azure
##  DevOps pipeline via the Revenera InstallShield Build extension:
##  https://community.revenera.com/s/article/installshield-azure-devops-build-extension
################################################################################

$ErrorActionPreference = 'Stop'

$installShield = (Get-ToolsetContent).installshield
$installerConfig = $installShield.installer
$installerPath = $null

if (-not [string]::IsNullOrWhiteSpace($env:INSTALLSHIELD_INSTALLER_PATH)) {
    $installerPath = $env:INSTALLSHIELD_INSTALLER_PATH
    Write-Host "Using local installer path from INSTALLSHIELD_INSTALLER_PATH."
}
elseif (-not [string]::IsNullOrWhiteSpace($env:INSTALLSHIELD_INSTALLER_URL)) {
    Write-Host "Downloading InstallShield SAB installer..."
    $fileName = $installerConfig.installerBlobName
    $installerPath = Invoke-DownloadWithRetry -Url $env:INSTALLSHIELD_INSTALLER_URL -Path (Join-Path $env:TEMP_DIR $fileName)
}
elseif (-not [string]::IsNullOrWhiteSpace($env:INSTALLSHIELD_ARTIFACTS_STORAGE_ACCOUNT)) {
    $storageAccount = $env:INSTALLSHIELD_ARTIFACTS_STORAGE_ACCOUNT
    $container = $installerConfig.blobContainer
    $blobName = $installerConfig.installerBlobName
    $installerPath = Join-Path $env:TEMP_DIR $blobName

    Write-Host "Downloading InstallShield SAB from '$storageAccount/$container/$blobName'..."
    az storage blob download `
        --account-name $storageAccount `
        --container-name $container `
        --name $blobName `
        --file $installerPath `
        --auth-mode login `
        --only-show-errors | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to download InstallShield installer from blob storage."
    }
}
else {
    throw @"
InstallShield installer source is not configured. Set one of:
  - INSTALLSHIELD_INSTALLER_PATH   (local path on build VM)
  - INSTALLSHIELD_INSTALLER_URL    (SAS URL to installer EXE)
  - INSTALLSHIELD_ARTIFACTS_STORAGE_ACCOUNT (blob: $($installerConfig.blobContainer)/$($installerConfig.installerBlobName))
"@
}

if (-not (Test-Path $installerPath)) {
    throw "InstallShield installer not found at '$installerPath'."
}

# SAB only — no license registration during image bake.
$installArgs = @(
    "/S",
    '/v"/qn VADDLOCAL=ALL"'
)

Write-Host "Installing InstallShield $($installShield.version) SAB..."
Install-Binary -LocalPath $installerPath -Type EXE -InstallArgs $installArgs

$systemPath = $installShield.systemPath
if (-not (Test-Path $systemPath)) {
    $discovered = Get-ChildItem -Path "${env:ProgramFiles(x86)}\InstallShield" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '2025.*SAB' } |
        Select-Object -First 1

    if ($discovered) {
        $systemPath = Join-Path $discovered.FullName "System"
    }
}

if (-not (Test-Path $systemPath)) {
    throw "InstallShield System directory not found at '$systemPath'."
}

Add-MachinePathItem $systemPath
Update-Environment

$isCmdBld = Join-Path $systemPath "ISCmdBld.exe"
if (-not (Test-Path $isCmdBld)) {
    throw "ISCmdBld.exe not found at '$isCmdBld'."
}

Write-Host "InstallShield SAB installed. ISCmdBld.exe: $isCmdBld"

Invoke-PesterTests -TestFile "InstallShield"
