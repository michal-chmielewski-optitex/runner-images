Describe "UiTests startup experience" {
    It "Windows welcome experience is disabled in default user profile" {
        Mount-RegistryHive `
            -FileName 'C:\Users\Default\NTUSER.DAT' `
            -SubKey 'HKLM\DEFAULT'

        try {
            $cdmPath = 'HKLM:\DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            (Get-ItemProperty -Path $cdmPath).'SubscribedContent-310093Enabled' | Should -Be 0

            $engagementPath = 'HKLM:\DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement'
            (Get-ItemProperty -Path $engagementPath).ScoobeSystemSettingEnabled | Should -Be 0
        }
        finally {
            Dismount-RegistryHive 'HKLM\DEFAULT'
        }
    }

    It "First logon welcome animation is disabled" {
        (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon').EnableFirstLogonAnimation | Should -Be 0
    }

    It "Recently added apps are hidden by policy" {
        (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer').HideRecentlyAddedApps | Should -Be 1
    }

    It "Get Started provisioned packages are removed" {
        $remaining = Get-AppxProvisionedPackage -Online |
            Where-Object { $_.DisplayName -in @('Microsoft.Getstarted', 'MicrosoftWindows.Client.OOBE') }
        @($remaining).Count | Should -Be 0
    }

    It "Consumer AppX packages are not provisioned" {
        $blocked = @(
            'Microsoft.OutlookForWindows'
            'MicrosoftTeams'
            'MSTeams'
            'Microsoft.MicrosoftOfficeHub'
            'Clipchamp.Clipchamp'
            'Microsoft.BingNews'
        )
        $remaining = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -in $blocked }
        @($remaining).Count | Should -Be 0
    }

    It "Windows Copilot is disabled by policy" {
        $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'
        (Get-ItemProperty -Path $path).TurnOffWindowsCopilot | Should -Be 1
    }

    It "Cloud consumer features policy is disabled" {
        $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
        (Get-ItemProperty -Path $path).DisableWindowsConsumerFeatures | Should -Be 1
        (Get-ItemProperty -Path $path).DisableConsumerAccountStateContent | Should -Be 1
    }

    It "Startup suppression scheduled task is registered" {
        $task = Get-ScheduledTask -TaskName 'DisableUiTestsStartupExperience' -ErrorAction SilentlyContinue
        $task | Should -Not -BeNullOrEmpty
        $task.Triggers.CimClass.CimClassName | Should -Contain 'MSFT_TaskLogonTrigger'
    }

    It "Startup watchdog scheduled task is registered" {
        $task = Get-ScheduledTask -TaskName 'DisableUiTestsStartupWatchdog' -ErrorAction SilentlyContinue
        $task | Should -Not -BeNullOrEmpty
        $task.Triggers.CimClass.CimClassName | Should -Contain 'MSFT_TaskLogonTrigger'
        $task.Triggers[0].Repetition.Interval | Should -Be 'PT30S'
    }

    It "Microsoft Store and InstallService are disabled" {
        $storePath = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'
        (Get-ItemProperty -Path $storePath).RemoveWindowsStore | Should -Be 1
        (Get-ItemProperty -Path $storePath).DisableStoreApps | Should -Be 1

        $appxPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx'
        (Get-ItemProperty -Path $appxPath).BlockNonAdminUserInstall | Should -Be 1

        (Get-Service -Name InstallService).StartType | Should -Be 'Disabled'
    }

    It "Display and system sleep timeouts are disabled" {
        $videoQuery = (& powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 2>&1) | Out-String
        $videoQuery | Should -Match 'Current AC Power Setting Index:\s+0x00000000'

        $sleepQuery = (& powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 2>&1) | Out-String
        $sleepQuery | Should -Match 'Current AC Power Setting Index:\s+0x00000000'
    }

    It "Screensaver is disabled by policy" {
        $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop'
        (Get-ItemProperty -Path $path).ScreenSaveActive | Should -Be '0'
        (Get-ItemProperty -Path $path).ScreenSaveTimeOut | Should -Be '0'
    }

    It "Screensaver is disabled in default user profile" {
        Mount-RegistryHive `
            -FileName 'C:\Users\Default\NTUSER.DAT' `
            -SubKey 'HKLM\DEFAULT'

        try {
            $desktopPath = 'HKLM:\DEFAULT\Control Panel\Desktop'
            (Get-ItemProperty -Path $desktopPath).ScreenSaveActive | Should -Be '0'
            (Get-ItemProperty -Path $desktopPath).ScreenSaveTimeOut | Should -Be '0'
            (Get-ItemProperty -Path $desktopPath).ScreenSaverIsSecure | Should -Be '0'
        }
        finally {
            Dismount-RegistryHive 'HKLM\DEFAULT'
        }
    }

    It "Automatic workstation lock and session timeouts are disabled" {
        $systemPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        (Get-ItemProperty -Path $systemPath).InactivityTimeoutSecs | Should -Be 0
        (Get-ItemProperty -Path $systemPath).DisableLockWorkstation | Should -Be 1

        $personalizationPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'
        (Get-ItemProperty -Path $personalizationPath).NoLockScreen | Should -Be 1

        $tsPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
        (Get-ItemProperty -Path $tsPath).MaxIdleTime | Should -Be 0
        (Get-ItemProperty -Path $tsPath).MaxDisconnectionTime | Should -Be 0
    }
}
