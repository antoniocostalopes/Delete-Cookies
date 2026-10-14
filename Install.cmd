@echo off
REM Double-click helper: registers the daily 05:00 cookie cleanup task.
REM No administrator rights required - the task runs as the current user.
setlocal
set "SCRIPT=%~dp0Install-CookieCleanupTask.ps1"

where pwsh.exe >nul 2>&1
if %ERRORLEVEL%==0 (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
)

echo.
pause
