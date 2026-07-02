################################################################################
##  File:  UiTests-ProvisionedPackages.ps1
##  Desc:  Shared list of Win11 consumer AppX packages to remove from UI test image
################################################################################

$script:UiTestsProvisionedPackagesToRemove = @(
    'Microsoft.Getstarted'
    'MicrosoftWindows.Client.OOBE'
    'Microsoft.OutlookForWindows'
    'MicrosoftTeams'
    'MSTeams'
    'Microsoft.MicrosoftOfficeHub'
    'Clipchamp.Clipchamp'
    'Microsoft.BingNews'
    'Microsoft.BingWeather'
    'Microsoft.BingFinance'
    'Microsoft.BingSports'
    'Microsoft.GetHelp'
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.Windows.DevHome'
    'Microsoft.PowerAutomateDesktop'
    'Microsoft.Todos'
    'Microsoft.YourPhone'
    'MicrosoftWindows.CrossDevice'
    'Microsoft.ZuneMusic'
    'Microsoft.ZuneVideo'
    'Microsoft.Xbox.TCUI'
    'Microsoft.XboxGameOverlay'
    'Microsoft.XboxGamingOverlay'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.XboxSpeechToTextOverlay'
)

$script:UiTestsSysprepBlockerPackages = @(
    'Microsoft.WidgetsPlatformRuntime'
    'MicrosoftWindows.Client.WebExperience'
    'Microsoft.StartExperiencesApp'
)

function Stop-UiTestsWelcomeProcesses {
    foreach ($processName in @('GetStarted', 'OOBE', 'WebExperienceHost', 'StartExperiencesApp')) {
        Get-Process -Name $processName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

function Remove-UiTestsAppxPackageSafely {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PackageFullName
    )

    Stop-UiTestsWelcomeProcesses

    $packages = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.PackageFullName -eq $PackageFullName })
    if ($packages.Count -eq 0) {
        return
    }

    $removedAny = $false
    foreach ($pkg in $packages) {
        $userInfos = @($pkg.PackageUserInformation | Where-Object { $_ })
        if ($userInfos.Count -gt 0) {
            foreach ($userInfo in $userInfos) {
                $userSid = $userInfo.UserSecurityId.Id
                try {
                    Remove-AppxPackage -Package $PackageFullName -User $userSid -ErrorAction Stop | Out-Null
                    Write-Host "Removed AppX package $PackageFullName for user $userSid"
                    $removedAny = $true
                }
                catch {
                    Write-Warning "Could not remove AppX package ${PackageFullName} for user ${userSid}: $($_.Exception.Message)"
                }
                finally {
                    $global:LASTEXITCODE = 0
                }
            }
            continue
        }

        try {
            Remove-AppxPackage -Package $PackageFullName -AllUsers -ErrorAction Stop | Out-Null
            Write-Host "Removed AppX package: $PackageFullName"
            $removedAny = $true
        }
        catch {
            Write-Warning "Could not remove AppX package ${PackageFullName}: $($_.Exception.Message)"
        }
        finally {
            $global:LASTEXITCODE = 0
        }
    }

    if (-not $removedAny) {
        Write-Warning "AppX package ${PackageFullName} is still registered for one or more users."
    }
}

function Remove-UiTestsProvisionedPackages {
    foreach ($displayName in $script:UiTestsProvisionedPackagesToRemove) {
        Get-AppxProvisionedPackage -Online |
            Where-Object { $_.DisplayName -eq $displayName } |
            ForEach-Object {
                $package = $_
                Write-Host "Removing provisioned package: $($package.DisplayName)"
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction Stop | Out-Null
                }
                catch {
                    Write-Warning "Could not remove provisioned package $($package.DisplayName): $($_.Exception.Message)"
                }
            }
    }
}

function Remove-UiTestsInstalledPackagesForAllUsers {
    Stop-UiTestsWelcomeProcesses

    foreach ($displayName in $script:UiTestsProvisionedPackagesToRemove) {
        Get-AppxPackage -AllUsers -Name $displayName -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "Removing installed package for all users: $($_.Name)"
            Remove-UiTestsAppxPackageSafely -PackageFullName $_.PackageFullName
        }
    }
}

function Remove-UiTestsSysprepBlockerPackages {
    foreach ($displayName in $script:UiTestsSysprepBlockerPackages) {
        Get-AppxPackage -AllUsers -Name $displayName -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "Removing sysprep blocker package: $($_.Name)"
            Remove-UiTestsAppxPackageSafely -PackageFullName $_.PackageFullName
        }
    }
}
