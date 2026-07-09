function Add-MachinePathEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Directory
    )

    if (-not (Test-Path $Directory)) {
        return
    }

    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $segments = @($machinePath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($segments -contains $Directory) {
        return
    }

    [Environment]::SetEnvironmentVariable('Path', "$Directory;$machinePath", 'Machine')
    $env:Path = "$Directory;$env:Path"
}

function Test-ChocoPackageInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PackageName
    )

    return [bool](choco list --localonly $PackageName --exact --all --limitoutput)
}

function Install-ChocoPackageOfflineFallback {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PackageName
    )

    Write-Warning "Chocolatey feed unavailable; installing $PackageName from an alternate source."

    switch ($PackageName) {
        '7zip.install' {
            $sevenZipDir = Join-Path $env:ProgramFiles '7-Zip'
            if (-not (Test-Path (Join-Path $sevenZipDir '7z.exe'))) {
                Install-Binary -Url 'https://7-zip.org/a/7z2409-x64.exe' -Type EXE -InstallArgs @('/S')
            }

            Add-MachinePathEntry -Directory $sevenZipDir
            return (Test-Path (Join-Path $sevenZipDir '7z.exe'))
        }
        'NuGet.CommandLine' {
            $toolsDir = 'C:\Tools\NuGet'
            $nugetExe = Join-Path $toolsDir 'nuget.exe'
            if (-not (Test-Path $nugetExe)) {
                New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
                Invoke-DownloadWithRetry -Url 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -Path $nugetExe
            }

            Add-MachinePathEntry -Directory $toolsDir
            return (Test-Path $nugetExe)
        }
        'vswhere' {
            foreach ($candidate in @(
                    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer')
                    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\Installer')
                )) {
                if (Test-Path (Join-Path $candidate 'vswhere.exe')) {
                    Add-MachinePathEntry -Directory $candidate
                    return $true
                }
            }

            return $false
        }
        'PSWindowsUpdate' {
            if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
                return $true
            }

            Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers -Repository PSGallery -AllowClobber
            return [bool](Get-Module -ListAvailable -Name PSWindowsUpdate)
        }
        default {
            return $false
        }
    }
}

function Install-ChocoPackage {
    <#
    .SYNOPSIS
        A function to install a Chocolatey package with retries.

    .DESCRIPTION
        This function attempts to install a specified Chocolatey package. If the 
        installation fails, it retries a specified number of times.

    .PARAMETER PackageName
        The name of the Chocolatey package to install.

    .PARAMETER ArgumentList
        An array of arguments to pass to the choco install command.

    .PARAMETER RetryCount
        The number of times to retry the installation if it fails. Default is 5.

    .PARAMETER Version
        The version of the package to install.

    .EXAMPLE
        Install-ChocoPackage -PackageName "git" -Version "2.39.2" -RetryCount 3
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $PackageName,
        [string[]] $ArgumentList,
        [string] $Version,
        [int] $RetryCount = 8
    )

    process {
        $count = 1
        while ($true) {
            Write-Host "Running [#$count]: choco install $packageName -y $argumentList"
            if ($Version) {
                choco install $packageName --version $Version -y @ArgumentList --no-progress --require-checksums
            } else {
                choco install $packageName -y @ArgumentList --no-progress --require-checksums
            }
            if (Test-ChocoPackageInstalled -PackageName $packageName) {
                $pkg = choco list --localonly $packageName --exact --all --limitoutput
                Write-Host "Package installed: $pkg"
                break
            }

            if ($count -ge $retryCount) {
                if ($env:IMAGE_UI_TESTS_BUILD -eq 'true' -and (Install-ChocoPackageOfflineFallback -PackageName $packageName)) {
                    Write-Host "Installed $packageName via offline fallback."
                    break
                }

                throw "Could not install $packageName after $count Chocolatey attempts."
            }

            $sleepSeconds = [Math]::Min(60 * $count, 180)
            Write-Host "Chocolatey install for $packageName failed; retrying in ${sleepSeconds}s..."
            Start-Sleep -Seconds $sleepSeconds
            $count++
        }
    }
}

function Resolve-ChocoPackageVersion {
    <#
    .SYNOPSIS
        Resolves the latest version of a Chocolatey package.

    .DESCRIPTION
        This function takes a package name and a target version as input and returns the latest
        version of the package that is greater than or equal to the target version.

    .PARAMETER PackageName
        The name of the Chocolatey package.

    .PARAMETER TargetVersion
        The target version of the package.

    .EXAMPLE
        Resolve-ChocoPackageVersion -PackageName "example-package" -TargetVersion "1.0.0"
        Returns the latest version of the "example-package" that is greater than or equal to "1.0.0".
    #>

    param(
        [Parameter(Mandatory)]
        [string] $PackageName,
        [Parameter(Mandatory)]
        [string] $TargetVersion
    )

    $searchResult = choco search $PackageName --exact --all-versions --approved-only --limit-output | 
        ConvertFrom-CSV -Delimiter '|' -Header 'Name', 'Version'

    $latestVersion = $searchResult.Version | 
        Where-Object { $_ -Like "$TargetVersion.*" -or $_ -eq $TargetVersion } | 
        Sort-Object { [version] $_ } | 
        Select-Object -Last 1

    return $latestVersion
}
