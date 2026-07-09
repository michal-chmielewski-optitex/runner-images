################################################################################
##  File:  UiTests-VisualStudioConfiguration.ps1
##  Desc:  Suppress Visual Studio first-launch sign-in for UI test agents
################################################################################

function Get-UiTestsVisualStudioRegistryInstanceKeys {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RootPath
    )

    if (-not (Test-Path $RootPath)) {
        return @()
    }

    @(Get-ChildItem -Path $RootPath -ErrorAction SilentlyContinue |
        Where-Object { $_.PSIsContainer -and $_.PSChildName -match '^17\.0_' })
}

function Get-UiTestsVisualStudioInstanceSuffixesFromRegistry {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RootKey
    )

    $vsRoot = "$RootKey\Software\Microsoft\VisualStudio"
    @(Get-UiTestsVisualStudioRegistryInstanceKeys -RootPath $vsRoot |
        ForEach-Object { $_.PSChildName.Substring('17.0_'.Length) })
}

function Add-UiTestsVisualStudioInstanceId {
    param(
        [System.Collections.Generic.HashSet[string]] $Ids,
        [string] $InstanceId
    )

    if ([string]::IsNullOrWhiteSpace($InstanceId)) {
        return
    }

    $normalized = ($InstanceId -replace '^17\.0_', '').Trim()
    if (-not [string]::IsNullOrWhiteSpace($normalized)) {
        [void]$Ids.Add($normalized)
    }
}

function Get-UiTestsVisualStudioInstanceIds {
    $ids = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    $instancesRoot = 'C:\ProgramData\Microsoft\VisualStudio\Packages\_Instances'
    if (Test-Path $instancesRoot) {
        Get-ChildItem -Path $instancesRoot -ErrorAction SilentlyContinue |
            Where-Object { $_.PSIsContainer } |
            ForEach-Object {
                $instanceId = $null
                foreach ($fileName in @('state.json', 'catalog.json')) {
                    $jsonPath = Join-Path $_.FullName $fileName
                    if (-not (Test-Path $jsonPath)) {
                        continue
                    }

                    try {
                        $json = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
                        foreach ($propertyName in @('instanceId', 'installationInstanceId')) {
                            if ($json.$propertyName) {
                                $instanceId = [string]$json.$propertyName
                                break
                            }
                        }
                    }
                    catch {
                        Write-Verbose "Could not read Visual Studio $fileName from $($_.FullName): $($_.Exception.Message)"
                    }

                    if ($instanceId) {
                        break
                    }
                }

                if ([string]::IsNullOrWhiteSpace($instanceId)) {
                    $instanceId = $_.Name
                }

                Add-UiTestsVisualStudioInstanceId -Ids $ids -InstanceId $instanceId
            }
    }

    try {
        Import-Module VSSetup -ErrorAction Stop
        Get-VSSetupInstance -Prerelease -All -ErrorAction SilentlyContinue | ForEach-Object {
            Add-UiTestsVisualStudioInstanceId -Ids $ids -InstanceId $_.InstanceId
        }
    }
    catch {
        Write-Verbose "Could not enumerate Visual Studio instances via VSSetup: $($_.Exception.Message)"
    }

    foreach ($rootKey in @('HKCU:', 'HKLM:\DEFAULT')) {
        foreach ($suffix in @(Get-UiTestsVisualStudioInstanceSuffixesFromRegistry -RootKey $rootKey)) {
            Add-UiTestsVisualStudioInstanceId -Ids $ids -InstanceId $suffix
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
        Get-UiTestsVisualStudioRegistryInstanceKeys -RootPath $vsRoot |
            ForEach-Object {
                $generalPath = "$RootKey\Software\Microsoft\VisualStudio\$($_.PSChildName)\General"
                Set-RegistryKeyDword -KeyPath $generalPath -Name DisableSignIn -Value 1 -UseRegExe:$useRegExe
                Set-RegistryKeyDword -KeyPath $generalPath -Name EnvironmentOptIn -Value 0 -UseRegExe:$useRegExe
            }
    }
}

function Invoke-UiTestsVisualStudioWarmup {
    param(
        [switch] $InteractiveFirstLaunch
    )

    $vsInstallRoot = (Get-VisualStudioInstance).InstallationPath
    $devEnvPath = Join-Path $vsInstallRoot 'Common7\IDE\devenv.exe'

    Set-UiTestsVisualStudioSignInDisabled -RootKey 'HKCU:'

    if ($InteractiveFirstLaunch) {
        Write-Host "Interactive Visual Studio first launch warmup: $devEnvPath"
        & $devEnvPath /Command File.Exit | Out-Null
    }
    else {
        # Headless Packer/WinRM cannot dismiss modal VS first-launch UI; registry + updateconfiguration only.
        Write-Host "Non-interactive Visual Studio warmup (updateconfiguration only): $devEnvPath"
    }

    cmd.exe /c "`"$devEnvPath`" /updateconfiguration"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to warmup 'devenv.exe /updateconfiguration' for UI tests"
    }

    Set-UiTestsVisualStudioSignInDisabled -RootKey 'HKCU:'
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
