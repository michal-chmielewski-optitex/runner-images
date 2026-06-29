Describe "WMIC" {
    It "wmic is on PATH" {
        "wmic /?" | Should -ReturnZeroExitCode
    }
}
