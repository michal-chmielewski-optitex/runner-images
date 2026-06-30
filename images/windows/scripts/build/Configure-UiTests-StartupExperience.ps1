################################################################################
##  File:  Configure-UiTests-StartupExperience.ps1
##  Desc:  Disable Win11 "Get Started" / welcome experience on interactive agents
################################################################################

function Set-UiTestsStartupRegistry {
    param([string]$RootKey)

    $cloudContentPath = "$RootKey\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    if (-not (Test-Path $cloudContentPath)) {
        New-Item -Path $cloudContentPath -Force | Out-Null
    }
    New-ItemProperty -Path $cloudContentPath -Name DisableWindowsConsumerFeatures -PropertyType DWORD -Value 1 -Force | Out-Null
    New-ItemProperty -Path $cloudContentPath -Name DisableCloudOptimizedContent -PropertyType DWORD -Value 1 -Force | Out-Null

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

$packagesToRemove = @(
    'Microsoft.Getstarted'
    'MicrosoftWindows.Client.OOBE'
)

foreach ($displayName in $packagesToRemove) {
    Get-AppxProvisionedPackage -Online |
        Where-Object { $_.DisplayName -eq $displayName } |
        ForEach-Object {
            Write-Host "Removing provisioned package: $($_.DisplayName)"
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName | Out-Null
        }
}

Write-Host 'Disabled Win11 startup / Get Started experience for new users.'

Invoke-PesterTests -TestFile 'UiTestsStartupExperience'
