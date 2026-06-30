################################################################################
##  File:  Initialize-UiTestsDriveLetter.ps1 (post-generation)
##  Desc:  Recreate D: mapping on MDP agent first boot (subst does not survive sysprep)
################################################################################

if (-not (Test-Path 'C:\imagedata.json')) {
    return
}

$imageData = Get-Content 'C:\imagedata.json' -Raw
if ($imageData -notmatch 'windows-11-x64-ui-tests') {
    return
}

$coreScript = Join-Path $PSScriptRoot 'UiTests-DriveLetterMapping.ps1'
if (-not (Test-Path $coreScript)) {
    throw "UI tests drive-letter script not found at $coreScript"
}

& $coreScript
