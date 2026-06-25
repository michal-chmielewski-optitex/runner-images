################################################################################
##  File:  Run-UiTests-Tests.ps1
##  Desc:  Pester validation for lean Win11 x64 UI test image
################################################################################

Import-Module ImageHelpers -DisableNameChecking -Force
Import-Module Pester -Force
Import-Module TestsHelpers -Force

$testPaths = @(
    'VisualStudio.Tests.ps1',
    'NUnit.Tests.ps1',
    'WinAppDriver.Tests.ps1',
    'DotnetSDK.Tests.ps1',
    'ChocoPackages-UiTests.Tests.ps1',
    'Git.Tests.ps1',
    'PowerShellModules.Tests.ps1'
) | ForEach-Object { Join-Path 'C:\image\tests' $_ }

$configuration = [PesterConfiguration] @{
    Run        = @{ Path = $testPaths; PassThru = $true }
    Output     = @{ Verbosity = "Detailed"; RenderMode = "Plaintext" }
    TestResult = @{ Enabled = $true; OutputPath = "C:\image\tests\testResults.xml" }
}

Update-Environment

$backupErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop"
$results = Invoke-Pester -Configuration $configuration
$ErrorActionPreference = $backupErrorActionPreference

if (-not ($results -and ($results.FailedCount -eq 0) -and ($results.PassedCount -gt 0))) {
    $results
    throw "UI test image validation has failed"
}
