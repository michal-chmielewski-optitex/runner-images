################################################################################
##  File:  Configure-UiTests-VisualStudio.ps1
##  Desc:  Disable VS sign-in and complete first-launch warmup before sysprep
################################################################################

. (Get-ImageHelperScriptPath -ScriptName 'UiTests-VisualStudioConfiguration.ps1')

Invoke-UiTestsVisualStudioWarmup
Invoke-UiTestsVisualStudioDefaultUserConfiguration

Copy-Item -Path (Get-ImageHelperScriptPath -ScriptName 'UiTests-VisualStudioConfiguration.ps1') `
    -Destination 'C:\post-generation\' `
    -Force

Write-Host 'Configured Visual Studio sign-in suppression for UI test agents.'

Invoke-PesterTests -TestFile 'UiTestsVisualStudio'
