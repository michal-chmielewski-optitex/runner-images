Describe "Rclone" {
    It "rclone is on PATH" {
        "rclone version" | Should -ReturnZeroExitCode
    }
}
