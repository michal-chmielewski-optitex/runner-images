################################################################################
##  File:  UiTests-StartupExperienceRegistry.ps1
##  Desc:  Registry settings to suppress Win11 Get Started / welcome UI
################################################################################

function Set-UiTestsStartupRegistry {
    param([string]$RootKey)

    $useRegExe = $RootKey -eq 'HKLM:\DEFAULT'

    function Set-Dword {
        param(
            [Parameter(Mandatory = $true)][string] $RelativePath,
            [Parameter(Mandatory = $true)][string] $Name,
            [Parameter(Mandatory = $true)][int] $Value
        )

        Set-RegistryKeyDword `
            -KeyPath "$RootKey\$RelativePath" `
            -Name $Name `
            -Value $Value `
            -UseRegExe:$useRegExe
    }

    Set-Dword -RelativePath 'SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name DisableWindowsConsumerFeatures -Value 1
    Set-Dword -RelativePath 'SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name DisableCloudOptimizedContent -Value 1
    Set-Dword -RelativePath 'SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' -Name TurnOffWindowsCopilot -Value 1
    Set-Dword -RelativePath 'SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE' -Name DisablePrivacyExperience -Value 1
    Set-Dword -RelativePath 'SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement' -Name ScoobeSystemSettingEnabled -Value 0
    Set-Dword -RelativePath 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name StartShownOnUpgrade -Value 0
    Set-Dword -RelativePath 'SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name HideRecentlyAddedApps -Value 1

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
        Set-Dword -RelativePath 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name $name -Value 0
    }

    if ($RootKey -eq 'HKLM:') {
        Set-RegistryKeyDword `
            -KeyPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' `
            -Name EnableFirstLogonAnimation `
            -Value 0
    }
}

function Set-UiTestsStartupRunOnce {
    param([string]$RootKey)

    $useRegExe = $RootKey -eq 'HKLM:\DEFAULT'
    $command = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\post-generation\Disable-UiTestsStartupExperience.ps1'
    $runOncePath = "$RootKey\Software\Microsoft\Windows\CurrentVersion\RunOnce"

    Set-RegistryKeyString `
        -KeyPath $runOncePath `
        -Name DisableUiTestsWelcome `
        -Value $command `
        -UseRegExe:$useRegExe
}

function Clear-UiTestsGetStartedRunOnce {
    param([string]$RootKey)

    $runOncePath = "$RootKey\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    if (Test-Path $runOncePath) {
        Remove-ItemProperty -Path $runOncePath -Name 'GetStarted' -ErrorAction SilentlyContinue
    }
}
