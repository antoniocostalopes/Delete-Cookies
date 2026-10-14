; Inno Setup script for "Delete Cookies"
; Builds a single setup.exe that installs the cleanup scripts and registers
; the daily Scheduled Task. Per-user install, no administrator rights needed.
;
; Build:  iscc installer\DeleteCookies.iss     (or run installer\build.cmd)

#define MyAppName      "Delete Cookies"
#define MyAppVersion   "1.0.5"
#define MyAppPublisher "Antonio Lopes"
#define MyTaskName     "Clear Chromium Cookies Daily"
#define MyPwsh         "{sys}\WindowsPowerShell\v1.0\powershell.exe"

[Setup]
AppId={{8F3A6B21-5C4D-4E8A-9B17-2D6C0A7E4F51}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
VersionInfoVersion={#MyAppVersion}

; Per-user install: {autopf} resolves to %LOCALAPPDATA%\Programs
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={sys}\shell32.dll,21

OutputDir=.\dist
OutputBaseFilename=DeleteCookies-Setup-{#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "pt"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Dirs]
Name: "{localappdata}\ClearChromiumCookies"

[Files]
Source: "..\Clear-ChromiumCookies.ps1";    DestDir: "{app}"; Flags: ignoreversion
Source: "..\Install-CookieCleanupTask.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md";                     DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}\Limpar cookies agora"; \
    Filename: "{#MyPwsh}"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\Clear-ChromiumCookies.ps1"""; \
    IconFilename: "{sys}\shell32.dll"; IconIndex: 21
Name: "{autoprograms}\{#MyAppName}\Ver log"; \
    Filename: "{win}\explorer.exe"; \
    Parameters: """{localappdata}\ClearChromiumCookies"""

[Run]
; Register the scheduled task with the choices made in the wizard.
Filename: "{#MyPwsh}"; \
    Parameters: "{code:GetTaskArgs}"; \
    StatusMsg: "A registar a tarefa diaria..."; \
    Flags: runhidden waituntilterminated
; Optional first run.
Filename: "{#MyPwsh}"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\Clear-ChromiumCookies.ps1"" {code:GetBrowserArg}"; \
    Description: "Limpar os cookies agora (fecha os browsers abertos)"; \
    Flags: runhidden postinstall unchecked

[UninstallRun]
; Remove the scheduled task before the files go away.
Filename: "{#MyPwsh}"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Install-CookieCleanupTask.ps1"" -Uninstall -InstallDir ""{app}"" -TaskName ""{#MyTaskName}"""; \
    RunOnceId: "RemoveCookieTask"; \
    Flags: runhidden waituntilterminated

[Code]
var
  TimePage: TInputQueryWizardPage;
  BrowserPage: TInputOptionWizardPage;

procedure InitializeWizard();
begin
  TimePage := CreateInputQueryPage(wpSelectDir,
    'Hora da limpeza',
    'A que horas devem os cookies ser apagados?',
    'Formato 24 horas, HH:MM. Se o PC estiver desligado a essa hora, a tarefa' + #13#10 +
    'corre no arranque seguinte.');
  TimePage.Add('Hora diaria:', False);
  TimePage.Values[0] := '05:30';

  BrowserPage := CreateInputOptionPage(TimePage.ID,
    'Browsers',
    'Quais os browsers a limpar?',
    'Browsers nao instalados sao ignorados. Os browsers abertos sao fechados' + #13#10 +
    'antes da limpeza (as abas sao restauradas no arranque seguinte).',
    False, False);
  BrowserPage.Add('Google Chrome');
  BrowserPage.Add('Chromium');
  BrowserPage.Add('Microsoft Edge');
  BrowserPage.Add('Brave');
  BrowserPage.Add('Vivaldi');
  BrowserPage.Add('Opera');
  BrowserPage.Values[0] := True;
  BrowserPage.Values[1] := True;
  BrowserPage.Values[2] := True;
  BrowserPage.Values[3] := True;
  BrowserPage.Values[4] := True;
  BrowserPage.Values[5] := True;
end;

function IsValidTime(const S: String): Boolean;
var
  H, M: Integer;
begin
  Result := False;
  if Length(S) <> 5 then Exit;
  if S[3] <> ':' then Exit;
  H := StrToIntDef(Copy(S, 1, 2), -1);
  M := StrToIntDef(Copy(S, 4, 2), -1);
  Result := (H >= 0) and (H <= 23) and (M >= 0) and (M <= 59);
end;

function SelectedBrowsers(): String;
var
  I: Integer;
  Names: array[0..5] of String;
begin
  Names[0] := 'Chrome';
  Names[1] := 'Chromium';
  Names[2] := 'Edge';
  Names[3] := 'Brave';
  Names[4] := 'Vivaldi';
  Names[5] := 'Opera';

  Result := '';
  for I := 0 to 5 do
    if BrowserPage.Values[I] then
    begin
      if Result <> '' then Result := Result + ',';
      Result := Result + Names[I];
    end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = TimePage.ID then
    if not IsValidTime(Trim(TimePage.Values[0])) then
    begin
      MsgBox('Hora invalida. Usa o formato HH:MM, por exemplo 05:00.', mbError, MB_OK);
      Result := False;
    end;

  if CurPageID = BrowserPage.ID then
    if SelectedBrowsers() = '' then
    begin
      MsgBox('Escolhe pelo menos um browser.', mbError, MB_OK);
      Result := False;
    end;
end;

// -Browser argument shared by the task registration and the optional first run.
function GetBrowserArg(Param: String): String;
begin
  Result := '-Browser ' + SelectedBrowsers();
end;

function GetTaskArgs(Param: String): String;
begin
  Result :=
    '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}') + '\Install-CookieCleanupTask.ps1"' +
    ' -InstallDir "' + ExpandConstant('{app}') + '"' +
    ' -TaskName "{#MyTaskName}"' +
    ' -Time ' + Trim(TimePage.Values[0]) +
    ' ' + GetBrowserArg('');
end;
