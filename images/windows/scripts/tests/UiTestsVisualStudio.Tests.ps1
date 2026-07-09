Describe "UiTests Visual Studio configuration" {
    BeforeAll {
        . (Get-ImageHelperScriptPath -ScriptName 'UiTests-VisualStudioConfiguration.ps1')
        $script:instanceIds = @(Get-UiTestsVisualStudioInstanceIds)
    }

    It "Visual Studio instance ids are discoverable" {
        $script:instanceIds.Count | Should -BeGreaterThan 0
    }

    It "Visual Studio sign-in is disabled for the build user" {
        foreach ($instanceId in $script:instanceIds) {
            $generalPath = "HKCU:\Software\Microsoft\VisualStudio\17.0_$instanceId\General"
            (Get-ItemProperty -Path $generalPath).DisableSignIn | Should -Be 1
        }
    }

    It "Visual Studio sign-in is disabled in default user profile" {
        Mount-RegistryHive `
            -FileName 'C:\Users\Default\NTUSER.DAT' `
            -SubKey 'HKLM\DEFAULT'

        try {
            foreach ($instanceId in $script:instanceIds) {
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
