Describe "InstallShield" {
    BeforeAll {
        $installShield = (Get-ToolsetContent).installshield
        $systemPath = $installShield.systemPath

        if (-not (Test-Path $systemPath)) {
            $discovered = Get-ChildItem -Path "${env:ProgramFiles(x86)}\InstallShield" -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match 'SAB' } |
                Select-Object -First 1
            if ($discovered) {
                $systemPath = Join-Path $discovered.FullName "System"
            }
        }

        $script:isCmdBldPath = Join-Path $systemPath "ISCmdBld.exe"
    }

    It "InstallShield SAB System directory exists" {
        Test-Path $systemPath | Should -Be $true
    }

    It "ISCmdBld.exe exists" {
        Test-Path $script:isCmdBldPath | Should -Be $true
    }

    It "ISCmdBld.exe is on PATH" {
        $env:PATH -split ";" | Should -Contain $systemPath
    }

    It "ISCmdBld.exe responds to -?" {
        $output = & $script:isCmdBldPath -? 2>&1
        $output | Should -Not -BeNullOrEmpty
    }
}
