################################################################################
##  File:  Initialize-UiTestsDriveLetter.ps1
##  Desc:  Map D: to C:\UiTestMount (Win11 Azure images reserve D: for CD-ROM)
################################################################################

function Remove-UiTestsDriveLetterD {
    cmd /c 'subst D: /D' 2>$null | Out-Null
    mountvol D: /D 2>$null | Out-Null

    $partition = Get-Partition -DriveLetter D -ErrorAction SilentlyContinue
    if ($partition) {
        Remove-PartitionAccessPath -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath 'D:\' -ErrorAction SilentlyContinue | Out-Null
    }
}

function Test-UiTestsDDriveWritable {
    if (-not (Test-Path 'D:\')) {
        return $false
    }

    try {
        $probeDir = 'D:\temp'
        if (-not (Test-Path $probeDir)) {
            New-Item -ItemType Directory -Path $probeDir -Force | Out-Null
        }

        $probe = Join-Path $probeDir '.ui-tests-drive-probe'
        Set-Content -Path $probe -Value 'ok' -Force -ErrorAction Stop
        Remove-Item -Path $probe -Force -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

$mountRoot = 'C:\UiTestMount'
if (-not (Test-Path $mountRoot)) {
    New-Item -Path $mountRoot -ItemType Directory -Force | Out-Null
}

if (-not (Test-UiTestsDDriveWritable)) {
    Remove-UiTestsDriveLetterD
    cmd /c "subst D: $mountRoot"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to map D: to $mountRoot"
    }

    if (-not (Test-UiTestsDDriveWritable)) {
        throw "D: is not writable after mapping to $mountRoot"
    }
}

foreach ($subDir in @('temp', 'WebDriver')) {
    $path = Join-Path $mountRoot $subDir
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}
