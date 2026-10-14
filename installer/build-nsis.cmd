@echo off
REM Builds dist\DeleteCookies-Setup-1.0.0.exe with NSIS.
REM Install the compiler first:  winget install -e --id NSIS.NSIS
setlocal
set "MAKENSIS=%ProgramFiles(x86)%\NSIS\makensis.exe"
if not exist "%MAKENSIS%" set "MAKENSIS=%ProgramFiles%\NSIS\makensis.exe"
if not exist "%MAKENSIS%" (
    echo [ERRO] NSIS nao encontrado. Instala com: winget install -e --id NSIS.NSIS
    pause
    exit /b 1
)
"%MAKENSIS%" "%~dp0DeleteCookies.nsi"
if errorlevel 1 ( echo. & echo [ERRO] Compilacao falhou. & pause & exit /b 1 )
echo.
echo Instalador em: %~dp0dist
pause
