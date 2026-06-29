################################################################################
##  File:  Initialize-UiTestsDriveLetter.ps1
##  Desc:  Map D: to C:\UiTestMount (Win11 client images have no D: volume)
################################################################################

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
