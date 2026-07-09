################################################################################
##  File:  UiTests-VisualStudioConfiguration.ps1
##  Desc:  Suppress Visual Studio first-launch sign-in for UI test agents
################################################################################

function Get-UiTestsVisualStudioInstanceIds {
    $ids = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    $instancesRoot = 'C:\ProgramData\Microsoft\VisualStudio\Packages\_Instances'
    if (Test-Path $instancesRoot) {
        Get-ChildItem -Path $instancesRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $statePath = Join-Path $_.FullName 'state.json'
            if (-not (Test-Path $statePath)) {
                return
            }

            try {
                $state = Get-Content -Path $statePath -Raw | ConvertFrom-Json
                if ($state.instanceId) {
                    [void]$ids.Add([string]$state.instanceId)
                }
            }
            catch {
                Write-Verbose "Could not read Visual Studio state.json from $($_.FullName): $($_.Exception.Message)"
            }
        }
    }

    foreach ($rootKey in @('HKCU:\Software\Microsoft\VisualStudio', 'HKLM:\DEFAULT\Software\Microsoft\VisualStudio')) {
        if (-not (Test-Path $rootKey)) {
            continue
        }

        Get-ChildItem -Path $rootKey -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^17\.0_' } |
            ForEach-Object {
                $suffix = $_.Name.Substring('17.0_'.Length)
                if (-not [string]::IsNullOrWhiteSpace($suffix)) {
                    [void]$ids.Add($suffix)
                }
            }
    }

    @($ids)
}

function Set-UiTestsVisualStudioSignInDisabled {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RootKey
    )

    $useRegExe = $RootKey -eq 'HKLM:\DEFAULT'
    $instanceIds = Get-UiTestsVisualStudioInstanceIds

    foreach ($instanceId in $instanceIds) {
        $generalPath = "$RootKey\Software\Microsoft\VisualStudio\17.0_$instanceId\General"
        Set-RegistryKeyDword -KeyPath $generalPath -Name DisableSignIn -Value 1 -UseRegExe:$useRegExe
        Set-RegistryKeyDword -KeyPath $generalPath -Name EnvironmentOptIn -Value 0 -UseRegExe:$useRegExe
    }

    $vsRoot = "$RootKey\Software\Microsoft\VisualStudio"
    if (Test-Path $vsRoot) {
        Get-ChildItem -Path $vsRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^17\.0_' } |
            ForEach-Object {
                $generalPath = Join-Path $_.FullName 'General'
                Set-RegistryKeyDword -KeyPath $generalPath -Name DisableSignIn -Value 1 -UseRegExe:$useRegExe
                Set-RegistryKeyDword -KeyPath $generalPath -Name EnvironmentOptIn -Value 0 -UseRegExe:$useRegExe
            }
    }
}

function Invoke-UiTestsVisualStudioWarmup {
    $vsInstallRoot = (Get-VisualStudioInstance).InstallationPath
    $devEnvPath = Join-Path $vsInstallRoot 'Common7\IDE\devenv.exe'

    Set-UiTestsVisualStudioSignInDisabled -RootKey 'HKCU:'

    Write-Host "Warmup Visual Studio first launch for UI tests: $devEnvPath"
    & $devEnvPath /Command File.Exit | Out-Null

    cmd.exe /c "`"$devEnvPath`" /updateconfiguration"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to warmup 'devenv.exe /updateconfiguration' for UI tests"
    }
}

function Invoke-UiTestsVisualStudioDefaultUserConfiguration {
    Mount-RegistryHive `
        -FileName 'C:\Users\Default\NTUSER.DAT' `
        -SubKey 'HKLM\DEFAULT'

    try {
        Set-UiTestsVisualStudioSignInDisabled -RootKey 'HKLM:\DEFAULT'
    }
    finally {
        Dismount-RegistryHive 'HKLM\DEFAULT'
    }
}
