Describe "Zstd" {
    It "zstd" {
        "zstd -V" | Should -ReturnZeroExitCode
    }
}
