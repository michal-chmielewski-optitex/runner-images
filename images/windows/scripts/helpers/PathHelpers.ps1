
function Get-ImageHelperScriptPath {
    <#
    .SYNOPSIS
        Resolves a helper script path inside the ImageHelpers module directory.

    .DESCRIPTION
        Packer copies build scripts to C:\Windows\Temp, so $PSScriptRoot in build/*.ps1
        must not be used to locate sibling helper scripts. Helper scripts live next to
        ImageHelpers.psm1 and are resolved via this function instead.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string] $ScriptName
    )

    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    if (-not (Test-Path $scriptPath)) {
        throw "Image helper script not found: $scriptPath"
    }

    return $scriptPath
}

function Invoke-ImageHelperScript {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ScriptName
    )

    & (Get-ImageHelperScriptPath -ScriptName $ScriptName)
}

function ConvertTo-RegExeKeyPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $KeyPath
    )

    if ($KeyPath -match '^(.):\\') {
        return ($KeyPath -replace '^(.):\\', '$1\')
    }

    return $KeyPath
}

function Set-RegistryDwordViaRegExe {
    <#
    .SYNOPSIS
        Sets a REG_DWORD value using reg.exe (safe for mounted registry hives).

    .DESCRIPTION
        PowerShell registry cmdlets can keep hive handles open and block reg unload.
        Use this helper when writing to HKLM\DEFAULT after Mount-RegistryHive.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string] $KeyPath,
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $true)]
        [int] $Value
    )

    $regKeyPath = ConvertTo-RegExeKeyPath -KeyPath $KeyPath
    $ensureResult = reg add $regKeyPath /f *>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to ensure registry key ${regKeyPath}: $ensureResult"
    }

    $result = reg add $regKeyPath /v $Name /t REG_DWORD /d $Value /f *>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set ${regKeyPath}\${Name}: $result"
    }
}

function Set-RegistryKeyDword {
    param(
        [Parameter(Mandatory = $true)]
        [string] $KeyPath,
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $true)]
        [int] $Value,
        [switch] $UseRegExe
    )

    if ($UseRegExe) {
        Set-RegistryDwordViaRegExe -KeyPath $KeyPath -Name $Name -Value $Value
        return
    }

    if (-not (Test-Path $KeyPath)) {
        New-Item -Path $KeyPath -Force | Out-Null
    }

    New-ItemProperty -Path $KeyPath -Name $Name -PropertyType DWORD -Value $Value -Force | Out-Null
}

function Mount-RegistryHive {
    <#
    .SYNOPSIS
        Mounts a registry hive from a file.

    .DESCRIPTION
        The Mount-RegistryHive function loads a registry hive from a specified file into a specified subkey.

    .PARAMETER FileName
        The path to the file from which to load the registry hive.

    .PARAMETER SubKey
        The registry subkey into which to load the hive.

    .EXAMPLE
        Mount-RegistryHive -FileName "C:\Path\To\HiveFile.hiv" -SubKey "HKLM\SubKey"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string] $FileName,
        [Parameter(Mandatory = $true)]
        [string] $SubKey
    )

    Write-Host "Loading the file $FileName to the Key $SubKey"
    if (Test-Path $SubKey.Replace("\", ":")) {
        Write-Warning "The key $SubKey is already loaded"
        return
    }

    $result = reg load $SubKey $FileName *>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to load file $FileName to the key ${SubKey}: $result"
    }
}

function Dismount-RegistryHive {
    <#
    .SYNOPSIS
        Dismounts a registry hive.

    .DESCRIPTION
        The Dismount-RegistryHive function unloads a registry hive from a specified subkey.

    .PARAMETER SubKey
        The registry subkey from which to unload the hive.

    .EXAMPLE
        Dismount-RegistryHive -SubKey "HKLM\SubKey"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string] $SubKey
    )

    Write-Host "Unloading the hive $SubKey"
    if (-not (Test-Path $SubKey.Replace("\", ":"))) {
        return
    }

    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    $maxAttempts = 5
    $result = $null
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $result = reg unload $SubKey *>&1
        if ($LASTEXITCODE -eq 0) {
            return
        }

        if ($attempt -lt $maxAttempts) {
            Write-Host "Failed to unload hive (attempt ${attempt}/${maxAttempts}): $result. Retrying..."
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            Start-Sleep -Seconds 2
        }
    }

    throw "Failed to unload hive ${SubKey}: $result"
}

function Add-MachinePathItem {
    <#
    .SYNOPSIS
        Adds a new item to the machine-level PATH environment variable.

    .DESCRIPTION
        The Add-MachinePathItem function adds a new item to the machine-level PATH environment variable.
        It takes a string parameter, $PathItem, which represents the new item to be added to the PATH.

    .PARAMETER PathItem
        Specifies the new item to be added to the machine-level PATH environment variable.

    .EXAMPLE
        Add-MachinePathItem -PathItem "C:\Program Files\MyApp"

        This example adds "C:\Program Files\MyApp" to the machine-level PATH environment variable.
    #>

    param(
        [Parameter(Mandatory = $true)]
        [string] $PathItem
    )

    $currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $newPath = $PathItem + ';' + $currentPath
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
}

function Add-DefaultPathItem {
    <#
    .SYNOPSIS
        Adds a path item to the default user profile path.

    .DESCRIPTION
        This function adds a specified path item to the default user profile path.
        It mounts the NTUSER.DAT file of the default user to the registry,
        retrieves the current value of the "Path" environment variable,
        appends the new path item to it, and updates the registry with the modified value.

    .PARAMETER PathItem
        The path item to be added to the default user profile path.

    .EXAMPLE
        Add-DefaultPathItem -PathItem "C:\Program Files\MyApp"

        This example adds "C:\Program Files\MyApp" to the default user profile path.

    .NOTES
        This function requires administrative privileges to modify the Windows registry.
    #>

    param(
        [Parameter(Mandatory = $true)]
        [string] $PathItem
    )

    Mount-RegistryHive `
        -FileName "C:\Users\Default\NTUSER.DAT" `
        -SubKey "HKLM\DEFAULT"

    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("DEFAULT\Environment", $true)
    $currentValue = $key.GetValue("Path", "", "DoNotExpandEnvironmentNames")
    $updatedValue = $PathItem + ';' + $currentValue
    $key.SetValue("Path", $updatedValue, "ExpandString")
    $key.Handle.Close()
    [System.GC]::Collect()

    Dismount-RegistryHive "HKLM\DEFAULT"
}
