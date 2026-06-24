################################################################################
##  File:  Install-VisualStudio-UiTests.ps1
##  Desc:  Install Visual Studio 2022 with baremetal-matched .NET desktop workload
################################################################################
$vsToolset = (Get-ToolsetContent).visualStudio

$env:VS_INSTALL_EXACT_COMPONENTS = 'true'

Install-VisualStudio `
    -Version $vsToolset.subversion `
    -Edition $vsToolset.edition `
    -Channel $vsToolset.channel `
    -InstallChannelUri $vsToolset.installChannelUri `
    -RequiredComponents $vsToolset.workloads `
    -ExtraArgs "--remove Component.CPython3.x64" `
    -Architecture x64

$vsProgramData = Get-Item -Path "C:\ProgramData\Microsoft\VisualStudio\Packages\_Instances"
$instanceFolders = Get-ChildItem -Path $vsProgramData.FullName

if ($instanceFolders -is [array]) {
    throw "More than one Visual Studio instance installed"
}

$vsInstallRoot = (Get-VisualStudioInstance).InstallationPath
$newContent = '{"Extensions":[{"Key":"1e906ff5-9da8-4091-a299-5c253c55fdc9","Value":{"ShouldAutoUpdate":false}},{"Key":"Microsoft.VisualStudio.Web.AzureFunctions","Value":{"ShouldAutoUpdate":false}}],"ShouldAutoUpdate":false,"ShouldCheckForUpdates":false}'
Set-Content -Path "$vsInstallRoot\Common7\IDE\Extensions\MachineState.json" -Value $newContent

Install-Binary -Type EXE `
    -Url 'https://go.microsoft.com/fwlink/?linkid=2349110' `
    -InstallArgs @("/q", "/norestart", "/ceip off", "/features OptionId.UWPManaged OptionId.UWPCPP OptionId.UWPLocalized OptionId.DesktopCPPx86 OptionId.DesktopCPPx64") `
    -ExpectedSubject $(Get-MicrosoftPublisher)

Invoke-PesterTests -TestFile "VisualStudio"
