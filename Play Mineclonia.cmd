@echo off
setlocal
where pwsh.exe >nul 2>&1
if errorlevel 1 (
    set "shell=powershell.exe"
) else (
    set "shell=pwsh.exe"
)
"%shell%" -NoLogo -NoProfile -File "%~dp0tools\Start-VibrantClient.ps1" -Profile Fast -TitleScreen -Config "%~dp0local\click-to-play.conf"
if errorlevel 1 (
    pause
    exit /b 1
)
