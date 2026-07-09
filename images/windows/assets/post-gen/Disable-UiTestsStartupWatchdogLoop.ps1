################################################################################
##  File:  Disable-UiTestsStartupWatchdogLoop.ps1 (post-generation)
##  Desc:  Background loop (1s) suppressing delayed Get Started / Start menu / Narrator popups
################################################################################

if (-not (Test-Path 'C:\imagedata.json')) {
    return
}

$imageData = Get-Content 'C:\imagedata.json' -Raw
if ($imageData -notmatch 'windows-11-x64-ui-tests') {
    return
}

Import-Module ImageHelpers -DisableNameChecking -Force

$packagesScript = Join-Path $PSScriptRoot 'UiTests-ProvisionedPackages.ps1'
$registryScript = Join-Path $PSScriptRoot 'UiTests-StartupExperienceRegistry.ps1'

while ($true) {
    if (Test-Path $packagesScript) {
        . $packagesScript
        Invoke-UiTestsWelcomeWatchdog
    }

    if (Test-Path $registryScript) {
        . $registryScript
        Clear-UiTestsGetStartedRunOnce -RootKey 'HKCU:'
    }

    Start-Sleep -Seconds 1
}
