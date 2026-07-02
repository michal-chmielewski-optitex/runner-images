################################################################################
##  File:  Configure-UiTests-StartupExperience.ps1
##  Desc:  Disable Win11 "Get Started" / welcome experience on interactive agents
################################################################################

. (Get-ImageHelperScriptPath -ScriptName 'UiTests-ProvisionedPackages.ps1')
. (Get-ImageHelperScriptPath -ScriptName 'UiTests-StartupExperienceRegistry.ps1')

Stop-UiTestsWelcomeProcesses

Set-UiTestsStartupRegistry -RootKey 'HKLM:'

Mount-RegistryHive `
    -FileName 'C:\Users\Default\NTUSER.DAT' `
    -SubKey 'HKLM\DEFAULT'

Set-UiTestsStartupRegistry -RootKey 'HKLM:\DEFAULT'
Set-UiTestsStartupRunOnce -RootKey 'HKLM:\DEFAULT'
Clear-UiTestsGetStartedRunOnce -RootKey 'HKLM:\DEFAULT'

Dismount-RegistryHive 'HKLM\DEFAULT'

Remove-UiTestsProvisionedPackages
Remove-UiTestsInstalledPackagesForAllUsers

foreach ($scriptName in @(
        'UiTests-ProvisionedPackages.ps1'
        'UiTests-StartupExperienceRegistry.ps1'
    )) {
    Copy-Item -Path (Get-ImageHelperScriptPath -ScriptName $scriptName) -Destination 'C:\post-generation\' -Force
}

Copy-Item -Path (Get-ImageHelperScriptPath -ScriptName 'Initialize-UiTestsDriveLetter.ps1') `
    -Destination (Join-Path 'C:\post-generation\' 'UiTests-DriveLetterMapping.ps1') `
    -Force

Write-Host 'Disabled Win11 startup experience and removed consumer AppX packages.'

Invoke-PesterTests -TestFile 'UiTestsStartupExperience'
