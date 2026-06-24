################################################################################
##  File:  Install-NUnit.ps1
##  Desc:  Install NUnit Console Runner for Windows x64 UI test agents
################################################################################

function Get-NUnitConsoleExecutable {
    param(
        [Parameter(Mandatory = $true)]
        [string] $InstallRoot
    )

    $preferredPath = Join-Path $InstallRoot "bin\net462\nunit3-console.exe"
    if (Test-Path $preferredPath) {
        return Get-Item $preferredPath
    }

    $consoleExe = Get-ChildItem -Path $InstallRoot -Filter "nunit3-console.exe" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -match '\\net462$' } |
        Select-Object -First 1

    if (-not $consoleExe) {
        $consoleExe = Get-ChildItem -Path $InstallRoot -Filter "nunit3-console.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1
    }

    return $consoleExe
}

$nunitToolset = (Get-ToolsetContent).nunit
$nunitVersion = $nunitToolset.version
$nunitRoot = "C:\Program Files\NUnit"
$nunitVersionPath = Join-Path $nunitRoot $nunitVersion

$consoleExe = Get-NUnitConsoleExecutable -InstallRoot $nunitVersionPath
if ($consoleExe) {
    Write-Host "NUnit $nunitVersion is already installed at $($consoleExe.FullName)"
}
else {
    $archiveName = "NUnit.Console-$nunitVersion.zip"
    $downloadUrl = "https://github.com/nunit/nunit-console/releases/download/$nunitVersion/$archiveName"

    Write-Host "Downloading NUnit Console $nunitVersion..."
    $archivePath = Invoke-DownloadWithRetry -Url $downloadUrl

    New-Item -Path $nunitVersionPath -ItemType Directory -Force | Out-Null
    Expand-Archive -Path $archivePath -DestinationPath $nunitVersionPath -Force

    $consoleExe = Get-NUnitConsoleExecutable -InstallRoot $nunitVersionPath
    if (-not $consoleExe) {
        throw "nunit3-console.exe not found under $nunitVersionPath after extracting $archiveName"
    }
}

Add-MachinePathItem $consoleExe.DirectoryName

Invoke-PesterTests -TestFile "NUnit"
