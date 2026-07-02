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
    }
}
