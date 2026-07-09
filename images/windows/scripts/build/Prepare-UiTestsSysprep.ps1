################################################################################
##  File:  Prepare-UiTestsSysprep.ps1
##  Desc:  Remove sysprep blockers before generalize (Win11 AppX, D: subst)
################################################################################

. (Get-ImageHelperScriptPath -ScriptName 'UiTests-ProvisionedPackages.ps1')
. (Get-ImageHelperScriptPath -ScriptName 'UiTests-StartupExperienceRegistry.ps1')

Stop-UiTestsWelcomeProcesses

Write-Host 'Removing UI tests D: subst mapping before sysprep...'
cmd /c 'subst D: /D' 2>$null | Out-Null
$global:LASTEXITCODE = 0
mountvol D: /D 2>$null | Out-Null
$global:LASTEXITCODE = 0

Write-Host 'Removing consumer and sysprep-blocker AppX packages...'
Invoke-UiTestsSysprepAppxCleanup

Write-Host 'Re-applying startup experience settings after final updates...'
Invoke-UiTestsStartupExperienceConfiguration

. (Get-ImageHelperScriptPath -ScriptName 'UiTests-VisualStudioConfiguration.ps1')
Invoke-UiTestsVisualStudioDefaultUserConfiguration

Write-Host 'Waiting for servicing tasks to complete...'
$deadline = (Get-Date).AddMinutes(10)
while ((Get-Process TiWorker -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) {
    Write-Host 'TiWorker.exe still running, waiting...'
    Start-Sleep -Seconds 15
}

Write-Host 'Prepare-UiTestsSysprep completed.'
exit 0
