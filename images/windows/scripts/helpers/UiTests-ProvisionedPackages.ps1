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
    'MicrosoftWindows.Client.OOBE'
    'Microsoft.StartExperiencesApp'
)

function Stop-UiTestsWelcomeProcesses {
    foreach ($processName in @(
            'GetStarted'
            'OOBE'
            'WebExperienceHost'
            'StartExperiencesApp'
            'Widgets'
        )) {
        Get-Process -Name $processName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.MainWindowTitle -match '^(Get Started|Welcome to Windows)\b'
    } | Stop-Process -Force -ErrorAction SilentlyContinue
}

function Invoke-UiTestsWelcomeWatchdog {
    Stop-UiTestsWelcomeProcesses
    Stop-UiTestsStoreInstallServices

    foreach ($displayName in @(
            'Microsoft.Getstarted'
            'MicrosoftWindows.Client.OOBE'
            'Microsoft.StartExperiencesApp'
            'MicrosoftWindows.Client.WebExperience'
        )) {
        Get-AppxPackage -Name $displayName -ErrorAction SilentlyContinue | ForEach-Object {
            $pkg = $_
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Verbose "Could not remove $($pkg.PackageFullName): $($_.Exception.Message)"
            }
            finally {
                $global:LASTEXITCODE = 0
            }
        }
    }

    Stop-UiTestsWelcomeProcesses
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

function Get-UiTestsProvisionedAppxDisplayNames {
    @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DisplayName)
}

function Get-UiTestsNonProvisionedInstalledAppx {
    $provisioned = Get-UiTestsProvisionedAppxDisplayNames
    $testPackage = {
        param($pkg)
        $pkg.DisplayName -and
        ($pkg.DisplayName -notin $provisioned) -and
        -not $pkg.IsFramework -and
        -not $pkg.IsResourcePackage
    }

    $seen = @{}
    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($pkg in @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { & $testPackage $_ })) {
        if (-not $seen.ContainsKey($pkg.PackageFullName)) {
            $seen[$pkg.PackageFullName] = $true
            [void]$results.Add($pkg)
        }
    }

    $profileSids = @(Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue |
        Where-Object { -not $_.Special -and $_.SID } |
        Select-Object -ExpandProperty SID -Unique)

    foreach ($sid in $profileSids) {
        foreach ($pkg in @(Get-AppxPackage -User $sid -ErrorAction SilentlyContinue | Where-Object { & $testPackage $_ })) {
            if (-not $seen.ContainsKey($pkg.PackageFullName)) {
                $seen[$pkg.PackageFullName] = $true
                [void]$results.Add($pkg)
            }
        }
    }

    foreach ($pkg in @(Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { & $testPackage $_ })) {
        if (-not $seen.ContainsKey($pkg.PackageFullName)) {
            $seen[$pkg.PackageFullName] = $true
            [void]$results.Add($pkg)
        }
    }

    @($results)
}

function Remove-UiTestsNonProvisionedInstalledAppx {
    $packages = Get-UiTestsNonProvisionedInstalledAppx
    foreach ($pkg in $packages) {
        Write-Host "Removing non-provisioned package: $($pkg.Name) [$($pkg.PackageFullName)]"
        Remove-UiTestsAppxPackageSafely -PackageFullName $pkg.PackageFullName
    }

    $provisioned = Get-UiTestsProvisionedAppxDisplayNames
    $profileSids = @(Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue |
        Where-Object { -not $_.Special -and $_.SID } |
        Select-Object -ExpandProperty SID -Unique)

    foreach ($sid in $profileSids) {
        Get-AppxPackage -User $sid -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -notin $provisioned -and -not $_.IsFramework -and -not $_.IsResourcePackage
        } | ForEach-Object {
            try {
                Remove-AppxPackage -Package $_.PackageFullName -User $sid -ErrorAction Stop | Out-Null
                Write-Host "Removed $($_.Name) for profile SID $sid"
            }
            catch {
                Write-Warning "Could not remove $($_.PackageFullName) for SID ${sid}: $($_.Exception.Message)"
            }
            finally {
                $global:LASTEXITCODE = 0
            }
        }
    }

    Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -notin $provisioned -and -not $_.IsFramework -and -not $_.IsResourcePackage
    } | ForEach-Object {
        try {
            Remove-AppxPackage -Package $_.PackageFullName -ErrorAction Stop | Out-Null
            Write-Host "Removed $($_.Name) for current WinRM user"
        }
        catch {
            Write-Warning "Could not remove $($_.PackageFullName) for current user: $($_.Exception.Message)"
        }
        finally {
            $global:LASTEXITCODE = 0
        }
    }
}

function Remove-UiTestsUnloadedBuildUserProfiles {
    param(
        [string[]] $UserNames
    )

    foreach ($userName in $UserNames) {
        if ([string]::IsNullOrWhiteSpace($userName)) {
            continue
        }

        $profiles = @(Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object {
            $_.LocalPath -like "*\$userName" -and -not $_.Special
        })

        foreach ($profile in $profiles) {
            if ($profile.Loaded) {
                Write-Warning "Skipping loaded profile $($profile.LocalPath); AppX must be removed in-place."
                continue
            }

            Write-Host "Removing unloaded profile: $($profile.LocalPath)"
            $profile | Remove-CimInstance -ErrorAction Stop
        }
    }
}

function Assert-UiTestsSysprepAppxState {
    $remaining = Get-UiTestsNonProvisionedInstalledAppx
    if ($remaining.Count -eq 0) {
        Write-Host 'AppX sysprep check: no installed non-provisioned packages remain.'
        return
    }

    $details = ($remaining | ForEach-Object { "  $($_.Name) [$($_.PackageFullName)]" }) -join [Environment]::NewLine
    throw @"
Installed AppX packages are not provisioned (sysprep 0x80073cf2):
$details
"@
}

function Write-UiTestsRemainingAppxAudit {
    $remaining = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -in ($script:UiTestsProvisionedPackagesToRemove + $script:UiTestsSysprepBlockerPackages)
        })

    if ($remaining.Count -eq 0) {
        Write-Host 'AppX audit: no known sysprep-blocker packages remain installed.'
        return
    }

    Write-Warning 'AppX audit: the following packages are still installed and may block sysprep:'
    $remaining | ForEach-Object {
        Write-Warning "  $($_.Name) [$($_.PackageFullName)]"
    }
}

function Invoke-UiTestsSysprepAppxCleanup {
    Stop-UiTestsWelcomeProcesses
    Remove-UiTestsProvisionedPackages
    Remove-UiTestsInstalledPackagesForAllUsers
    Remove-UiTestsSysprepBlockerPackages
    Remove-UiTestsNonProvisionedInstalledAppx

    $buildUsers = @($env:INSTALL_USER, 'packer') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
    Remove-UiTestsUnloadedBuildUserProfiles -UserNames $buildUsers

    Remove-UiTestsNonProvisionedInstalledAppx
    Assert-UiTestsSysprepAppxState
}
