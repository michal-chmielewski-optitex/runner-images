<#
.SYNOPSIS
    Build Windows 11 x64 + VS 2022 UI test image and publish to ACG acg_ned_prd_mdp_001 (NED PRD).

.DESCRIPTION
    Wrapper around GenerateResourcesAndImage with NED PRD defaults.
    Image stack: Win11 Enterprise x64, VS 2022 (.NET desktop workload matching baremetal),
    .NET SDK 8/9, NUnit Console, WinAppDriver, Developer Mode.

.EXAMPLE
    .\Build-Win11UiTestsImage-NedPrd.ps1 -ImageVersion "1.0.0"

.EXAMPLE
    .\Build-Win11UiTestsImage-NedPrd.ps1 -ImageVersion "1.0.0" -UseManagedIdentity -RestrictToAgentIpAddress
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
    [string] $GalleryImageName = 'win11-vs2022-ui-x64',

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
    [string] $ManagedIdentityResourceGroup = 'rg-ned-prd-mdp-001',

    [Parameter(Mandatory = $false)]
    [string] $VmSize = 'Standard_D4s_v5'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
Import-Module (Join-Path $repoRoot 'helpers\GenerateResourcesAndImage.ps1') -Force

if (-not (Get-Command packer -ErrorAction SilentlyContinue)) {
    throw "Packer not found. Install: choco install packer -y"
}

$env:GALLERY_NAME = $GalleryName
$env:GALLERY_RG_NAME = $GalleryResourceGroupName
$env:GALLERY_IMAGE_NAME = $GalleryImageName
$env:GALLERY_IMAGE_VERSION = $ImageVersion
$env:GALLERY_STORAGE_ACCOUNT_TYPE = 'Premium_LRS'
$env:BUILD_RG_NAME = $ResourceGroupName

function Test-AcgImageDefinitionExists {
    param(
        [string] $GalleryResourceGroup,
        [string] $Gallery,
        [string] $ImageDefinition
    )

    az sig image-definition show `
        --resource-group $GalleryResourceGroup `
        --gallery-name $Gallery `
        --gallery-image-definition $ImageDefinition `
        --only-show-errors 2>$null | Out-Null

    return $LASTEXITCODE -eq 0
}

Write-Host "=== Win11 x64 UI tests image build (NED PRD) ==="
Write-Host "  Subscription:  $SubscriptionId"
Write-Host "  Location:        $AzureLocation"
Write-Host "  Gallery:         $GalleryName / $GalleryImageName"
Write-Host "  Version:         $ImageVersion"
Write-Host "  Build RG:        $ResourceGroupName"
Write-Host "  VM size:         $VmSize"
Write-Host ""

if ($WhatIfPreference) {
    Write-Host "WhatIf: would run GenerateResourcesAndImage -ImageType Windows11_x64_ui_tests"
    return
}

$params = @{
    SubscriptionId                = $SubscriptionId
    ResourceGroupName             = $ResourceGroupName
    ImageType                     = [ImageType]::Windows11_x64_ui_tests
    AzureLocation                 = $AzureLocation
    ManagedImageName              = "win11-vs2022-ui-x64-$ImageVersion"
    ImageGenerationRepositoryRoot = $repoRoot
    OnError                       = 'abort'
    VmSize                        = $VmSize
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

if ($UseManagedIdentity) {
    az login --identity --client-id $params.ManagedIdentityClientId --output none
    az account set --subscription $SubscriptionId
}

if (-not (Test-AcgImageDefinitionExists -GalleryResourceGroup $GalleryResourceGroupName -Gallery $GalleryName -ImageDefinition $GalleryImageName)) {
    $bicepPath = Join-Path $repoRoot 'custom\win11-ui-tests\infra\bicep\main.bicep'
    $bicepParams = Join-Path $repoRoot 'custom\win11-ui-tests\infra\parameters\ned-prd.bicepparam'
    throw @"
Gallery image definition '$GalleryImageName' not found in '$GalleryName' (RG: $GalleryResourceGroupName).

Run one-time Bicep deploy before the first Packer build (Reader role skipped — already set for InstallShield):

  cd $repoRoot
  az deployment group create `
    --resource-group $GalleryResourceGroupName `
    --template-file $bicepPath `
    --parameters $bicepParams `
    --parameters deployGalleryReaderRole=false

Then re-run this script.
"@
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
Write-Host "    -PoolName 'mdp-ned-prd-uittest-001' ``"
Write-Host "    -GalleryImageVersionResourceId '$versionId' ``"
Write-Host "    -ImageAlias 'win11-vs2022-ui-x64'"
Write-Host ""
Write-Host "Enable interactive desktop on the UI test pool:"
Write-Host "  .\Set-ManagedDevOpsPoolInteractiveMode.ps1 ``"
Write-Host "    -ResourceGroupName '$ResourceGroupName' ``"
Write-Host "    -PoolName 'mdp-ned-prd-uittest-001'"
