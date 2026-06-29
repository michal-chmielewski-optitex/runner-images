Describe "AltTester Desktop" {
    It "AltTesterDesktop.exe is installed" {
        $env:ALTTTESTER_DESKTOP_PATH | Should -Not -BeNullOrEmpty
        $env:ALTTTESTER_DESKTOP_PATH | Should -Exist
    }

    It "AltTesterDesktop.exe has a file version" {
        $version = (Get-Item $env:ALTTTESTER_DESKTOP_PATH).VersionInfo.FileVersion
        $version | Should -Not -BeNullOrEmpty
    }
}
