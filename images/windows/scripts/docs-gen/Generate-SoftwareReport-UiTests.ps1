using module ./software-report-base/SoftwareReport.psm1
using module ./software-report-base/SoftwareReport.Nodes.psm1

$global:ErrorActionPreference = "Stop"
$global:ProgressPreference = "SilentlyContinue"
$ErrorView = "NormalView"
Set-StrictMode -Version Latest

Import-Module ImageHelpers -DisableNameChecking -Force
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.Common.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.Helpers.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.Tools.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.VisualStudio.psm1") -DisableNameChecking

function Get-NUnitConsoleVersion {
    $consoleExe = Get-ChildItem -Path "C:\Program Files\NUnit" -Filter "nunit3-console.exe" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if (-not $consoleExe) {
        return "Not installed"
    }

    return [System.Diagnostics.FileVersionInfo]::GetVersionInfo($consoleExe.FullName).FileVersion
}

$softwareReport = [SoftwareReport]::new($(Build-OSInfoSection))
$installedSoftware = $softwareReport.Root.AddHeader("Installed Software")

$languageAndRuntime = $installedSoftware.AddHeader("Language and Runtime")
$languageAndRuntime.AddToolVersion("Bash", $(Get-BashVersion))

$packageManagement = $installedSoftware.AddHeader("Package Management")
$packageManagement.AddToolVersion("Chocolatey", $(Get-ChocoVersion))
$packageManagement.AddToolVersion("NuGet", $(Get-NugetVersion))

$tools = $installedSoftware.AddHeader("Tools")
$tools.AddToolVersion("Git", $(Get-GitVersion))
$tools.AddToolVersion("Git LFS", $(Get-GitLFSVersion))
$tools.AddToolVersion("NUnit Console", $(Get-NUnitConsoleVersion))
$tools.AddToolVersion("VSWhere", $(Get-VSWhereVersion))
$tools.AddToolVersion("WinAppDriver", $(Get-WinAppDriver))

$vsTable = Get-VisualStudioVersion
$visualStudio = $installedSoftware.AddHeader($vsTable.Name)
$visualStudio.AddTable($vsTable)

$workloads = $visualStudio.AddHeader("Workloads, components and extensions")
$workloads.AddTable($(Get-VisualStudioComponents))

$msVisualCpp = $visualStudio.AddHeader("Microsoft Visual C++")
$msVisualCpp.AddTable($(Get-VisualCPPComponents))

$visualStudio.AddToolVersionsList("Installed Windows SDKs", $(Get-WindowsSDKs).Versions, '^.+')

$netCoreTools = $installedSoftware.AddHeader(".NET Core Tools")
$netCoreTools.AddToolVersionsListInline(".NET Core SDK", $(Get-DotnetSdks).Versions, '^\d+\.\d+\.\d{3}')
$netCoreTools.AddToolVersionsListInline(".NET Framework", $(Get-DotnetFrameworkVersions), '^.+')
Get-DotnetRuntimes | ForEach-Object {
    $netCoreTools.AddToolVersionsListInline($_.Runtime, $_.Versions, '^.+')
}
$netCoreTools.AddNodes($(Get-DotnetTools))

$psTools = $installedSoftware.AddHeader("PowerShell Tools")
$psTools.AddToolVersion("PowerShell", $(Get-PowershellCoreVersion))
$psTools.AddHeader("Powershell Modules").AddNodes($(Get-PowerShellModules))

$softwareReport.ToJson() | Out-File -FilePath "C:\software-report.json" -Encoding UTF8NoBOM
$softwareReport.ToMarkdown() | Out-File -FilePath "C:\software-report.md" -Encoding UTF8NoBOM
