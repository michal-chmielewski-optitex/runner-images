################################################################################
##  File:  Import-ImageHelpers.ps1
##  Desc:  Load ImageHelpers after Packer restarts (new WinRM session)
################################################################################

Import-Module ImageHelpers -DisableNameChecking -Force
