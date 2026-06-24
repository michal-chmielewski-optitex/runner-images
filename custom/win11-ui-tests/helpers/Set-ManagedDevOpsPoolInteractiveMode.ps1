<#
.SYNOPSIS
    Enable or disable interactive desktop sessions on a Managed DevOps Pool (required for GUI / WinAppDriver tests).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string] $PoolName = 'mdp-ned-prd-uittest-001',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Service')]
    [string] $LogonType = 'Interactive',

    [Parameter(Mandatory = $false)]
    [string] $ApiVersion = '2025-09-20'
)

$ErrorActionPreference = 'Stop'

$subscriptionId = (az account show --query id -o tsv)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($subscriptionId)) {
    throw "Azure CLI is not authenticated. Run 'az login' or 'az login --identity' first."
}

$poolUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevOpsInfrastructure/pools/$PoolName?api-version=$ApiVersion"

Write-Host "Loading pool '$PoolName'..."
$poolJson = az rest --method get --url "$poolUri" --only-show-errors
if ($LASTEXITCODE -ne 0) {
    throw "Failed to load Managed DevOps Pool '$PoolName'."
}

$pool = $poolJson | ConvertFrom-Json
$fabric = $pool.properties.fabricProfile
if (-not $fabric) {
    throw "Pool '$PoolName' has no fabricProfile."
}

if (-not $fabric.osProfile) {
    $fabric | Add-Member -NotePropertyName osProfile -NotePropertyValue ([PSCustomObject]@{}) -Force
}

$fabric.osProfile | Add-Member -NotePropertyName logonType -NotePropertyValue $LogonType -Force

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

    Write-Host "Setting fabricProfile.osProfile.logonType = '$LogonType' on pool '$PoolName'..."
    az rest --method put --url "$poolUri" --body "@$tempFile" --only-show-errors
    if ($LASTEXITCODE -ne 0) {
        throw "Pool update failed."
    }
}
finally {
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}

Write-Host "Done. UI test pipelines require logonType '$LogonType'."
