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
    Set-Dword -RelativePath 'SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name DisableConsumerAccountStateContent -Value 1
    Set-Dword -RelativePath 'SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name DisableWindowsSpotlightFeatures -Value 1
    Set-Dword -RelativePath 'SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' -Name TurnOffWindowsCopilot -Value 1
    Set-Dword -RelativePath 'SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE' -Name DisablePrivacyExperience -Value 1
    Set-Dword -RelativePath 'SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement' -Name ScoobeSystemSettingEnabled -Value 0
    Set-Dword -RelativePath 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name StartShownOnUpgrade -Value 0
    Set-Dword -RelativePath 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name Start_IrisRecommendations -Value 0
    Set-Dword -RelativePath 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name Start_Layout -Value 1
    Set-Dword -RelativePath 'SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name HideRecentlyAddedApps -Value 1
    Set-Dword -RelativePath 'SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name HideRecommendedSection -Value 1

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

function Remove-UiTestsDefaultUserConsumerPackages {
    $packagesRoot = 'C:\Users\Default\AppData\Local\Packages'
    if (-not (Test-Path $packagesRoot)) {
        return
    }

    $patterns = @(
        '*MicrosoftWindows.Client.OOBE*'
        '*Microsoft.Getstarted*'
        '*MicrosoftWindows.Client.WebExperience*'
        '*Microsoft.StartExperiencesApp*'
        '*Clipchamp*'
    )

    foreach ($pattern in $patterns) {
        Get-ChildItem -Path $packagesRoot -Filter $pattern -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                Write-Host "Removing default user package folder: $($_.Name)"
                Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
    }
}

function Register-UiTestsStartupLogonTask {
    $taskName = 'DisableUiTestsStartupExperience'
    $scriptPath = 'C:\post-generation\Disable-UiTestsStartupExperience.ps1'

    if (-not (Test-Path $scriptPath)) {
        Write-Warning "Post-gen script not found: $scriptPath"
        return
    }

    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }

    $action = New-ScheduledTaskAction `
        -Execute 'powershell.exe' `
        -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

    $principal = New-ScheduledTaskPrincipal `
        -GroupId 'BUILTIN\Users' `
        -RunLevel Highest

    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description 'Suppress Win11 Get Started on interactive UI test agents.' `
        -Force | Out-Null

    Write-Host "Registered scheduled task '$taskName' (AtLogOn, all users)."
}

function Set-UiTestsStoreInstallDisabled {
    Write-Host 'Disabling Microsoft Store, AppX user installs, and InstallService.'

    $storePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'
    if (-not (Test-Path $storePolicyPath)) {
        New-Item -Path $storePolicyPath -Force | Out-Null
    }
    New-ItemProperty -Path $storePolicyPath -Name RemoveWindowsStore -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $storePolicyPath -Name DisableStoreApps -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $storePolicyPath -Name AutoDownload -Value 4 -PropertyType DWord -Force | Out-Null

    $appxPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx'
    if (-not (Test-Path $appxPolicyPath)) {
        New-Item -Path $appxPolicyPath -Force | Out-Null
    }
    New-ItemProperty -Path $appxPolicyPath -Name BlockNonAdminUserInstall -Value 1 -PropertyType DWord -Force | Out-Null

    foreach ($serviceName in @('InstallService', 'WSService')) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            continue
        }

        if ($service.Status -eq 'Running') {
            Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        }
        Set-Service -Name $serviceName -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "Disabled service: $serviceName"
    }
}

function Stop-UiTestsStoreInstallServices {
    foreach ($serviceName in @('InstallService', 'WSService')) {
        Get-Service -Name $serviceName -ErrorAction SilentlyContinue |
            Where-Object { $_.Status -eq 'Running' } |
            Stop-Service -Force -ErrorAction SilentlyContinue
    }
}

function Register-UiTestsStartupWatchdogTask {
    $taskName = 'DisableUiTestsStartupWatchdog'
    $scriptPath = 'C:\post-generation\Start-UiTestsStartupWatchdogLoop.ps1'

    if (-not (Test-Path $scriptPath)) {
        Write-Warning "Post-gen watchdog launcher not found: $scriptPath"
        return
    }

    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }

    $action = New-ScheduledTaskAction `
        -Execute 'powershell.exe' `
        -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

    $trigger = New-ScheduledTaskTrigger -AtLogOn

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 2) `
        -MultipleInstances IgnoreNew

    $principal = New-ScheduledTaskPrincipal `
        -GroupId 'BUILTIN\Users' `
        -RunLevel Highest

    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description 'Start background Get Started watchdog loop on interactive UI test agents.' `
        -Force | Out-Null

    Write-Host "Registered scheduled task '$taskName' (AtLogOn, starts 5-second watchdog loop)."
}

function Invoke-UiTestsPowerCfg {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList
    )

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try {
        & powercfg.exe @ArgumentList 2>&1 | Out-Null
        return $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
        $global:LASTEXITCODE = 0
    }
}

function Set-UiTestsPowerSettings {
    Write-Host 'Configuring power settings: disable display sleep and system standby.'

    $highPerformanceGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    if ((Invoke-UiTestsPowerCfg @('/setactive', $highPerformanceGuid)) -ne 0) {
        Write-Warning 'High performance power plan is unavailable; applying timeouts to the active plan.'
    }

    foreach ($setting in @(
            'monitor-timeout-ac'
            'monitor-timeout-dc'
            'standby-timeout-ac'
            'standby-timeout-dc'
            'hibernate-timeout-ac'
            'hibernate-timeout-dc'
            'disk-timeout-ac'
            'disk-timeout-dc'
        )) {
        Invoke-UiTestsPowerCfg @('/change', $setting, '0') | Out-Null
    }

    $policyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop'
    if (-not (Test-Path $policyPath)) {
        New-Item -Path $policyPath -Force | Out-Null
    }
    New-ItemProperty -Path $policyPath -Name ScreenSaveActive -Value '0' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $policyPath -Name ScreenSaveTimeOut -Value '0' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $policyPath -Name ScreenSaverIsSecure -Value '0' -PropertyType String -Force | Out-Null

    Set-UiTestsSessionLockDisabled
}

function Set-UiTestsSessionLockDisabled {
    Write-Host 'Configuring session settings: disable auto-lock, sign-in on wake, and session timeouts.'

    $systemPolicyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    if (-not (Test-Path $systemPolicyPath)) {
        New-Item -Path $systemPolicyPath -Force | Out-Null
    }
    New-ItemProperty -Path $systemPolicyPath -Name InactivityTimeoutSecs -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $systemPolicyPath -Name DisableLockWorkstation -Value 1 -PropertyType DWord -Force | Out-Null

    $personalizationPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'
    if (-not (Test-Path $personalizationPath)) {
        New-Item -Path $personalizationPath -Force | Out-Null
    }
    New-ItemProperty -Path $personalizationPath -Name NoLockScreen -Value 1 -PropertyType DWord -Force | Out-Null

    $terminalServicesPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
    if (-not (Test-Path $terminalServicesPath)) {
        New-Item -Path $terminalServicesPath -Force | Out-Null
    }
    foreach ($name in @('MaxIdleTime', 'MaxDisconnectionTime', 'RemoteAppLogoffTimeLimit')) {
        New-ItemProperty -Path $terminalServicesPath -Name $name -Value 0 -PropertyType DWord -Force | Out-Null
    }

    $subNone = '238c9fa8-0aad-41ed-83f4-97be242c8f20'
    $requirePasswordOnWake = '0e796bdb-100d-47d6-a2d5-f7d2daa51f51'
    foreach ($setter in @('/SETACVALUEINDEX', '/SETDCVALUEINDEX')) {
        Invoke-UiTestsPowerCfg @($setter, 'SCHEME_CURRENT', $subNone, $requirePasswordOnWake, '0') | Out-Null
    }
    Invoke-UiTestsPowerCfg @('/SETACTIVE', 'SCHEME_CURRENT') | Out-Null
}

function Set-UiTestsScreensaverDisabled {
    param([string]$RootKey)

    $useRegExe = $RootKey -eq 'HKLM:\DEFAULT'
    $desktopPath = "$RootKey\Control Panel\Desktop"

    foreach ($entry in @(
            @{ Name = 'ScreenSaveActive'; Value = '0' }
            @{ Name = 'ScreenSaveTimeOut'; Value = '0' }
            @{ Name = 'ScreenSaverIsSecure'; Value = '0' }
        )) {
        Set-RegistryKeyString `
            -KeyPath $desktopPath `
            -Name $entry.Name `
            -Value $entry.Value `
            -UseRegExe:$useRegExe
    }
}

function Set-UiTestsStartMenuPolicyOverrides {
    $policyManagerStart = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start'
    if (-not (Test-Path $policyManagerStart)) {
        New-Item -Path $policyManagerStart -Force | Out-Null
    }
    New-ItemProperty -Path $policyManagerStart -Name HideRecommendedSection -Value 1 -PropertyType DWord -Force | Out-Null
}

function Set-UiTestsNarratorDisabled {
    Write-Host 'Disabling Windows Narrator on UI test agents.'

    $accessibilityPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Accessibility'
    if (-not (Test-Path $accessibilityPath)) {
        New-Item -Path $accessibilityPath -Force | Out-Null
    }
    Set-ItemProperty -Path $accessibilityPath -Name Configuration -Value '' -Force | Out-Null

    $ifeoPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\Narrator.exe'
    if (-not (Test-Path $ifeoPath)) {
        New-Item -Path $ifeoPath -Force | Out-Null
    }
    Set-ItemProperty -Path $ifeoPath -Name Debugger -Value '%1' -PropertyType String -Force | Out-Null

    Get-Process -Name Narrator -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

function Set-UiTestsNarratorUserRegistry {
    param([string]$RootKey)

    $useRegExe = $RootKey -eq 'HKLM:\DEFAULT'

    Set-RegistryKeyDword `
        -KeyPath "$RootKey\Software\Microsoft\Narrator\NoRoam" `
        -Name WinEnterLaunchEnabled `
        -Value 0 `
        -UseRegExe:$useRegExe

    Set-RegistryKeyDword `
        -KeyPath "$RootKey\Software\Microsoft\Narrator" `
        -Name OnlineServicesEnabled `
        -Value 0 `
        -UseRegExe:$useRegExe
}

function Invoke-UiTestsStartupExperienceConfiguration {
    Stop-UiTestsWelcomeProcesses
    Set-UiTestsPowerSettings
    Set-UiTestsStoreInstallDisabled
    Set-UiTestsStartMenuPolicyOverrides
    Set-UiTestsNarratorDisabled
    Set-UiTestsStartupRegistry -RootKey 'HKLM:'

    Mount-RegistryHive `
        -FileName 'C:\Users\Default\NTUSER.DAT' `
        -SubKey 'HKLM\DEFAULT'

    try {
        Set-UiTestsStartupRegistry -RootKey 'HKLM:\DEFAULT'
        Set-UiTestsScreensaverDisabled -RootKey 'HKLM:\DEFAULT'
        Set-UiTestsNarratorUserRegistry -RootKey 'HKLM:\DEFAULT'
        Set-UiTestsStartupRunOnce -RootKey 'HKLM:\DEFAULT'
        Clear-UiTestsGetStartedRunOnce -RootKey 'HKLM:\DEFAULT'
    }
    finally {
        Dismount-RegistryHive 'HKLM\DEFAULT'
    }

    Remove-UiTestsDefaultUserConsumerPackages
    Register-UiTestsStartupLogonTask
    Register-UiTestsStartupWatchdogTask
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
