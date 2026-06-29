################################################################################
##  File:  Import-ImageHelpers.ps1
##  Desc:  Load ImageHelpers after Packer restarts (new WinRM session)
################################################################################

Import-Module ImageHelpers -DisableNameChecking -Force

if ($env:TEMP_DIR -like 'D:\*' -and -not (Get-PSDrive -Name D -ErrorAction SilentlyContinue)) {
    & "$PSScriptRoot\Initialize-UiTestsDriveLetter.ps1"
}
