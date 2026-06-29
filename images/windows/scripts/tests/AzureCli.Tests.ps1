Describe "Azure CLI" {
    It "az --version" {
        "az --version" | Should -ReturnZeroExitCode
    }
}
