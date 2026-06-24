<#
.SYNOPSIS
    Register a gallery image version on an existing Managed DevOps Pool.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string] $PoolName = 'mdp-ned-prd-uittest-001',

    [Parameter(Mandatory = $true)]
    [string] $GalleryImageVersionResourceId,

    [Parameter(Mandatory = $false)]
    [string] $ImageAlias = 'win11-vs2022-ui-x64',

    [Parameter(Mandatory = $false)]
    [string] $Buffer = '*',

    [Parameter(Mandatory = $false)]
    [string] $ApiVersion = '2025-09-20'
)

$ErrorActionPreference = 'Stop'

$updateScript = Join-Path $PSScriptRoot '..\..\installshield\helpers\Update-ManagedDevOpsPoolImage.ps1'
if (-not (Test-Path $updateScript)) {
    throw "Shared helper not found: $updateScript"
}

& $updateScript `
    -ResourceGroupName $ResourceGroupName `
    -PoolName $PoolName `
    -GalleryImageVersionResourceId $GalleryImageVersionResourceId `
    -ImageAlias $ImageAlias `
    -Buffer $Buffer `
    -ApiVersion $ApiVersion
