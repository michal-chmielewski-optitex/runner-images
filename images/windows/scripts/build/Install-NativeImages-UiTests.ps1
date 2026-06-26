################################################################################
##  File: Install-NativeImages-UiTests.ps1
##  Desc: Generate native images for lean Win11 UI test image builds
################################################################################

function Disable-NGenScheduledTasks {
    @(
        @{TaskPath = "\Microsoft\Windows\.NET Framework\"; TaskName = ".NET Framework NGEN v4.0.30319" }
        @{TaskPath = "\Microsoft\Windows\.NET Framework\"; TaskName = ".NET Framework NGEN v4.0.30319 64" }
    ) | ForEach-Object {
        Disable-ScheduledTask @PSItem -ErrorAction Ignore | Out-Null
    }
}

function Invoke-NGenUpdateWithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$NGenPath,
        [Parameter(Mandatory = $true)][string]$Label,
        [int]$MaxAttempts = 3
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        Write-Host "NGen: update $Label native images (attempt $attempt/$MaxAttempts)..."
        & $NGenPath executequeueditems 2>&1 | ForEach-Object { Write-Host $_ }
        & $NGenPath update 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -eq 0) {
            return
        }

        if ($attempt -lt $MaxAttempts) {
            Start-Sleep -Seconds 45
        }
    }

    Write-Warning "NGen update for $Label failed with exit code $LASTEXITCODE after $MaxAttempts attempts; continuing build."
}

Disable-NGenScheduledTasks

Write-Host "NGen: install Microsoft.PowerShell.Utility.Activities..."
& $env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\ngen.exe install "Microsoft.PowerShell.Utility.Activities, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" 2>&1 | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    throw "Installation of Microsoft.PowerShell.Utility.Activities failed with exit code $LASTEXITCODE"
}

if (Test-IsX64) {
    Invoke-NGenUpdateWithRetry -NGenPath "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\ngen.exe" -Label "x64"
    Invoke-NGenUpdateWithRetry -NGenPath "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\ngen.exe" -Label "x86"
}
