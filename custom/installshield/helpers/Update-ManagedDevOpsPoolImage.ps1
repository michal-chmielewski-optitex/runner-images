<#
.SYNOPSIS
    Register a gallery image version on an existing Managed DevOps Pool.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string] $PoolName = 'mdp-ned-prd-winbuild-001',

    [Parameter(Mandatory = $true)]
    [string] $GalleryImageVersionResourceId,

    [Parameter(Mandatory = $false)]
    [string] $ImageAlias = 'installshield-2025',

    [Parameter(Mandatory = $false)]
    [string] $Buffer = '*',

    [Parameter(Mandatory = $false)]
    [string] $ApiVersion = '2025-09-20'
)

$ErrorActionPreference = 'Stop'

$subscriptionId = (az account show --query id -o tsv)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($subscriptionId)) {
    throw "Azure CLI is not authenticated. Run 'az login' or 'az login --identity' first."
}

$poolUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevOpsInfrastructure/pools/$PoolName?api-version=$ApiVersion"

Write-Host "Loading pool '$PoolName' (REST api-version $ApiVersion)..."
$poolJson = az rest --method get --url $poolUri --only-show-errors
if ($LASTEXITCODE -ne 0) {
    throw "Failed to load Managed DevOps Pool '$PoolName'."
}

$pool = $poolJson | ConvertFrom-Json
$fabric = $pool.properties.fabricProfile
if (-not $fabric) {
    throw "Pool '$PoolName' has no fabricProfile."
}

if (-not $fabric.images) {
    $fabric | Add-Member -NotePropertyName images -NotePropertyValue @() -Force
}

$updatedImages = [System.Collections.Generic.List[object]]::new()
$replaced = $false

foreach ($img in @($fabric.images)) {
    if ($img.aliases -contains $ImageAlias) {
        Write-Host "Updating image alias '$ImageAlias' -> $GalleryImageVersionResourceId"
        $updatedImages.Add([PSCustomObject]@{
            resourceId = $GalleryImageVersionResourceId
            aliases    = @($ImageAlias)
            buffer     = $Buffer
        })
        $replaced = $true
    }
    else {
        $updatedImages.Add($img)
    }
}

if (-not $replaced) {
    Write-Host "Adding image alias '$ImageAlias'."
    $updatedImages.Add([PSCustomObject]@{
        resourceId = $GalleryImageVersionResourceId
        aliases    = @($ImageAlias)
        buffer     = $Buffer
    })
}

$fabric.images = $updatedImages.ToArray()

$putBody = [PSCustomObject]@{
    location   = $pool.location
    properties = $pool.properties
}
if ($null -ne $pool.tags) {
    $putBody | Add-Member -NotePropertyName tags -NotePropertyValue $pool.tags
}
if ($null -ne $pool.identity) {
    $putBody | Add-Member -NotePropertyName identity -NotePropertyValue $pool.identity
}

$tempFile = [System.IO.Path]::GetTempFileName() + '.json'
try {
    $putBody | ConvertTo-Json -Depth 50 | Set-Content -Path $tempFile -Encoding UTF8

    Write-Host "Updating fabricProfile on pool '$PoolName'..."
    az rest --method put --url $poolUri --body "@$tempFile" --only-show-errors
    if ($LASTEXITCODE -ne 0) {
        throw "Pool update failed."
    }
}
finally {
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}

Write-Host "Done. Pipelines: demands: ImageOverride -equals $ImageAlias"
