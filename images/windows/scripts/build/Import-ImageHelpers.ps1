################################################################################
##  File:  Import-ImageHelpers.ps1
##  Desc:  Load ImageHelpers after Packer restarts (new WinRM session)
################################################################################

$ErrorActionPreference = 'Stop'

$moduleRoot = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules\ImageHelpers'
$moduleFile = Join-Path $moduleRoot 'ImageHelpers.psm1'

if (-not (Test-Path $moduleFile)) {
    throw "ImageHelpers module not found: $moduleFile"
}

Import-Module $moduleFile -DisableNameChecking -Force

if (-not (Get-Command Invoke-ImageHelperScript -ErrorAction SilentlyContinue)) {
    . (Join-Path $moduleRoot 'PathHelpers.ps1')
}

if (-not (Get-Command Invoke-ImageHelperScript -ErrorAction SilentlyContinue)) {
    throw 'Invoke-ImageHelperScript is unavailable after importing ImageHelpers.'
}

if ($env:UI_TESTS_INIT_D_DRIVE -eq '1') {
    Invoke-ImageHelperScript -ScriptName 'Initialize-UiTestsDriveLetter.ps1'
}
