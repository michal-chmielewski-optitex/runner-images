################################################################################
##  File:  Import-ImageHelpers.ps1
##  Desc:  Load ImageHelpers after Packer restarts (new WinRM session)
################################################################################

Import-Module ImageHelpers -DisableNameChecking -Force

if ($env:UI_TESTS_IMAGE -eq '1') {
    & "$PSScriptRoot\Initialize-UiTestsDriveLetter.ps1"
}
