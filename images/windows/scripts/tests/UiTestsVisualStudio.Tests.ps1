Describe "UiTests Visual Studio configuration" {
    BeforeAll {
        . (Get-ImageHelperScriptPath -ScriptName 'UiTests-VisualStudioConfiguration.ps1')
        $script:instanceIds = @(Get-UiTestsVisualStudioInstanceIds)
        $script:buildUserInstanceSuffixes = @(Get-UiTestsVisualStudioInstanceSuffixesFromRegistry -RootKey 'HKCU:')
    }

    It "Visual Studio instance ids are discoverable" {
        @($script:instanceIds + $script:buildUserInstanceSuffixes | Select-Object -Unique).Count |
            Should -BeGreaterThan 0
    }

    It "Visual Studio sign-in is disabled for the build user" {
        $script:buildUserInstanceSuffixes.Count | Should -BeGreaterThan 0

        foreach ($instanceId in $script:buildUserInstanceSuffixes) {
            $generalPath = "HKCU:\Software\Microsoft\VisualStudio\17.0_$instanceId\General"
            (Get-ItemProperty -Path $generalPath).DisableSignIn | Should -Be 1
        }
    }

    It "Visual Studio sign-in is disabled in default user profile" {
        Mount-RegistryHive `
            -FileName 'C:\Users\Default\NTUSER.DAT' `
            -SubKey 'HKLM\DEFAULT'

        try {
            $defaultUserInstanceSuffixes = @(Get-UiTestsVisualStudioInstanceSuffixesFromRegistry -RootKey 'HKLM:\DEFAULT')
            $defaultUserInstanceSuffixes.Count | Should -BeGreaterThan 0

            foreach ($instanceId in $defaultUserInstanceSuffixes) {
                $generalPath = "HKLM:\DEFAULT\Software\Microsoft\VisualStudio\17.0_$instanceId\General"
                (Get-ItemProperty -Path $generalPath).DisableSignIn | Should -Be 1
            }
        }
        finally {
            Dismount-RegistryHive 'HKLM\DEFAULT'
        }
    }

    It "Visual Studio configuration helper is deployed to post-generation" {
        Test-Path 'C:\post-generation\UiTests-VisualStudioConfiguration.ps1' | Should -Be $true
    }
}
