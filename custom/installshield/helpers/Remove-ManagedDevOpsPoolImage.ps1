<#
.SYNOPSIS
    Remove a gallery image alias from an existing Managed DevOps Pool.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string] $PoolName,

    [Parameter(Mandatory = $true)]
    [string] $ImageAlias,

    [Parameter(Mandatory = $false)]
    [string] $ApiVersion = '2025-09-20'
)

$ErrorActionPreference = 'Stop'

$subscriptionId = (az account show --query id -o tsv)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($subscriptionId)) {
    throw "Azure CLI is not authenticated. Run 'az login' or 'az login --identity' first."
}

$poolBaseUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevOpsInfrastructure/pools/$PoolName"
$poolUri = '{0}?api-version={1}' -f $poolBaseUri, $ApiVersion

Write-Host "Loading pool '$PoolName'..."
$poolJson = az rest --method get --url $poolUri --only-show-errors
if ($LASTEXITCODE -ne 0) {
    throw "Failed to load Managed DevOps Pool '$PoolName'."
}

$pool = $poolJson | ConvertFrom-Json
$fabric = $pool.properties.fabricProfile
if (-not $fabric -or -not $fabric.images) {
    throw "Pool '$PoolName' has no fabricProfile.images."
}

$remaining = @($fabric.images | Where-Object { $_.aliases -notcontains $ImageAlias })
if ($remaining.Count -eq $fabric.images.Count) {
    Write-Host "Alias '$ImageAlias' not found on pool '$PoolName'. Nothing to remove."
    return
}

Write-Host "Removing image alias '$ImageAlias' from pool '$PoolName'..."
$fabric.images = $remaining

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
    az rest --method put --url $poolUri --body "@$tempFile" --only-show-errors
    if ($LASTEXITCODE -ne 0) {
        throw "Pool update failed."
    }
}
finally {
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}

Write-Host "Done. Remaining image aliases:"
$remaining | ForEach-Object { Write-Host "  - $($_.aliases -join ', ')" }
