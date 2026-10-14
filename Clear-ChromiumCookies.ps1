<#
.SYNOPSIS
    Deletes all cookies from Chromium-based browsers for the current user.

.DESCRIPTION
    Walks every profile of every installed Chromium-based browser
    (Chrome, Chromium, Edge, Brave, Vivaldi, Opera) and deletes the
    Cookies SQLite database plus its journal/WAL files. The browser
    recreates an empty database on next launch.

    The Cookies file is locked while the browser runs, so by default any
    running browser process is closed first (sessions are restored on the
    next launch). Use -NoStopBrowsers to skip that and only delete files
    that are not locked.

.PARAMETER Browser
    Limit the cleanup to specific browsers. Default: all known browsers.

.PARAMETER NoStopBrowsers
    Do not close running browsers. Locked cookie databases are skipped.

.PARAMETER LogPath
    Log file. Default: %LOCALAPPDATA%\ClearChromiumCookies\clear-cookies.log

.EXAMPLE
    .\Clear-ChromiumCookies.ps1
    Closes every Chromium browser and deletes all cookies.

.EXAMPLE
    .\Clear-ChromiumCookies.ps1 -Browser Chrome,Edge -NoStopBrowsers
#>

[CmdletBinding()]
param(
    [string[]] $Browser = @('Chrome', 'Chromium', 'Edge', 'Brave', 'Vivaldi', 'Opera'),

    [switch] $NoStopBrowsers,

    [string] $LogPath = (Join-Path $env:LOCALAPPDATA 'ClearChromiumCookies\clear-cookies.log')
)

# No Set-StrictMode here on purpose: this script must also run on the
# PowerShell 2.0 shipped with Windows 7.
$ErrorActionPreference = 'Stop'

# PowerShell -File passes "-Browser Chrome,Edge" as ONE literal string, so the
# list is normalised here instead of with a ValidateSet on the parameter.
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
# Canonical casing, duplicates removed.
$Browser = @($knownBrowsers | Where-Object { $Browser -contains $_ })

# User Data root + process names for each supported browser.
$catalog = @{
    Chrome   = @{ Base = $env:LOCALAPPDATA; Root = 'Google\Chrome\User Data';              Processes = @('chrome') }
    Chromium = @{ Base = $env:LOCALAPPDATA; Root = 'Chromium\User Data';                    Processes = @('chromium') }
    Edge     = @{ Base = $env:LOCALAPPDATA; Root = 'Microsoft\Edge\User Data';              Processes = @('msedge') }
    Brave    = @{ Base = $env:LOCALAPPDATA; Root = 'BraveSoftware\Brave-Browser\User Data'; Processes = @('brave') }
    Vivaldi  = @{ Base = $env:LOCALAPPDATA; Root = 'Vivaldi\User Data';                      Processes = @('vivaldi') }
    Opera    = @{ Base = $env:APPDATA;      Root = 'Opera Software\Opera Stable';            Processes = @('opera') }
}

$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log {
    param([string] $Message, [string] $Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
    Write-Verbose $line
}

function Stop-BrowserProcess {
    param([string[]] $Names)
    foreach ($name in $Names) {
        $procs = @(Get-Process -Name $name -ErrorAction SilentlyContinue)
        if ($procs.Count -eq 0) { continue }

        Write-Log "Closing $($procs.Count) '$name' process(es)."
        foreach ($p in $procs) {
            try { $null = $p.CloseMainWindow() } catch { }
        }
        # Give the browser a few seconds to flush and release the database.
        $null = $procs | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue

        $procs = @(Get-Process -Name $name -ErrorAction SilentlyContinue)
        if ($procs.Count -gt 0) {
            Write-Log "'$name' still running; forcing termination." 'WARN'
            $procs | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
    }
}

# Cookie databases live either in <Profile>\Network\Cookies (current layout)
# or <Profile>\Cookies (older builds). Journal/WAL siblings must go too.
function Get-CookieFile {
    param([string] $UserDataRoot)

    $patterns = @('Cookies', 'Cookies-journal', 'Cookies-wal', 'Cookies-shm')
    foreach ($pattern in $patterns) {
        # -File needs PowerShell 3.0, so directories are filtered by hand.
        Get-ChildItem -LiteralPath $UserDataRoot -Filter $pattern -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer }
    }
}

Write-Log "--- Cookie cleanup started (PowerShell $($PSVersionTable.PSVersion)) ---"
$deleted = 0
$skipped = 0

foreach ($name in $Browser) {
    $entry = $catalog[$name]
    $root  = Join-Path $entry.Base $entry.Root

    if (-not (Test-Path -LiteralPath $root)) {
        Write-Log "$name not installed ($root); skipping."
        continue
    }

    if (-not $NoStopBrowsers) {
        Stop-BrowserProcess -Names $entry.Processes
    }

    foreach ($file in Get-CookieFile -UserDataRoot $root) {
        try {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            $deleted++
            Write-Log "Deleted $($file.FullName)"
        }
        catch {
            $skipped++
            Write-Log "Could not delete $($file.FullName): $($_.Exception.Message)" 'WARN'
        }
    }
}

Write-Log "--- Cookie cleanup finished: $deleted deleted, $skipped skipped ---"
if ($skipped -gt 0) { exit 1 }
exit 0
