using module ./software-report-base/SoftwareReport.psm1
using module ./software-report-base/SoftwareReport.Nodes.psm1

$global:ErrorActionPreference = "Stop"
$global:ProgressPreference = "SilentlyContinue"
$ErrorView = "NormalView"
Set-StrictMode -Version Latest

$moduleRoot = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules\ImageHelpers'
$moduleFile = Join-Path $moduleRoot 'ImageHelpers.psm1'
Import-Module $moduleFile -DisableNameChecking -Force

if (-not (Get-Command Invoke-ImageHelperScript -ErrorAction SilentlyContinue)) {
    . (Join-Path $moduleRoot 'PathHelpers.ps1')
}

if ($env:UI_TESTS_INIT_D_DRIVE -eq '1') {
    Invoke-ImageHelperScript -ScriptName 'Initialize-UiTestsDriveLetter.ps1'
}
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.Common.psm1") -DisableNameChecking -Force
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.Helpers.psm1") -DisableNameChecking -Force
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.Tools.psm1") -DisableNameChecking -Force
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.VisualStudio.psm1") -DisableNameChecking -Force

if (-not (Get-Command Get-VisualStudioVersion -ErrorAction SilentlyContinue)) {
    throw "Get-VisualStudioVersion was not loaded from SoftwareReport.VisualStudio.psm1"
}

function Get-UiTestsChromeVersion {
    $chromeExe = 'D:\WebDriver\chrome-win64\chrome.exe'
    if (-not (Test-Path $chromeExe)) {
        return 'Not installed'
    }
    return [System.Diagnostics.FileVersionInfo]::GetVersionInfo($chromeExe).ProductVersion
}

function Get-UiTestsChromeDriverVersion {
    $versionFile = 'D:\WebDriver\chromedriver-win64\versioninfo.txt'
    if (Test-Path $versionFile) {
        return (Get-Content $versionFile -Raw).Trim()
    }
    $driverExe = 'D:\WebDriver\chromedriver-win64\chromedriver.exe'
    if (-not (Test-Path $driverExe)) {
        return 'Not installed'
    }
    return (& $driverExe --version).Trim().Replace('ChromeDriver ', '')
}

function Get-RcloneVersion {
    if (-not (Get-Command rclone -ErrorAction SilentlyContinue)) {
        return 'Not installed'
    }
    return (rclone version | Select-Object -First 1).Replace('rclone ', '').Trim()
}

function Get-AltTesterDesktopVersion {
    $exePath = $env:ALTTTESTER_DESKTOP_PATH
    if (-not $exePath -or -not (Test-Path $exePath)) {
        return 'Not installed'
    }
    return [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exePath).FileVersion
}

function Get-NUnitConsoleVersion {
    $consoleExe = Get-ChildItem -Path "C:\Program Files\NUnit" -Filter "nunit3-console.exe" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if (-not $consoleExe) {
        return "Not installed"
    }

    return [System.Diagnostics.FileVersionInfo]::GetVersionInfo($consoleExe.FullName).FileVersion
}

function Get-UiTestsPowerShellModuleNodes {
    return (Get-ToolsetContent).powershellModules.name | Sort-Object | ForEach-Object {
        $moduleName = $_
        $moduleVersions = Get-Module -Name $moduleName -ListAvailable | Select-Object -ExpandProperty Version | Sort-Object -Unique
        [ToolVersionsListNode]::new($moduleName, $moduleVersions, '^\d+', "Inline")
    }
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
$tools.AddToolVersion("Azure CLI", $(Get-AzureCLIVersion))
$tools.AddToolVersion("Rclone", $(Get-RcloneVersion))
$tools.AddToolVersion("zstd", $(Get-ZstdVersion))
$tools.AddToolVersion("WMIC", $(if (Get-Command wmic.exe -ErrorAction SilentlyContinue) { 'Installed' } else { 'Not installed' }))
$tools.AddToolVersion("NUnit Console", $(Get-NUnitConsoleVersion))
$tools.AddToolVersion("Google Chrome (portable)", $(Get-UiTestsChromeVersion))
$tools.AddToolVersion("Chrome Driver", $(Get-UiTestsChromeDriverVersion))
$tools.AddToolVersion("AltTester Desktop", $(Get-AltTesterDesktopVersion))
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
$dotnetToolNodes = @(Get-DotnetTools)
if ($dotnetToolNodes.Count -gt 0) {
    $netCoreTools.AddNodes($dotnetToolNodes)
}

$psTools = $installedSoftware.AddHeader("PowerShell Tools")
$psTools.AddToolVersion("PowerShell", $(Get-PowershellCoreVersion))
$psModuleNodes = @(Get-UiTestsPowerShellModuleNodes)
if ($psModuleNodes.Count -gt 0) {
    $psTools.AddHeader("Powershell Modules").AddNodes($psModuleNodes)
}

$softwareReport.ToJson() | Out-File -FilePath "C:\software-report.json" -Encoding UTF8NoBOM
$softwareReport.ToMarkdown() | Out-File -FilePath "C:\software-report.md" -Encoding UTF8NoBOM
