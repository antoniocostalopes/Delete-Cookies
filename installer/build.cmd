@echo off
REM Builds installer\dist\DeleteCookies-Setup-<version>.exe with Inno Setup 6.
REM Install the compiler first:  winget install -e --id JRSoftware.InnoSetup
setlocal

set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" (
    where iscc.exe >nul 2>&1 && set "ISCC=iscc.exe"
)
if not exist "%ISCC%" if /i not "%ISCC%"=="iscc.exe" (
    echo [ERRO] Inno Setup 6 nao encontrado.
    echo        Instala com:  winget install -e --id JRSoftware.InnoSetup
    echo.
    pause
    exit /b 1
)

"%ISCC%" "%~dp0DeleteCookies.iss"
if errorlevel 1 (
    echo.
    echo [ERRO] A compilacao falhou.
    pause
    exit /b 1
)

echo.
echo Instalador criado em: %~dp0dist
pause
