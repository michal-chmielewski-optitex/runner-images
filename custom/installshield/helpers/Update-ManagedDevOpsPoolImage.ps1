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
    [string] $Buffer = '*'
)

$ErrorActionPreference = 'Stop'

Write-Host "Loading pool '$PoolName'..."
$pool = az mdp pool show --resource-group $ResourceGroupName --name $PoolName -o json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "Failed to load Managed DevOps Pool '$PoolName'."
}

$fabric = $pool.properties.fabricProfile
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
$tempFile = [System.IO.Path]::GetTempFileName() + '.json'
$fabric | ConvertTo-Json -Depth 20 | Set-Content -Path $tempFile -Encoding UTF8

try {
    Write-Host "Updating fabricProfile on pool '$PoolName'..."
    az mdp pool update `
        --resource-group $ResourceGroupName `
        --name $PoolName `
        --fabric-profile "@$tempFile" `
        --only-show-errors

    if ($LASTEXITCODE -ne 0) {
        throw "az mdp pool update failed."
    }
}
finally {
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}

Write-Host "Done. Pipelines: demands: ImageOverride -equals $ImageAlias"
