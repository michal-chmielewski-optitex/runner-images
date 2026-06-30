Describe "UiTests Developer Mode" {
    It "AllowDevelopmentWithoutDevLicense is enabled" {
        $path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
        (Get-ItemProperty -Path $path).AllowDevelopmentWithoutDevLicense | Should -Be 1
    }

    It "AllowAllTrustedApps is enabled" {
        $path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
        (Get-ItemProperty -Path $path).AllowAllTrustedApps | Should -Be 1
    }
}
