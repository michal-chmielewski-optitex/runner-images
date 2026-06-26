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
    [int] $MaximumConcurrency = 1,

    [Parameter(Mandatory = $false)]
    [string] $SkuName = 'Standard_D4as_v5',

    [Parameter(Mandatory = $false)]
    [string] $ApiVersion = '2025-09-20',

    [Parameter(Mandatory = $false)]
    [int] $ProvisioningPollSeconds = 900
)

$ErrorActionPreference = 'Stop'

$account = az account show -o json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $null -eq $account) {
    throw "Azure CLI is not authenticated. Run 'az login' first."
}

$subscriptionId = $account.id
$userType = $account.user.type
$userName = $account.user.name

$baseUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevOpsInfrastructure/pools"
$sourceUri = '{0}/{1}?api-version={2}' -f $baseUri, $SourcePoolName, $ApiVersion
$targetUri = '{0}/{1}?api-version={2}' -f $baseUri, $PoolName, $ApiVersion

if ($userType -eq 'servicePrincipal') {
    throw @"
Pool creation requires a user account with Azure DevOps agent pool permissions, not a managed identity or service principal.
Currently signed in as: $userName

Run 'az login' (interactive) as a member of https://dev.azure.com/NEDGRAPHICS with project-level Agent pools Administrator or Creator on Optitex, then retry.
If a pool was already created by MI, delete it first:
  az rest --method delete --url '$targetUri'
"@
}

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
$props.maximumConcurrency = [int]$MaximumConcurrency
$props.fabricProfile.sku.name = $SkuName

foreach ($org in @($props.organizationProfile.organizations)) {
    $org.parallelism = [int]$MaximumConcurrency
}

if (-not $props.fabricProfile.osProfile) {
    $props.fabricProfile | Add-Member -NotePropertyName osProfile -NotePropertyValue ([PSCustomObject]@{}) -Force
}
$props.fabricProfile.osProfile | Add-Member -NotePropertyName logonType -NotePropertyValue $LogonType -Force

$props.fabricProfile.images = @(
    [PSCustomObject]@{
        resourceId    = $GalleryImageVersionResourceId
        aliases       = @($ImageAlias)
        buffer        = '*'
        ephemeralType = 'Automatic'
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
    Write-Host "Creating pool '$PoolName' (sku=$SkuName, maxAgents=$MaximumConcurrency, logonType=$LogonType, alias=$ImageAlias)..."
    az rest --method put --url $targetUri --body "@$tempFile" --only-show-errors
    if ($LASTEXITCODE -ne 0) {
        throw "Pool create failed."
    }
}
finally {
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}

Write-Host "Waiting for pool provisioning (up to $ProvisioningPollSeconds s)..."
$deadline = (Get-Date).AddSeconds($ProvisioningPollSeconds)
$finalState = $null
do {
    Start-Sleep -Seconds 15
    $prevErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $statusJson = az rest --method get --url $targetUri --only-show-errors 2>&1
    }
    finally {
        $ErrorActionPreference = $prevErrorAction
    }
    if ($LASTEXITCODE -ne 0) {
        $failedLog = az monitor activity-log list --resource-group $ResourceGroupName --offset 30m -o json | ConvertFrom-Json |
            Where-Object { $_.resourceId -like "*$PoolName*" -and $_.status.value -eq 'Failed' } |
            Sort-Object eventTimestamp -Descending |
            Select-Object -First 1
        if ($failedLog -and $failedLog.properties.statusMessage) {
            throw "Pool '$PoolName' provisioning failed (resource removed). $($failedLog.properties.statusMessage)"
        }
        throw "Failed to read provisioning state for '$PoolName'."
    }
    $status = $statusJson | ConvertFrom-Json
    $finalState = $status.properties.provisioningState
    Write-Host "  provisioningState: $finalState"
} while ($finalState -in @('Accepted', 'Provisioning', 'Updating') -and (Get-Date) -lt $deadline)

if ($finalState -ne 'Succeeded') {
    throw @"
Pool '$PoolName' did not reach provisioningState Succeeded (last state: $finalState).
Check Azure Portal > rg-ned-prd-mdp-001 > $PoolName > Overview (Pool Provisioning Health / error codes).
Common fix: delete the pool and recreate after 'az login' as an ADO user with Agent pools Administrator or Creator on project Optitex.
"@
}

Write-Host "Done. Pool is visible in https://dev.azure.com/NEDGRAPHICS/_settings/managedpools after refresh."
Write-Host "Pipelines:"
Write-Host "  pool:"
Write-Host "    name: $PoolName"
Write-Host "    demands:"
Write-Host "      - ImageOverride -equals $ImageAlias"
