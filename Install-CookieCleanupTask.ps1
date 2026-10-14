<#
.SYNOPSIS
    Registers a Windows Scheduled Task that deletes all Chromium cookies
    every day at 05:30.

.DESCRIPTION
    Copies Clear-ChromiumCookies.ps1 to a stable location and registers a
    daily task through schtasks.exe, which is present on every Windows
    version (the ScheduledTasks PowerShell module only exists on Windows 8 /
    Server 2012 and newer). Re-running the installer replaces the task.

    Everything it does is logged to <InstallDir>\install-task.log.

.PARAMETER Time
    Daily run time, 24h "HH:mm". Default: 05:30.

.PARAMETER TaskName
    Scheduled task name. Default: "Clear Chromium Cookies Daily".

.PARAMETER Browser
    Browsers to clean, comma separated. Default: all supported ones.

.PARAMETER NoStopBrowsers
    Pass -NoStopBrowsers to the cleanup script (locked databases are skipped
    instead of closing the browser).

.PARAMETER InstallDir
    Where the cleanup script is copied.
    Default: %LOCALAPPDATA%\ClearChromiumCookies

.PARAMETER Uninstall
    Remove the scheduled task and the installed script.

.EXAMPLE
    .\Install-CookieCleanupTask.ps1

.EXAMPLE
    .\Install-CookieCleanupTask.ps1 -Time 03:30 -Browser Chrome,Edge

.EXAMPLE
    .\Install-CookieCleanupTask.ps1 -Uninstall
#>

[CmdletBinding()]
param(
    [string] $Time = '05:30',

    [string] $TaskName = 'Clear Chromium Cookies Daily',

    [string[]] $Browser = @('Chrome', 'Chromium', 'Edge', 'Brave', 'Vivaldi', 'Opera'),

    [switch] $NoStopBrowsers,

    [string] $InstallDir = (Join-Path $env:LOCALAPPDATA 'ClearChromiumCookies'),

    [switch] $Uninstall
)

# No Set-StrictMode here on purpose: this script must also run on the
# PowerShell 2.0 shipped with Windows 7.
$ErrorActionPreference = 'Stop'

$logFile = $null

function Write-Log {
    param([string] $Message, [string] $Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    if ($logFile) {
        try { Add-Content -LiteralPath $logFile -Value $line } catch { }
    }
}

function ConvertTo-XmlText {
    param([string] $Value)
    $Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
}

try {
    # -- normalise arguments -------------------------------------------------
    # PowerShell -File passes "-Browser Chrome,Edge" as ONE literal string, so
    # the list is split here instead of with a ValidateSet on the parameter.
    $knownBrowsers = @('Chrome', 'Chromium', 'Edge', 'Brave', 'Vivaldi', 'Opera')
    $Browser = @(
        $Browser |
            ForEach-Object { $_ -split ',' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ }
    )
    if ($Browser.Count -eq 0) { $Browser = $knownBrowsers }

    $unknown = @($Browser | Where-Object { $knownBrowsers -notcontains $_ })
    if ($unknown.Count -gt 0) {
        throw "Unknown browser(s): $($unknown -join ', '). Valid values: $($knownBrowsers -join ', ')."
    }
    $Browser = @($knownBrowsers | Where-Object { $Browser -contains $_ })

    if ($Time -notmatch '^([01][0-9]|2[0-3]):[0-5][0-9]$') {
        throw "Invalid -Time '$Time'. Use 24h HH:mm, for example 05:00."
    }

    if (-not (Test-Path -LiteralPath $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
    $InstallDir = (Resolve-Path -LiteralPath $InstallDir).Path
    $logFile = Join-Path $InstallDir 'install-task.log'

    Write-Log "=== Install-CookieCleanupTask started ==="
    Write-Log "PowerShell $($PSVersionTable.PSVersion) | User $env:USERDOMAIN\$env:USERNAME"
    Write-Log "InstallDir=$InstallDir Time=$Time Browsers=$($Browser -join ',') Uninstall=$Uninstall"

    $targetScript = Join-Path $InstallDir 'Clear-ChromiumCookies.ps1'
    $schtasks     = Join-Path $env:SystemRoot 'System32\schtasks.exe'
    if (-not (Test-Path -LiteralPath $schtasks)) { $schtasks = 'schtasks.exe' }

    # -- uninstall -----------------------------------------------------------
    if ($Uninstall) {
        $null = & $schtasks /Query /TN $TaskName 2>&1
        if ($LASTEXITCODE -eq 0) {
            $out = & $schtasks /Delete /TN $TaskName /F 2>&1
            Write-Log ("schtasks /Delete: " + ($out -join ' '))
            if ($LASTEXITCODE -ne 0) { throw "schtasks /Delete failed with exit code $LASTEXITCODE." }
            Write-Log "Scheduled task '$TaskName' removed."
        }
        else {
            Write-Log "Scheduled task '$TaskName' not found; nothing to remove."
        }

        if (Test-Path -LiteralPath $targetScript) {
            Remove-Item -LiteralPath $targetScript -Force
            Write-Log "Removed $targetScript"
        }
        Write-Log "=== Done ==="
        exit 0
    }

    # -- copy the cleanup script --------------------------------------------
    $scriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $sourceScript = Join-Path $scriptDir 'Clear-ChromiumCookies.ps1'
    if (-not (Test-Path -LiteralPath $sourceScript)) {
        throw "Clear-ChromiumCookies.ps1 not found next to this installer ($sourceScript)."
    }

    # When -InstallDir is the installer's own folder the script is already in
    # place; copying it onto itself would fail.
    $sourceFull = (Resolve-Path -LiteralPath $sourceScript).Path
    if ($sourceFull -ne $targetScript) {
        Copy-Item -LiteralPath $sourceFull -Destination $targetScript -Force
        Write-Log "Cleanup script copied to $targetScript"
    }
    else {
        Write-Log "Cleanup script already in place at $targetScript"
    }

    # -- build the task XML --------------------------------------------------
    # schtasks /XML works on every Windows version and supports settings that
    # the plain /Create switches cannot express (StartWhenAvailable, batteries).
    $pwsh = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $pwshCommand = Get-Command 'pwsh.exe' -ErrorAction SilentlyContinue
    if ($pwshCommand -ne $null -and $pwshCommand.Path) { $pwsh = $pwshCommand.Path }

    $taskArgs = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Browser {1}' -f $targetScript, ($Browser -join ',')
    if ($NoStopBrowsers) { $taskArgs += ' -NoStopBrowsers' }

    $userId      = "$env:USERDOMAIN\$env:USERNAME"
    $description = "Deletes all cookies from Chromium-based browsers every day at $Time."

    $xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>$(ConvertTo-XmlText $userId)</Author>
    <Description>$(ConvertTo-XmlText $description)</Description>
  </RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>2020-01-01T${Time}:00</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$(ConvertTo-XmlText $userId)</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT10M</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>$(ConvertTo-XmlText $pwsh)</Command>
      <Arguments>$(ConvertTo-XmlText $taskArgs)</Arguments>
    </Exec>
  </Actions>
</Task>
"@

    $expectedBoundary = "2020-01-01T${Time}:00"
    if ($xml -notmatch [regex]::Escape("<StartBoundary>$expectedBoundary</StartBoundary>")) {
        throw "Task XML has a bad StartBoundary; expected '$expectedBoundary'."
    }
    try {
        $null = [xml] $xml
    }
    catch {
        throw "Generated task XML is not well formed: $($_.Exception.Message)"
    }

    # schtasks /XML requires a Unicode (UTF-16 LE) file.
    $xmlPath = Join-Path $InstallDir 'task.xml'
    [System.IO.File]::WriteAllText($xmlPath, $xml, [System.Text.Encoding]::Unicode)
    Write-Log "Task XML written to $xmlPath"
    Write-Log "Task action: $pwsh $taskArgs"

    # -- register ------------------------------------------------------------
    Write-Log "StartBoundary: $expectedBoundary"
    $out = & $schtasks /Create /TN $TaskName /XML $xmlPath /F 2>&1
    Write-Log ("schtasks /Create: " + ($out -join ' '))
    if ($LASTEXITCODE -ne 0) {
        Write-Log "The rejected XML was kept at $xmlPath" 'ERROR'
        Write-Log ("--- XML ---`r`n" + $xml) 'ERROR'
        throw "schtasks /Create failed with exit code $LASTEXITCODE."
    }

    $out = & $schtasks /Query /TN $TaskName 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Task '$TaskName' was not found after creation."
    }
    Remove-Item -LiteralPath $xmlPath -Force -ErrorAction SilentlyContinue

    Write-Log "Scheduled task '$TaskName' registered: daily at $Time."
    Write-Log "Browsers: $($Browser -join ', ')"
    Write-Log "=== Done ==="
    exit 0
}
catch {
    $message = $_.Exception.Message
    $where   = ''
    if ($_.InvocationInfo) { $where = " (line $($_.InvocationInfo.ScriptLineNumber))" }
    Write-Log "FAILED$where : $message" 'ERROR'
    Write-Host $_.ScriptStackTrace
    exit 1
}
