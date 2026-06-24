Describe "NUnit" {
    It "nunit3-console.exe is on PATH" {
        $nunitToolset = Get-ToolsetContent | Select-Object -ExpandProperty nunit
        $nunitPath = Join-Path "C:\Program Files\NUnit" $nunitToolset.version "nunit3-console.exe"
        $nunitPath | Should -Exist
    }
}
