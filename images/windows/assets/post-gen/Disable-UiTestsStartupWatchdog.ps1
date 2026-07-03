################################################################################
##  File:  Disable-UiTestsStartupWatchdog.ps1 (post-generation)
##  Desc:  Lightweight periodic cleanup when Get Started reinstalls mid-session
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

if (Test-Path $packagesScript) {
    . $packagesScript
    Invoke-UiTestsWelcomeWatchdog
}

if (Test-Path $registryScript) {
    . $registryScript
    Clear-UiTestsGetStartedRunOnce -RootKey 'HKCU:'
}
