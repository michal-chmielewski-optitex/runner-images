################################################################################
##  File:  Prepare-UiTestsSysprep.ps1
##  Desc:  Remove sysprep blockers before generalize (Win11 AppX, D: subst)
################################################################################

. (Get-ImageHelperScriptPath -ScriptName 'UiTests-ProvisionedPackages.ps1')

Write-Host 'Removing UI tests D: subst mapping before sysprep...'
cmd /c 'subst D: /D' 2>$null | Out-Null
mountvol D: /D 2>$null | Out-Null

Write-Host 'Removing consumer and sysprep-blocker AppX packages...'
Remove-UiTestsProvisionedPackages
Remove-UiTestsInstalledPackagesForAllUsers
Remove-UiTestsSysprepBlockerPackages

Write-Host 'Waiting for servicing tasks to complete...'
$deadline = (Get-Date).AddMinutes(10)
while ((Get-Process TiWorker -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) {
    Write-Host 'TiWorker.exe still running, waiting...'
    Start-Sleep -Seconds 15
}

Write-Host 'Prepare-UiTestsSysprep completed.'
