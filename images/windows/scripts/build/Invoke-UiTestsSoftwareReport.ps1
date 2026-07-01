################################################################################
##  File:  Invoke-UiTestsSoftwareReport.ps1
##  Desc:  Generate software report with ImageHelpers and D: drive initialized
################################################################################

$reportScript = Join-Path $env:IMAGE_FOLDER 'SoftwareReport\Generate-SoftwareReport-UiTests.ps1'
if (-not (Test-Path $reportScript)) {
    throw "Software report script not found at $reportScript"
}

& $reportScript
if ($LASTEXITCODE -ne 0) {
    throw "Generate-SoftwareReport-UiTests.ps1 failed with exit code $LASTEXITCODE"
}
