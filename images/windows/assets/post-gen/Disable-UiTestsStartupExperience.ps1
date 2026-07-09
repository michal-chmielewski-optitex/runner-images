################################################################################
##  File:  Disable-UiTestsStartupExperience.ps1 (post-generation)
##  Desc:  Remove consumer apps and suppress welcome UI on interactive agent boot
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
    Stop-UiTestsWelcomeProcesses
    Remove-UiTestsProvisionedPackages
    Remove-UiTestsInstalledPackagesForAllUsers
    Remove-UiTestsSysprepBlockerPackages
    Remove-UiTestsNonProvisionedInstalledAppx
}

$vsConfigScript = Join-Path $PSScriptRoot 'UiTests-VisualStudioConfiguration.ps1'
if (Test-Path $vsConfigScript) {
    . $vsConfigScript
    Set-UiTestsVisualStudioSignInDisabled -RootKey 'HKCU:'
}

if (Test-Path $registryScript) {
    . $registryScript
    Set-UiTestsPowerSettings
    Set-UiTestsStoreInstallDisabled
    Set-UiTestsStartupRegistry -RootKey 'HKCU:'
    Set-UiTestsNarratorUserRegistry -RootKey 'HKCU:'
    Set-UiTestsScreensaverDisabled -RootKey 'HKCU:'
    Clear-UiTestsGetStartedRunOnce -RootKey 'HKCU:'
}

if (Test-Path $packagesScript) {
    . $packagesScript
    Invoke-UiTestsWelcomeWatchdog
}
