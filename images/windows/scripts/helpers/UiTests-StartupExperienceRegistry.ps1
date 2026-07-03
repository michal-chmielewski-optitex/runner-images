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
    $scriptPath = 'C:\post-generation\Disable-UiTestsStartupWatchdog.ps1'

    if (-not (Test-Path $scriptPath)) {
        Write-Warning "Post-gen watchdog script not found: $scriptPath"
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
    $repetitionTemplate = New-ScheduledTaskTrigger -Once -At (Get-Date) `
        -RepetitionInterval (New-TimeSpan -Seconds 30) `
        -RepetitionDuration (New-TimeSpan -Days 365)
    $trigger.Repetition = $repetitionTemplate.Repetition

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Seconds 25) `
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
        -Description 'Kill Get Started if it appears during UI test sessions.' `
        -Force | Out-Null

    Write-Host "Registered scheduled task '$taskName' (AtLogOn, repeat every 30 seconds)."
}

function Set-UiTestsPowerSettings {
    Write-Host 'Configuring power settings: disable display sleep and system standby.'

    $highPerformanceGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    & powercfg /setactive $highPerformanceGuid 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'High performance power plan is unavailable; applying timeouts to the active plan.'
    }
    $global:LASTEXITCODE = 0

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
        & powercfg /change $setting 0 | Out-Null
        $global:LASTEXITCODE = 0
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
        & powercfg $setter SCHEME_CURRENT $subNone $requirePasswordOnWake 0 | Out-Null
        & powercfg $setter SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 | Out-Null
        $global:LASTEXITCODE = 0
    }
    & powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
    $global:LASTEXITCODE = 0
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

function Invoke-UiTestsStartupExperienceConfiguration {
    Stop-UiTestsWelcomeProcesses
    Set-UiTestsPowerSettings
    Set-UiTestsStoreInstallDisabled
    Set-UiTestsStartupRegistry -RootKey 'HKLM:'

    Mount-RegistryHive `
        -FileName 'C:\Users\Default\NTUSER.DAT' `
        -SubKey 'HKLM\DEFAULT'

    try {
        Set-UiTestsStartupRegistry -RootKey 'HKLM:\DEFAULT'
        Set-UiTestsScreensaverDisabled -RootKey 'HKLM:\DEFAULT'
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
