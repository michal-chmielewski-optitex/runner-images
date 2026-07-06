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

function Initialize-UiTestsShellInputHelpers {
    if ([System.Management.Automation.PSTypeName]'UiTestsShellInput'.Type) {
        return
    }

    Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class UiTestsShellInput {
    public const byte VkEscape = 0x1B;
    public const byte VkLWin = 0x5B;
    public const uint KeyeventfKeyup = 0x0002;

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
}
"@
}

function Write-UiTestsWatchdogLog {
    param([string]$Message)

    $logPath = Join-Path $env:TEMP 'UiTestsStartupWatchdog.log'
    $line = '{0:u} {1}' -f (Get-Date), $Message
    Add-Content -Path $logPath -Value $line -ErrorAction SilentlyContinue
}

function Test-UiTestsStartMenuOpen {
    Initialize-UiTestsShellInputHelpers

    $hwnd = [UiTestsShellInput]::GetForegroundWindow()
    if ($hwnd -eq [IntPtr]::Zero) {
        return $false
    }

    $processId = [uint32]0
    [void][UiTestsShellInput]::GetWindowThreadProcessId($hwnd, [ref]$processId)
    if ($processId -eq 0) {
        return $false
    }

    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        return $false
    }

    if ($process.ProcessName -in @('StartMenuExperienceHost', 'SearchHost')) {
        return $true
    }

    $className = New-Object System.Text.StringBuilder 256
    [void][UiTestsShellInput]::GetClassName($hwnd, $className, $className.Capacity)
    if ($className.ToString() -match 'Windows\.UI\.Core\.CoreWindow' -and
        $process.ProcessName -in @('ShellExperienceHost', 'StartMenuExperienceHost', 'SearchHost')) {
        return $true
    }

    return $false
}

function Send-UiTestsKeyPress {
    param(
        [Parameter(Mandatory = $true)]
        [byte] $VirtualKey
    )

    Initialize-UiTestsShellInputHelpers
    [UiTestsShellInput]::keybd_event($VirtualKey, 0, 0, [UIntPtr]::Zero)
    [UiTestsShellInput]::keybd_event($VirtualKey, 0, [UiTestsShellInput]::KeyeventfKeyup, [UIntPtr]::Zero)
}

function Dismiss-UiTestsStartMenu {
    if (-not (Test-UiTestsStartMenuOpen)) {
        return $false
    }

    Send-UiTestsKeyPress -VirtualKey ([UiTestsShellInput]::VkEscape)
    Start-Sleep -Milliseconds 200

    if (Test-UiTestsStartMenuOpen) {
        Send-UiTestsKeyPress -VirtualKey ([UiTestsShellInput]::VkLWin)
        Start-Sleep -Milliseconds 200
    }

    $dismissed = -not (Test-UiTestsStartMenuOpen)
    if ($dismissed) {
        Write-UiTestsWatchdogLog 'Dismissed open Start menu (Escape/Win).'
    }
    else {
        Write-UiTestsWatchdogLog 'Start menu still open after Escape/Win.'
    }

    return $dismissed
}

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
    $actions = [System.Collections.Generic.List[string]]::new()

    if (Dismiss-UiTestsStartMenu) {
        $actions.Add('dismissed-start-menu')
    }

    $welcomeProcesses = @(
        'GetStarted'
        'OOBE'
        'WebExperienceHost'
        'StartExperiencesApp'
        'Widgets'
    )
    $runningWelcome = @($welcomeProcesses | Where-Object {
        $null -ne (Get-Process -Name $_ -ErrorAction SilentlyContinue)
    })

    Stop-UiTestsWelcomeProcesses
    Stop-UiTestsStoreInstallServices

    $removedPackages = [System.Collections.Generic.List[string]]::new()
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
                $removedPackages.Add($pkg.Name)
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

    if ($runningWelcome.Count -gt 0 -or $removedPackages.Count -gt 0 -or $actions.Count -gt 0) {
        $details = @()
        if ($actions.Count -gt 0) {
            $details += "actions=$($actions -join ',')"
        }
        if ($runningWelcome.Count -gt 0) {
            $details += "stopped=$($runningWelcome -join ',')"
        }
        if ($removedPackages.Count -gt 0) {
            $details += "removed=$($removedPackages -join ',')"
        }
        Write-UiTestsWatchdogLog ($details -join '; ')
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
