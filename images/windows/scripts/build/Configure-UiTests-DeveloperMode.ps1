################################################################################
##  File:  Configure-UiTests-DeveloperMode.ps1
##  Desc:  Enable Developer Mode for WinAppDriver on Win11 UI test agents
################################################################################

$registryKeyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
Set-RegistryKeyDword -KeyPath $registryKeyPath -Name AllowDevelopmentWithoutDevLicense -Value 1
Set-RegistryKeyDword -KeyPath $registryKeyPath -Name AllowAllTrustedApps -Value 1

Mount-RegistryHive `
    -FileName 'C:\Users\Default\NTUSER.DAT' `
    -SubKey 'HKLM\DEFAULT'

$defaultDevPath = 'HKLM:\DEFAULT\Software\Microsoft\Windows\CurrentVersion\AppModelUnlock'
Set-RegistryKeyDword -KeyPath $defaultDevPath -Name AllowDevelopmentWithoutDevLicense -Value 1 -UseRegExe
Set-RegistryKeyDword -KeyPath $defaultDevPath -Name AllowAllTrustedApps -Value 1 -UseRegExe

Dismount-RegistryHive 'HKLM\DEFAULT'

Write-Host 'Developer Mode enabled (machine + default user profile).'

Invoke-PesterTests -TestFile 'UiTestsDeveloperMode'
