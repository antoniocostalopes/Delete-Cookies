; NSIS installer for "Delete Cookies"
; Per-user install (no administrator rights). Registers a Scheduled Task that
; deletes all Chromium cookies daily at the chosen time.
;
; Build (Windows, macOS or Linux):  makensis DeleteCookies.nsi

Unicode true

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "nsDialogs.nsh"
!include "x64.nsh"
!include "FileFunc.nsh"

!define APPNAME    "Delete Cookies"
!define APPVERSION "1.0.5"
!define PUBLISHER  "Antonio Lopes"
!define TASKNAME   "Clear Chromium Cookies Daily"
!define REGKEY     "Software\Microsoft\Windows\CurrentVersion\Uninstall\DeleteCookies"

Name "${APPNAME} ${APPVERSION}"
OutFile "dist\DeleteCookies-Setup-${APPVERSION}.exe"
InstallDir "$LOCALAPPDATA\Programs\${APPNAME}"
InstallDirRegKey HKCU "Software\${APPNAME}" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
ShowInstDetails show
ShowUninstDetails show

VIProductVersion "${APPVERSION}.0"
VIAddVersionKey "ProductName"     "${APPNAME}"
VIAddVersionKey "ProductVersion"  "${APPVERSION}"
VIAddVersionKey "CompanyName"     "${PUBLISHER}"
VIAddVersionKey "FileDescription" "Limpeza diaria de cookies Chromium"
VIAddVersionKey "FileVersion"     "${APPVERSION}"
VIAddVersionKey "LegalCopyright"  "${PUBLISHER}"

; ---------------------------------------------------------------- variables
Var Dialog
Var hTime
Var hChrome
Var hChromium
Var hEdge
Var hBrave
Var hVivaldi
Var hOpera
Var sTime
Var sBrowsers
Var hOpenLog
Var sOpenLog
Var sPwsh
Var sCmd
Var sOutLog

; ---------------------------------------------------------------- pages
!define MUI_ABORTWARNING
!define MUI_ICON   "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"

!define MUI_WELCOMEPAGE_TITLE "${APPNAME}"
!define MUI_WELCOMEPAGE_TEXT "Este programa cria uma tarefa agendada do Windows que apaga TODOS os cookies dos browsers Chromium, todos os dias a hora que escolheres.$\r$\n$\r$\nApagar cookies termina as sessoes (logins) de todos os sites.$\r$\n$\r$\nNao sao necessarios direitos de administrador."
!insertmacro MUI_PAGE_WELCOME

Page custom OptionsPageCreate OptionsPageLeave

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_NOREBOOTSUPPORT
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Limpar os cookies agora (fecha os browsers abertos)"
!define MUI_FINISHPAGE_RUN_FUNCTION RunCleanupNow
!define MUI_FINISHPAGE_RUN_NOTCHECKED
!define MUI_FINISHPAGE_TEXT "A tarefa diaria ficou registada.$\r$\n$\r$\nNome da tarefa: ${TASKNAME}$\r$\nLog: %LOCALAPPDATA%\ClearChromiumCookies\clear-cookies.log"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "PortugueseBR"
!insertmacro MUI_LANGUAGE "English"

; ---------------------------------------------------------------- helpers
; Resolve the real 64-bit PowerShell even when this 32-bit installer runs
; under WOW64 file system redirection.
Function GetPwsh
  ${If} ${RunningX64}
    ${DisableX64FSRedirection}
  ${EndIf}
  StrCpy $sPwsh "$WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
FunctionEnd

Function RestoreRedirection
  ${If} ${RunningX64}
    ${EnableX64FSRedirection}
  ${EndIf}
FunctionEnd

; ---------------------------------------------------------------- options page
Function OptionsPageCreate
  !insertmacro MUI_HEADER_TEXT "Opcoes" "Hora da limpeza e browsers a limpar"

  nsDialogs::Create 1018
  Pop $Dialog
  ${If} $Dialog == error
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 0 100% 24u "Hora da limpeza diaria (formato 24h, HH:MM). Se o PC estiver desligado a essa hora, a tarefa corre no arranque seguinte."
  Pop $0

  ${NSD_CreateText} 0 28u 40u 12u "$sTime"
  Pop $hTime

  ${NSD_CreateLabel} 0 48u 100% 20u "Browsers a limpar (os que nao estiverem instalados sao ignorados):"
  Pop $0

  ${NSD_CreateCheckbox} 0 68u 48% 10u "Google Chrome"
  Pop $hChrome
  ${NSD_SetState} $hChrome ${BST_CHECKED}

  ${NSD_CreateCheckbox} 50% 68u 48% 10u "Chromium"
  Pop $hChromium
  ${NSD_SetState} $hChromium ${BST_CHECKED}

  ${NSD_CreateCheckbox} 0 82u 48% 10u "Microsoft Edge"
  Pop $hEdge
  ${NSD_SetState} $hEdge ${BST_CHECKED}

  ${NSD_CreateCheckbox} 50% 82u 48% 10u "Brave"
  Pop $hBrave
  ${NSD_SetState} $hBrave ${BST_CHECKED}

  ${NSD_CreateCheckbox} 0 96u 48% 10u "Vivaldi"
  Pop $hVivaldi
  ${NSD_SetState} $hVivaldi ${BST_CHECKED}

  ${NSD_CreateCheckbox} 50% 96u 48% 10u "Opera"
  Pop $hOpera
  ${NSD_SetState} $hOpera ${BST_CHECKED}

  ${NSD_CreateLabel} 0 112u 100% 18u "Os browsers abertos sao fechados antes da limpeza; as abas sao restauradas no arranque seguinte."
  Pop $0

  ${NSD_CreateCheckbox} 0 132u 100% 10u "Se ocorrer um erro, abrir a janela com o log dos erros"
  Pop $hOpenLog
  ${If} $sOpenLog == "1"
    ${NSD_SetState} $hOpenLog ${BST_CHECKED}
  ${EndIf}

  nsDialogs::Show
FunctionEnd

Function OptionsPageLeave
  ${NSD_GetText} $hTime $sTime
  Call ValidateTime
  Pop $0
  ${If} $0 != "ok"
    MessageBox MB_ICONEXCLAMATION|MB_OK "Hora invalida. Usa o formato HH:MM, por exemplo 05:00."
    Abort
  ${EndIf}

  StrCpy $sBrowsers ""
  ${NSD_GetState} $hChrome $0
  ${If} $0 == ${BST_CHECKED}
    Push "Chrome"
    Call AppendBrowser
  ${EndIf}
  ${NSD_GetState} $hChromium $0
  ${If} $0 == ${BST_CHECKED}
    Push "Chromium"
    Call AppendBrowser
  ${EndIf}
  ${NSD_GetState} $hEdge $0
  ${If} $0 == ${BST_CHECKED}
    Push "Edge"
    Call AppendBrowser
  ${EndIf}
  ${NSD_GetState} $hBrave $0
  ${If} $0 == ${BST_CHECKED}
    Push "Brave"
    Call AppendBrowser
  ${EndIf}
  ${NSD_GetState} $hVivaldi $0
  ${If} $0 == ${BST_CHECKED}
    Push "Vivaldi"
    Call AppendBrowser
  ${EndIf}
  ${NSD_GetState} $hOpera $0
  ${If} $0 == ${BST_CHECKED}
    Push "Opera"
    Call AppendBrowser
  ${EndIf}

  ${If} $sBrowsers == ""
    MessageBox MB_ICONEXCLAMATION|MB_OK "Escolhe pelo menos um browser."
    Abort
  ${EndIf}

  ${NSD_GetState} $hOpenLog $0
  ${If} $0 == ${BST_CHECKED}
    StrCpy $sOpenLog "1"
  ${Else}
    StrCpy $sOpenLog "0"
  ${EndIf}
FunctionEnd

; Appends the browser name on the stack to the comma-separated $sBrowsers.
Function AppendBrowser
  Exch $1
  ${If} $sBrowsers == ""
    StrCpy $sBrowsers "$1"
  ${Else}
    StrCpy $sBrowsers "$sBrowsers,$1"
  ${EndIf}
  Pop $1
FunctionEnd

; Pushes "ok" when $sTime is a valid HH:MM value.
Function ValidateTime
  Push $1
  Push $2
  Push $3

  StrLen $1 $sTime
  ${If} $1 != 5
    Goto bad
  ${EndIf}
  StrCpy $2 $sTime 1 2
  ${If} $2 != ":"
    Goto bad
  ${EndIf}

  StrCpy $2 $sTime 2 0   ; hours
  StrCpy $3 $sTime 2 3   ; minutes
  Call IsTwoDigits
  Pop $1
  ${If} $1 != "ok"
    Goto bad
  ${EndIf}

  IntOp $1 $2 + 0
  ${If} $1 > 23
    Goto bad
  ${EndIf}
  IntOp $1 $3 + 0
  ${If} $1 > 59
    Goto bad
  ${EndIf}

  Pop $3
  Pop $2
  Pop $1
  Push "ok"
  Return

bad:
  Pop $3
  Pop $2
  Pop $1
  Push "bad"
FunctionEnd

; Checks that $2 and $3 contain two digits each.
Function IsTwoDigits
  Push $4
  Push $5
  Push $6

  StrCpy $6 0
  loop:
    ${If} $6 < 2
      StrCpy $4 $2 1 $6
      StrCpy $5 $3 1 $6
      ${If} $4 S< "0"
        Goto notdigit
      ${EndIf}
      ${If} $4 S> "9"
        Goto notdigit
      ${EndIf}
      ${If} $5 S< "0"
        Goto notdigit
      ${EndIf}
      ${If} $5 S> "9"
        Goto notdigit
      ${EndIf}
      IntOp $6 $6 + 1
      Goto loop
    ${EndIf}

  Pop $6
  Pop $5
  Pop $4
  Push "ok"
  Return

notdigit:
  Pop $6
  Pop $5
  Pop $4
  Push "bad"
FunctionEnd

; ---------------------------------------------------------------- install
Function .onInit
  ; Defaults, also used by silent installs where the options page never shows.
  StrCpy $sTime "05:30"
  StrCpy $sBrowsers "Chrome,Chromium,Edge,Brave,Vivaldi,Opera"
  StrCpy $sOpenLog "1"
FunctionEnd

Section "Install"
  SetOutPath "$INSTDIR"
  File "..\Clear-ChromiumCookies.ps1"
  File "..\Install-CookieCleanupTask.ps1"
  File "..\README.md"

  CreateDirectory "$LOCALAPPDATA\ClearChromiumCookies"

  WriteRegStr HKCU "Software\${APPNAME}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\${APPNAME}" "Time"       "$sTime"
  WriteRegStr HKCU "Software\${APPNAME}" "Browsers"   "$sBrowsers"

  ; Register the daily scheduled task with the chosen options.
  Call GetPwsh
  DetailPrint "A registar a tarefa diaria as $sTime..."
  ; cmd.exe redirection captures stdout AND stderr, so even a PowerShell that
  ; dies before creating its own log leaves the error in a readable file.
  StrCpy $sOutLog "$INSTDIR\install-output.log"
  StrCpy $sCmd '"$SYSDIR\cmd.exe" /C ""$sPwsh" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$INSTDIR\Install-CookieCleanupTask.ps1" -InstallDir "$INSTDIR" -TaskName "${TASKNAME}" -Time $sTime -Browser $sBrowsers > "$sOutLog" 2>&1"'
  nsExec::ExecToLog $sCmd
  Pop $0
  Call RestoreRedirection
  ${If} $0 != 0
    SetDetailsView show
    Call EnsureLogExists
    DetailPrint "ERRO: o registo da tarefa falhou (codigo $0). Log: $sOutLog"
    ${If} $sOpenLog == "1"
      Call OpenLogWindow
      MessageBox MB_ICONEXCLAMATION|MB_OK "Nao foi possivel registar a tarefa agendada (codigo $0).$\r$\n$\r$\nO log com o erro foi aberto numa janela do Bloco de Notas:$\r$\n$sOutLog"
    ${Else}
      MessageBox MB_ICONEXCLAMATION|MB_YESNO "Nao foi possivel registar a tarefa agendada (codigo $0).$\r$\n$\r$\nQueres abrir a janela com o log dos erros?$\r$\n$sOutLog" IDNO +2
      Call OpenLogWindow
    ${EndIf}
  ${Else}
    DetailPrint "Tarefa '${TASKNAME}' registada: diariamente as $sTime."
  ${EndIf}

  ; Start menu shortcuts.
  CreateDirectory "$SMPROGRAMS\${APPNAME}"
  CreateShortcut "$SMPROGRAMS\${APPNAME}\Limpar cookies agora.lnk" \
    "$sPwsh" \
    '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$INSTDIR\Clear-ChromiumCookies.ps1" -Browser $sBrowsers' \
    "$WINDIR\System32\shell32.dll" 21
  CreateShortcut "$SMPROGRAMS\${APPNAME}\Ver log.lnk" \
    "$WINDIR\explorer.exe" '"$LOCALAPPDATA\ClearChromiumCookies"'
  CreateShortcut "$SMPROGRAMS\${APPNAME}\Log de instalacao.lnk" \
    "$WINDIR\notepad.exe" '"$INSTDIR\install-output.log"'
  CreateShortcut "$SMPROGRAMS\${APPNAME}\Desinstalar.lnk" "$INSTDIR\Uninstall.exe"

  ; Add/Remove Programs entry (per user).
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr   HKCU "${REGKEY}" "DisplayName"     "${APPNAME}"
  WriteRegStr   HKCU "${REGKEY}" "DisplayVersion"  "${APPVERSION}"
  WriteRegStr   HKCU "${REGKEY}" "Publisher"       "${PUBLISHER}"
  WriteRegStr   HKCU "${REGKEY}" "DisplayIcon"     "$INSTDIR\Uninstall.exe"
  WriteRegStr   HKCU "${REGKEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr   HKCU "${REGKEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegStr   HKCU "${REGKEY}" "InstallLocation" "$INSTDIR"
  WriteRegDWORD HKCU "${REGKEY}" "NoModify" 1
  WriteRegDWORD HKCU "${REGKEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKCU "${REGKEY}" "EstimatedSize" $0
SectionEnd

; Opens both logs in Notepad: the console transcript and, when the PowerShell
; script got far enough to create it, its own structured log.
Function OpenLogWindow
  ExecShell "open" "notepad.exe" '"$sOutLog"'
  ${If} ${FileExists} "$INSTDIR\install-task.log"
    Sleep 300
    ExecShell "open" "notepad.exe" '"$INSTDIR\install-task.log"'
  ${EndIf}
FunctionEnd

; Guarantees the log window has something to show even if nothing was written.
Function EnsureLogExists
  ${IfNot} ${FileExists} "$sOutLog"
    FileOpen $1 "$sOutLog" w
    ${If} $1 != ""
      FileWrite $1 "O registo da tarefa agendada falhou com o codigo $0.$\r$\n"
      FileWrite $1 "Nao houve saida do PowerShell - provavelmente nao chegou a arrancar.$\r$\n$\r$\n"
      FileWrite $1 "PowerShell: $sPwsh$\r$\n"
      FileWrite $1 "Comando:    $sCmd$\r$\n$\r$\n"
      FileWrite $1 "Tenta correr esse comando numa janela do PowerShell para veres o erro.$\r$\n"
      FileClose $1
    ${EndIf}
  ${EndIf}
FunctionEnd

Function RunCleanupNow
  ReadRegStr $sBrowsers HKCU "Software\${APPNAME}" "Browsers"
  Call GetPwsh
  nsExec::ExecToLog '"$sPwsh" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$INSTDIR\Clear-ChromiumCookies.ps1" -Browser $sBrowsers'
  Pop $0
  Call RestoreRedirection
FunctionEnd

; ---------------------------------------------------------------- uninstall
Section "Uninstall"
  ; Remove the scheduled task before deleting the scripts it points at.
  ${If} ${RunningX64}
    ${DisableX64FSRedirection}
  ${EndIf}
  StrCpy $sPwsh "$WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
  DetailPrint "A remover a tarefa agendada..."
  nsExec::ExecToLog '"$sPwsh" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$INSTDIR\Install-CookieCleanupTask.ps1" -Uninstall -InstallDir "$INSTDIR" -TaskName "${TASKNAME}"'
  Pop $0
  ${If} ${RunningX64}
    ${EnableX64FSRedirection}
  ${EndIf}

  Delete "$SMPROGRAMS\${APPNAME}\Limpar cookies agora.lnk"
  Delete "$SMPROGRAMS\${APPNAME}\Ver log.lnk"
  Delete "$SMPROGRAMS\${APPNAME}\Log de instalacao.lnk"
  Delete "$SMPROGRAMS\${APPNAME}\Desinstalar.lnk"
  RMDir  "$SMPROGRAMS\${APPNAME}"

  Delete "$INSTDIR\Clear-ChromiumCookies.ps1"
  Delete "$INSTDIR\Install-CookieCleanupTask.ps1"
  Delete "$INSTDIR\README.md"
  Delete "$INSTDIR\install-output.log"
  Delete "$INSTDIR\install-task.log"
  Delete "$INSTDIR\task.xml"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir  "$INSTDIR"

  DeleteRegKey HKCU "${REGKEY}"
  DeleteRegKey HKCU "Software\${APPNAME}"
SectionEnd
