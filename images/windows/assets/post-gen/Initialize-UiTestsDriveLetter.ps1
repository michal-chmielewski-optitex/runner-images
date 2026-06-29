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

$mountRoot = 'C:\UiTestMount'
if (-not (Test-Path $mountRoot)) {
    New-Item -Path $mountRoot -ItemType Directory -Force | Out-Null
}

if (-not (Get-PSDrive -Name D -ErrorAction SilentlyContinue)) {
    cmd /c "subst D: $mountRoot"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to map D: to $mountRoot"
    }
}

foreach ($subDir in @('temp', 'WebDriver')) {
    $path = Join-Path $mountRoot $subDir
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}
