################################################################################
##  File:  Install-NUnit.ps1
##  Desc:  Install NUnit Console Runner for Windows x64 UI test agents
################################################################################

$nunitToolset = (Get-ToolsetContent).nunit
$nunitVersion = $nunitToolset.version
$nunitRoot = "C:\Program Files\NUnit"
$nunitVersionPath = Join-Path $nunitRoot $nunitVersion

if (Test-Path $nunitVersionPath) {
    Write-Host "NUnit $nunitVersion is already installed at $nunitVersionPath"
}
else {
    $archiveName = "NUnit.Console-$nunitVersion.zip"
    $downloadUrl = "https://github.com/nunit/nunit-console/releases/download/$nunitVersion/$archiveName"

    Write-Host "Downloading NUnit Console $nunitVersion..."
    $archivePath = Invoke-DownloadWithRetry -Url $downloadUrl

    New-Item -Path $nunitVersionPath -ItemType Directory -Force | Out-Null
    Expand-Archive -Path $archivePath -DestinationPath $nunitVersionPath -Force
}

Add-MachinePathItem $nunitVersionPath

Invoke-PesterTests -TestFile "NUnit"
