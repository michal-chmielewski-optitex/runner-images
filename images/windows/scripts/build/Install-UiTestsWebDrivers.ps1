################################################################################
##  File:  Install-UiTestsWebDrivers.ps1
##  Desc:  Chrome + chromedriver portable layout for Optitex TestAutomation (D:\WebDriver)
################################################################################

$webDriverRoot = 'D:\WebDriver'
$chromeDir = Join-Path $webDriverRoot 'chrome-win64'
$driverDir = Join-Path $webDriverRoot 'chromedriver-win64'

New-Item -ItemType Directory -Path $webDriverRoot -Force | Out-Null

$versionsUrl = 'https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json'
Write-Host "Resolving Chrome for Testing stable downloads..."
$channel = (Invoke-RestMethod -Uri $versionsUrl).channels.Stable

$chromeUrl = ($channel.downloads.chrome | Where-Object platform -eq 'win64').url
$driverUrl = ($channel.downloads.chromedriver | Where-Object platform -eq 'win64').url
if (-not $chromeUrl -or -not $driverUrl) {
    throw 'Could not resolve win64 chrome/chromedriver URLs from Chrome for Testing feed.'
}

Write-Host "Chrome for Testing version: $($channel.version)"

$chromeZip = Invoke-DownloadWithRetry -Url $chromeUrl
$driverZip = Invoke-DownloadWithRetry -Url $driverUrl

if (Test-Path $chromeDir) { Remove-Item -Path $chromeDir -Recurse -Force }
if (Test-Path $driverDir) { Remove-Item -Path $driverDir -Recurse -Force }

Expand-Archive -Path $chromeZip -DestinationPath $webDriverRoot -Force
Expand-Archive -Path $driverZip -DestinationPath $webDriverRoot -Force

$chromeExe = Join-Path $chromeDir 'chrome.exe'
$driverExe = Join-Path $driverDir 'chromedriver.exe'
if (-not (Test-Path $chromeExe)) { throw "chrome.exe not found at $chromeExe" }
if (-not (Test-Path $driverExe)) { throw "chromedriver.exe not found at $driverExe" }

$channel.version | Out-File -FilePath (Join-Path $driverDir 'versioninfo.txt') -Encoding ascii -Force

[Environment]::SetEnvironmentVariable('ChromeWebDriver', $driverDir, 'Machine')
[Environment]::SetEnvironmentVariable('UITESTS_CHROME_PATH', $chromeExe, 'Machine')
Add-MachinePathItem $driverDir
Add-MachinePathItem $chromeDir
Update-Environment

. "$PSScriptRoot\Configure-UiTests-ChromePolicy.ps1"

Invoke-PesterTests -TestFile 'UiTestsWebDrivers'
