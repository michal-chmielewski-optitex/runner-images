<#
.SYNOPSIS
    Create mdp-ned-prd-uittest-001 by cloning mdp-ned-prd-winbuild-001 with logonType Interactive and Win11 UI image only.

.DESCRIPTION
    One-time setup for GUI test agents. Keeps InstallShield pool headless (Service logon).

.EXAMPLE
    .\New-UiTestsManagedDevOpsPool-NedPrd.ps1 `
      -GalleryImageVersionResourceId '/subscriptions/.../versions/1.0.0'
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string] $ResourceGroupName = 'rg-ned-prd-mdp-001',

    [Parameter(Mandatory = $false)]
    [string] $SourcePoolName = 'mdp-ned-prd-winbuild-001',

    [Parameter(Mandatory = $false)]
    [string] $PoolName = 'mdp-ned-prd-uittest-001',

    [Parameter(Mandatory = $true)]
    [string] $GalleryImageVersionResourceId,

    [Parameter(Mandatory = $false)]
    [string] $ImageAlias = 'win11-vs2022-ui-x64',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Service')]
    [string] $LogonType = 'Interactive',

    [Parameter(Mandatory = $false)]
    [int] $MaximumConcurrency = 2,

    [Parameter(Mandatory = $false)]
    [string] $ApiVersion = '2025-09-20'
)

$ErrorActionPreference = 'Stop'

$subscriptionId = (az account show --query id -o tsv)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($subscriptionId)) {
    throw "Azure CLI is not authenticated. Run 'az login' or 'az login --identity' first."
}

$baseUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevOpsInfrastructure/pools"
$sourceUri = '{0}/{1}?api-version={2}' -f $baseUri, $SourcePoolName, $ApiVersion
$targetUri = '{0}/{1}?api-version={2}' -f $baseUri, $PoolName, $ApiVersion

Write-Host "Loading template pool '$SourcePoolName'..."
$sourceJson = az rest --method get --url $sourceUri --only-show-errors
if ($LASTEXITCODE -ne 0) {
    throw "Failed to load source pool '$SourcePoolName'."
}

Write-Host "Checking whether pool '$PoolName' already exists..."
$prevErrorAction = $ErrorActionPreference
try {
    # az rest writes 404 to stderr; with $ErrorActionPreference Stop that aborts before $LASTEXITCODE is checked.
    $ErrorActionPreference = 'Continue'
    $null = az rest --method get --url $targetUri --only-show-errors 2>&1
    if ($LASTEXITCODE -eq 0) {
        throw "Pool '$PoolName' already exists. Use Update-ManagedDevOpsPoolImage.ps1 or delete the pool first."
    }
}
finally {
    $ErrorActionPreference = $prevErrorAction
}

$source = $sourceJson | ConvertFrom-Json
$props = $source.properties | ConvertTo-Json -Depth 50 | ConvertFrom-Json

$props.PSObject.Properties.Remove('provisioningState')
$props.maximumConcurrency = $MaximumConcurrency

if (-not $props.fabricProfile.osProfile) {
    $props.fabricProfile | Add-Member -NotePropertyName osProfile -NotePropertyValue ([PSCustomObject]@{}) -Force
}
$props.fabricProfile.osProfile | Add-Member -NotePropertyName logonType -NotePropertyValue $LogonType -Force

$props.fabricProfile.images = @(
    [PSCustomObject]@{
        resourceId = $GalleryImageVersionResourceId
        aliases    = @($ImageAlias)
        buffer     = '*'
    }
)

$putBody = [PSCustomObject]@{
    location   = $source.location
    properties = $props
}
if ($null -ne $source.tags) {
    $putBody | Add-Member -NotePropertyName tags -NotePropertyValue $source.tags
}
if ($null -ne $source.identity) {
    $putBody | Add-Member -NotePropertyName identity -NotePropertyValue $source.identity
}

if ($WhatIfPreference) {
    Write-Host "WhatIf: would create pool '$PoolName' with logonType=$LogonType and alias '$ImageAlias'"
    return
}

$tempFile = [System.IO.Path]::GetTempFileName() + '.json'
try {
    $putBody | ConvertTo-Json -Depth 50 | Set-Content -Path $tempFile -Encoding UTF8
    Write-Host "Creating pool '$PoolName' (logonType=$LogonType, alias=$ImageAlias)..."
    az rest --method put --url $targetUri --body "@$tempFile" --only-show-errors
    if ($LASTEXITCODE -ne 0) {
        throw "Pool create failed."
    }
}
finally {
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}

Write-Host "Done. Pipelines:"
Write-Host "  pool:"
Write-Host "    name: $PoolName"
Write-Host "    demands:"
Write-Host "      - ImageOverride -equals $ImageAlias"
