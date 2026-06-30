################################################################################
##  File:  Disable-UiTestsStartupExperience.ps1 (post-generation)
##  Desc:  Remove Get Started for the interactive agent session on first boot
################################################################################

if (-not (Test-Path 'C:\imagedata.json')) {
    return
}

$imageData = Get-Content 'C:\imagedata.json' -Raw
if ($imageData -notmatch 'windows-11-x64-ui-tests') {
    return
}

$packagesToRemove = @(
    'Microsoft.Getstarted'
    'MicrosoftWindows.Client.OOBE'
)

foreach ($displayName in $packagesToRemove) {
    Get-AppxPackage -AllUsers -Name $displayName -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "Removing installed package for current users: $($_.Name)"
        Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue | Out-Null
    }
}

$cdmPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
if (-not (Test-Path $cdmPath)) {
    New-Item -Path $cdmPath -Force | Out-Null
}

New-ItemProperty -Path $cdmPath -Name SubscribedContent-310093Enabled -PropertyType DWORD -Value 0 -Force | Out-Null

Get-Process -Name 'GetStarted' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process -Name 'OOBE' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
