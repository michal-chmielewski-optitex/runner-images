################################################################################
##  File:  Disable-UiTestsStartupExperience.ps1 (post-generation)
##  Desc:  Remove consumer apps and suppress welcome UI on interactive agent boot
################################################################################

if (-not (Test-Path 'C:\imagedata.json')) {
    return
}

$imageData = Get-Content 'C:\imagedata.json' -Raw
if ($imageData -notmatch 'windows-11-x64-ui-tests') {
    return
}

$packagesScript = Join-Path $PSScriptRoot 'UiTests-ProvisionedPackages.ps1'
if (Test-Path $packagesScript) {
    . $packagesScript
    Remove-UiTestsInstalledPackagesForAllUsers
}

$cdmPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
if (-not (Test-Path $cdmPath)) {
    New-Item -Path $cdmPath -Force | Out-Null
}

New-ItemProperty -Path $cdmPath -Name SubscribedContent-310093Enabled -PropertyType DWORD -Value 0 -Force | Out-Null

Get-Process -Name 'GetStarted' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process -Name 'OOBE' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
