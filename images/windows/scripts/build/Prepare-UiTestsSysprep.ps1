################################################################################
##  File:  Prepare-UiTestsSysprep.ps1
##  Desc:  Remove sysprep blockers before generalize (Win11 AppX, D: subst)
################################################################################

. (Get-ImageHelperScriptPath -ScriptName 'UiTests-ProvisionedPackages.ps1')

Write-Host 'Removing UI tests D: subst mapping before sysprep...'
cmd /c 'subst D: /D' 2>$null | Out-Null
mountvol D: /D 2>$null | Out-Null

Write-Host 'Removing consumer AppX packages...'
Remove-UiTestsProvisionedPackages
Remove-UiTestsInstalledPackagesForAllUsers

Write-Host 'Removing AppX packages installed for users but not provisioned for all users...'
$provisionedDisplayNames = @(
    Get-AppxProvisionedPackage -Online |
        Select-Object -ExpandProperty DisplayName -Unique
)

$sysprepBlockerPatterns = @(
    'Microsoft.WidgetsPlatformRuntime'
    'MicrosoftWindows.Client.WebExperience'
    'Microsoft.StartExperiencesApp'
)

Get-AppxPackage -AllUsers | ForEach-Object {
    $package = $_
    $shouldRemove = $false

    if ($package.Name -in $sysprepBlockerPatterns) {
        $shouldRemove = $true
    }
    elseif ($package.Name -notin $provisionedDisplayNames -and -not $package.IsFramework -and -not $package.IsResourcePackage) {
        $shouldRemove = $true
    }

    if ($shouldRemove) {
        Write-Host "Removing AppX package: $($package.PackageFullName)"
        Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction SilentlyContinue | Out-Null
    }
}

Write-Host 'Waiting for servicing tasks to complete...'
$deadline = (Get-Date).AddMinutes(10)
while ((Get-Process TiWorker -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) {
    Write-Host 'TiWorker.exe still running, waiting...'
    Start-Sleep -Seconds 15
}

Write-Host 'Prepare-UiTestsSysprep completed.'
