################################################################################
##  File:  Install-AltTesterDesktop.ps1
##  Desc:  Install AltTester Desktop server (AltDriver websocket on port 13000)
################################################################################

$installDir = 'C:\AltTester'
$version = '2.3.2'
$downloadUrl = "https://alttester.com/app/uploads/AltTester/desktop/AltTesterDesktop__v$version.exe"
$exePath = Join-Path $installDir 'AltTesterDesktop.exe'

New-Item -ItemType Directory -Path $installDir -Force | Out-Null

if (-not (Test-Path $exePath)) {
    Write-Host "Downloading AltTester Desktop $version..."
    $downloaded = Invoke-DownloadWithRetry -Url $downloadUrl
    Copy-Item -Path $downloaded -Destination $exePath -Force
}

if (-not (Test-Path $exePath)) {
    throw "AltTester Desktop not found at $exePath"
}

Add-MachinePathItem $installDir
[Environment]::SetEnvironmentVariable('ALTTTESTER_DESKTOP_PATH', $exePath, 'Machine')
Update-Environment

Write-Host "AltTester Desktop installed at $exePath"
Write-Host "Start server before tests: AltTesterDesktop.exe -batchmode -port 13000 -nographics -license <KEY> -termsAndConditionsAccepted"

Invoke-PesterTests -TestFile 'AltTesterDesktop'
