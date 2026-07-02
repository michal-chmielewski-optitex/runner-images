################################################################################
##  File:  Enable-TestSigning.ps1
##  Desc:  Enable test signing mode (used by elevated Packer provisioner)
################################################################################

bcdedit.exe /set TESTSIGNING ON
if ($LASTEXITCODE -ne 0) {
    throw "bcdedit /set TESTSIGNING ON failed with exit code $LASTEXITCODE"
}
