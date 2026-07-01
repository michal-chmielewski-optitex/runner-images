################################################################################
##  File:  Invoke-UiTestsSoftwareReport.ps1
##  Desc:  Generate software report with ImageHelpers and D: drive initialized
################################################################################

$ErrorActionPreference = 'Stop'

$reportScript = Join-Path $env:IMAGE_FOLDER 'SoftwareReport\Generate-SoftwareReport-UiTests.ps1'
if (-not (Test-Path $reportScript)) {
    throw "Software report script not found at $reportScript"
}

$reportDir = Split-Path $reportScript -Parent
$modulePath = Join-Path $reportDir 'software-report-base\SoftwareReport.psm1'
if (-not (Test-Path $modulePath)) {
    throw "Software report base module not found at $modulePath"
}

# `using module ./software-report-base/...` resolves from the current directory when
# the report script is invoked with `&`, not from the script file location.
Push-Location $reportDir
try {
    & $reportScript
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Generate-SoftwareReport-UiTests.ps1 failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}
