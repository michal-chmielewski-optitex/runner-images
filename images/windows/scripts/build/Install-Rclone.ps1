################################################################################
##  File:  Install-Rclone.ps1
##  Desc:  Install rclone for UI test report uploads (Cloudflare R2)
################################################################################

Install-ChocoPackage -PackageName 'rclone'
Update-Environment

Invoke-PesterTests -TestFile 'Rclone'
