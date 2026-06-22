<#
.SYNOPSIS
    Build Windows 2022 + InstallShield SAB and publish to ACG acg_ned_prd_mdp_001 (NED PRD).

.DESCRIPTION
    Wrapper around GenerateResourcesAndImage with NED PRD defaults.
    Requires: Packer 1.8+, Git, Azure CLI, az login to subcr-ned-prd-001.

    InstallShield SAB installer — set ONE of:
      - INSTALLSHIELD_INSTALLER_URL          (SAS URL to .exe)
      - INSTALLSHIELD_INSTALLER_PATH         (local path)
      - INSTALLSHIELD_ARTIFACTS_STORAGE_ACCOUNT (blob installshield-artifacts/InstallShield2025StandaloneBuild.exe)

.EXAMPLE
    $env:INSTALLSHIELD_INSTALLER_URL = "https://....sas...."
    .\Build-InstallShieldImage-NedPrd.ps1 -ImageVersion "1.0.0"

.EXAMPLE
    # On Azure VM with user-assigned MI id-aib-win11-installer-gui-001 attached:
    .\Build-InstallShieldImage-NedPrd.ps1 -ImageVersion "1.0.0" -UseManagedIdentity

.EXAMPLE
    .\Build-InstallShieldImage-NedPrd.ps1 -ImageVersion "1.0.0" -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string] $ImageVersion = '1.0.0',

    [Parameter(Mandatory = $false)]
    [string] $SubscriptionId = '426ea593-fd6e-40a0-a314-be2b3d6a2a06',

    [Parameter(Mandatory = $false)]
    [string] $ResourceGroupName = 'rg-ned-prd-mdp-001',

    [Parameter(Mandatory = $false)]
    [string] $AzureLocation = 'germanywestcentral',

    [Parameter(Mandatory = $false)]
    [string] $GalleryName = 'acg_ned_prd_mdp_001',

    [Parameter(Mandatory = $false)]
    [string] $GalleryResourceGroupName = 'rg-ned-prd-mdp-001',

    [Parameter(Mandatory = $false)]
    [string] $GalleryImageName = 'installshield-2025-win2022',

    [Parameter(Mandatory = $false)]
    [switch] $RestrictToAgentIpAddress,

    [Parameter(Mandatory = $false)]
    [string] $AzureClientId,

    [Parameter(Mandatory = $false)]
    [string] $AzureClientSecret,

    [Parameter(Mandatory = $false)]
    [string] $AzureTenantId,

    [Parameter(Mandatory = $false)]
    [switch] $UseManagedIdentity,

    [Parameter(Mandatory = $false)]
    [string] $ManagedIdentityName = 'id-aib-win11-installer-gui-001',

    [Parameter(Mandatory = $false)]
    [string] $ManagedIdentityResourceGroup = 'rg-ned-prd-mdp-001'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
Import-Module (Join-Path $repoRoot 'helpers\GenerateResourcesAndImage.ps1') -Force

# Prerequisites
if (-not (Get-Command packer -ErrorAction SilentlyContinue)) {
    throw "Packer not found. Install: choco install packer -y"
}

$hasInstaller = -not [string]::IsNullOrWhiteSpace($env:INSTALLSHIELD_INSTALLER_URL) `
    -or -not [string]::IsNullOrWhiteSpace($env:INSTALLSHIELD_INSTALLER_PATH) `
    -or -not [string]::IsNullOrWhiteSpace($env:INSTALLSHIELD_ARTIFACTS_STORAGE_ACCOUNT)

if (-not $hasInstaller) {
    throw @"
InstallShield installer source not configured. Set one of:
  `$env:INSTALLSHIELD_INSTALLER_URL = '<SAS URL>'
  `$env:INSTALLSHIELD_INSTALLER_PATH = 'C:\path\InstallShield2025StandaloneBuild.exe'
  `$env:INSTALLSHIELD_ARTIFACTS_STORAGE_ACCOUNT = '<storage account name>'
"@
}

$env:GALLERY_NAME = $GalleryName
$env:GALLERY_RG_NAME = $GalleryResourceGroupName
$env:GALLERY_IMAGE_NAME = $GalleryImageName
$env:GALLERY_IMAGE_VERSION = $ImageVersion
$env:GALLERY_STORAGE_ACCOUNT_TYPE = 'Premium_LRS'

Write-Host "=== InstallShield image build (NED PRD) ==="
Write-Host "  Subscription:  $SubscriptionId"
Write-Host "  Location:        $AzureLocation"
Write-Host "  Gallery:         $GalleryName / $GalleryImageName"
Write-Host "  Version:         $ImageVersion"
Write-Host "  Build RG:        $ResourceGroupName"
Write-Host ""

if ($WhatIfPreference) {
    Write-Host "WhatIf: would run GenerateResourcesAndImage -ImageType Windows2022InstallShield"
    return
}

$params = @{
    SubscriptionId              = $SubscriptionId
    ResourceGroupName           = $ResourceGroupName
    ImageType                   = [ImageType]::Windows2022InstallShield
    AzureLocation               = $AzureLocation
    ManagedImageName            = "installshield-win2022-$ImageVersion"
    ImageGenerationRepositoryRoot = $repoRoot
    OnError                     = 'abort'
}

if ($RestrictToAgentIpAddress) {
    $params.RestrictToAgentIpAddress = $true
}

if ($UseManagedIdentity) {
    Write-Host "Resolving managed identity '$ManagedIdentityName'..."
    $miClientId = az identity show `
        --resource-group $ManagedIdentityResourceGroup `
        --name $ManagedIdentityName `
        --query clientId -o tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($miClientId)) {
        throw "Managed identity '$ManagedIdentityName' not found in '$ManagedIdentityResourceGroup'."
    }
    Write-Host "  Client ID: $miClientId"
    $params.UseAzureCliAuth = $true
    $params.ManagedIdentityClientId = $miClientId
}
elseif (-not [string]::IsNullOrWhiteSpace($AzureClientId)) {
    $params.AzureClientId = $AzureClientId
    $params.AzureClientSecret = $AzureClientSecret
    $params.AzureTenantId = $AzureTenantId
}

GenerateResourcesAndImage @params

$versionId = "/subscriptions/$SubscriptionId/resourceGroups/$GalleryResourceGroupName/providers/Microsoft.Compute/galleries/$GalleryName/images/$GalleryImageName/versions/$ImageVersion"
Write-Host ""
Write-Host "=== Build complete ==="
Write-Host "Gallery version: $versionId"
Write-Host ""
Write-Host "Register on MDP:"
Write-Host "  .\Update-ManagedDevOpsPoolImage.ps1 ``"
Write-Host "    -ResourceGroupName '$ResourceGroupName' ``"
Write-Host "    -PoolName 'mdp-ned-prd-winbuild-001' ``"
Write-Host "    -GalleryImageVersionResourceId '$versionId'"
