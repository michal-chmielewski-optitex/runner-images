################################################################################
##  File:  Invoke-UiTestsSoftwareReport.ps1
##  Desc:  Generate software report via PowerShell 7 (software-report-base requires PS7+)
################################################################################

$ErrorActionPreference = 'Stop'

$reportScript = Join-Path $env:IMAGE_FOLDER 'SoftwareReport\Generate-SoftwareReport-UiTests.ps1'
if (-not (Test-Path $reportScript)) {
    throw "Software report script not found at $reportScript"
}

& pwsh -NoProfile -File $reportScript
if ($LASTEXITCODE -ne 0) {
    throw "Generate-SoftwareReport-UiTests.ps1 failed with exit code $LASTEXITCODE"
}
