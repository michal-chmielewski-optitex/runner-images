Describe "AltTester Desktop" {
    It "AltTesterDesktop.exe is installed" {
        $env:ALTTTESTER_DESKTOP_PATH | Should -Not -BeNullOrEmpty
        $env:ALTTTESTER_DESKTOP_PATH | Should -Exist
    }

    It "AltTesterDesktop.exe reports version in batch mode" {
        & $env:ALTTTESTER_DESKTOP_PATH -batchmode -nographics -version | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}
