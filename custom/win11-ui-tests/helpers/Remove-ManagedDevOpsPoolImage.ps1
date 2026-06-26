<#
.SYNOPSIS
    Remove a gallery image alias from a Managed DevOps Pool (wrapper).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string] $PoolName = 'mdp-ned-prd-winbuild-001',

    [Parameter(Mandatory = $false)]
    [string] $ImageAlias = 'win11-vs2022-ui-x64',

    [Parameter(Mandatory = $false)]
    [string] $ApiVersion = '2025-09-20'
)

$removeScript = Join-Path $PSScriptRoot '..\..\installshield\helpers\Remove-ManagedDevOpsPoolImage.ps1'
if (-not (Test-Path $removeScript)) {
    throw "Shared helper not found: $removeScript"
}

& $removeScript `
    -ResourceGroupName $ResourceGroupName `
    -PoolName $PoolName `
    -ImageAlias $ImageAlias `
    -ApiVersion $ApiVersion
