Describe "WMIC" {
    It "wmic.exe is installed" {
        Join-Path $env:Windir 'System32\wbem\WMIC.exe' | Should -Exist
    }

    It "wmic is on PATH" {
        "wmic /?" | Should -ReturnZeroExitCode
    }
}
