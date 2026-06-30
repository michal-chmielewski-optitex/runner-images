################################################################################
##  File:  Configure-UiTests-DeveloperMode.ps1
##  Desc:  Enable Developer Mode for WinAppDriver on Win11 UI test agents
################################################################################

$registryKeyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
if (-not (Test-Path -Path $registryKeyPath)) {
    New-Item -Path $registryKeyPath -ItemType Directory -Force | Out-Null
}

New-ItemProperty -Path $registryKeyPath -Name AllowDevelopmentWithoutDevLicense -PropertyType DWORD -Value 1 -Force | Out-Null
New-ItemProperty -Path $registryKeyPath -Name AllowAllTrustedApps -PropertyType DWORD -Value 1 -Force | Out-Null

Mount-RegistryHive `
    -FileName 'C:\Users\Default\NTUSER.DAT' `
    -SubKey 'HKLM\DEFAULT'

$defaultDevPath = 'HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\AppModelUnlock'
if (-not (Test-Path -Path $defaultDevPath)) {
    New-Item -Path $defaultDevPath -ItemType Directory -Force | Out-Null
}

New-ItemProperty -Path $defaultDevPath -Name AllowDevelopmentWithoutDevLicense -PropertyType DWORD -Value 1 -Force | Out-Null
New-ItemProperty -Path $defaultDevPath -Name AllowAllTrustedApps -PropertyType DWORD -Value 1 -Force | Out-Null

Dismount-RegistryHive 'HKLM\DEFAULT'

Write-Host 'Developer Mode enabled (machine + default user profile).'

Invoke-PesterTests -TestFile 'UiTestsDeveloperMode'
