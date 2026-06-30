################################################################################
##  File:  Configure-UiTests-StartupExperience.ps1
##  Desc:  Disable Win11 "Get Started" / welcome experience on interactive agents
################################################################################

. "$PSScriptRoot\UiTests-ProvisionedPackages.ps1"

function Set-UiTestsStartupRegistry {
    param([string]$RootKey)

    $cloudContentPath = "$RootKey\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    if (-not (Test-Path $cloudContentPath)) {
        New-Item -Path $cloudContentPath -Force | Out-Null
    }
    New-ItemProperty -Path $cloudContentPath -Name DisableWindowsConsumerFeatures -PropertyType DWORD -Value 1 -Force | Out-Null
    New-ItemProperty -Path $cloudContentPath -Name DisableCloudOptimizedContent -PropertyType DWORD -Value 1 -Force | Out-Null

    $copilotPolicyPath = "$RootKey\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
    if (-not (Test-Path $copilotPolicyPath)) {
        New-Item -Path $copilotPolicyPath -Force | Out-Null
    }
    New-ItemProperty -Path $copilotPolicyPath -Name TurnOffWindowsCopilot -PropertyType DWORD -Value 1 -Force | Out-Null

    $oobePath = "$RootKey\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE"
    if (-not (Test-Path $oobePath)) {
        New-Item -Path $oobePath -Force | Out-Null
    }
    New-ItemProperty -Path $oobePath -Name DisablePrivacyExperience -PropertyType DWORD -Value 1 -Force | Out-Null

    $cdmPath = "$RootKey\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    if (-not (Test-Path $cdmPath)) {
        New-Item -Path $cdmPath -Force | Out-Null
    }

    foreach ($name in @(
            'SubscribedContent-310093Enabled'
            'SubscribedContent-338388Enabled'
            'SubscribedContent-338389Enabled'
            'SubscribedContent-338393Enabled'
            'SubscribedContent-353694Enabled'
            'SubscribedContent-353696Enabled'
            'SoftLandingEnabled'
            'SystemPaneSuggestionsEnabled'
        )) {
        New-ItemProperty -Path $cdmPath -Name $name -PropertyType DWORD -Value 0 -Force | Out-Null
    }
}

Set-UiTestsStartupRegistry -RootKey 'HKLM:'

Mount-RegistryHive `
    -FileName 'C:\Users\Default\NTUSER.DAT' `
    -SubKey 'HKLM\DEFAULT'

Set-UiTestsStartupRegistry -RootKey 'HKLM:\DEFAULT'

Dismount-RegistryHive 'HKLM\DEFAULT'

Remove-UiTestsProvisionedPackages

Copy-Item -Path "$PSScriptRoot\UiTests-ProvisionedPackages.ps1" -Destination 'C:\post-generation\' -Force

Write-Host 'Disabled Win11 startup experience and removed consumer AppX packages.'

Invoke-PesterTests -TestFile 'UiTestsStartupExperience'
