################################################################################
##  File:  Import-ImageHelpers.ps1
##  Desc:  Load ImageHelpers after Packer restarts (new WinRM session)
################################################################################

Import-Module ImageHelpers -DisableNameChecking -Force

if ($env:UI_TESTS_IMAGE -eq '1') {
    $initScript = Join-Path (Get-Module ImageHelpers).ModuleBase 'Initialize-UiTestsDriveLetter.ps1'
    & $initScript
}
