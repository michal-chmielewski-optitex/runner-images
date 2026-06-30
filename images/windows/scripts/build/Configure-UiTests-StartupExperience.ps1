################################################################################
##  File:  Configure-UiTests-StartupExperience.ps1
##  Desc:  Disable Win11 "Get Started" / welcome experience on interactive agents
################################################################################

. (Get-ImageHelperScriptPath -ScriptName 'UiTests-ProvisionedPackages.ps1')

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
}

Set-UiTestsStartupRegistry -RootKey 'HKLM:'

Mount-RegistryHive `
    -FileName 'C:\Users\Default\NTUSER.DAT' `
    -SubKey 'HKLM\DEFAULT'

Set-UiTestsStartupRegistry -RootKey 'HKLM:\DEFAULT'

Dismount-RegistryHive 'HKLM\DEFAULT'

Remove-UiTestsProvisionedPackages

foreach ($scriptName in @(
        'UiTests-ProvisionedPackages.ps1'
    )) {
    Copy-Item -Path (Get-ImageHelperScriptPath -ScriptName $scriptName) -Destination 'C:\post-generation\' -Force
}

Copy-Item -Path (Get-ImageHelperScriptPath -ScriptName 'Initialize-UiTestsDriveLetter.ps1') `
    -Destination (Join-Path 'C:\post-generation\' 'UiTests-DriveLetterMapping.ps1') `
    -Force

Write-Host 'Disabled Win11 startup experience and removed consumer AppX packages.'

Invoke-PesterTests -TestFile 'UiTestsStartupExperience'
