# Create shells folder
$shellPath = "C:\shells"
New-Item -Path $shellPath -ItemType Directory -Force | Out-Null

$msysBashPath = "C:\msys64\usr\bin\bash.exe"
if (Test-IsX64 -and (Test-Path $msysBashPath)) {
    # add a wrapper for C:\msys64\usr\bin\bash.exe
@'
@echo off
setlocal
IF NOT DEFINED MSYS2_PATH_TYPE set MSYS2_PATH_TYPE=strict
IF NOT DEFINED MSYSTEM set MSYSTEM=mingw64
set CHERE_INVOKING=1
C:\msys64\usr\bin\bash.exe -leo pipefail %*
'@ | Out-File -FilePath "$shellPath\msys2bash.cmd" -Encoding ascii
}

# gitbash <--> C:\Program Files\Git\bin\bash.exe
$gitBashPath = "$env:ProgramFiles\Git\bin\bash.exe"
if (Test-Path $gitBashPath) {
    New-Item -ItemType SymbolicLink -Path "$shellPath\gitbash.exe" -Target $gitBashPath -Force | Out-Null
}
else {
    Write-Host "Skipping gitbash.exe symlink; Git bash not installed ($gitBashPath)"
}

# wslbash <--> C:\Windows\System32\bash.exe
$wslBashPath = "$env:SystemRoot\System32\bash.exe"
if (Test-Path $wslBashPath) {
    New-Item -ItemType SymbolicLink -Path "$shellPath\wslbash.exe" -Target $wslBashPath -Force | Out-Null
}
else {
    Write-Host "Skipping wslbash.exe symlink; WSL bash not installed ($wslBashPath)"
}
