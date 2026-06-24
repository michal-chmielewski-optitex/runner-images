Describe "NUnit" {
    BeforeAll {
        $nunitToolset = Get-ToolsetContent | Select-Object -ExpandProperty nunit
        $nunitVersionPath = Join-Path "C:\Program Files\NUnit" $nunitToolset.version
        $preferredPath = Join-Path $nunitVersionPath "bin\net462\nunit3-console.exe"

        if (Test-Path $preferredPath) {
            $script:nunitConsolePath = $preferredPath
        }
        else {
            $consoleExe = Get-ChildItem -Path $nunitVersionPath -Filter "nunit3-console.exe" -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.DirectoryName -match '\\net462$' } |
                Select-Object -First 1

            if (-not $consoleExe) {
                $consoleExe = Get-ChildItem -Path $nunitVersionPath -Filter "nunit3-console.exe" -Recurse -ErrorAction SilentlyContinue |
                    Select-Object -First 1
            }

            $script:nunitConsolePath = $consoleExe.FullName
        }
    }

    It "nunit3-console.exe is on PATH" {
        $script:nunitConsolePath | Should -Exist
        Get-Command nunit3-console.exe -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }
}
