
# ============================================================
# COMPUTE MODE - INTERACTIVE PROCESS MANAGER
# Windows 10 / PowerShell 5.1
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

$script:Denied = @{}
$script:Allowed = @{}
$script:Log = [System.Collections.Generic.List[string]]::new()
$script:Snapshot = @()
$script:InputBuffer = ""
$script:LastScan = Get-Date
$script:RefreshSeconds = 2
$script:ShowProtected = $false

# Basic protection for important Windows processes.
# This is not a complete system-safety boundary.
$script:ProtectedNames = @(
    "System", "Idle", "Registry", "smss", "csrss",
    "wininit", "winlogon", "services", "lsass",
    "svchost", "dwm", "fontdrvhost",
    "powershell", "powershell_ise", "pwsh"
)

# ------------------------------------------------------------
# ACTIVITY LOG
# ------------------------------------------------------------

function Add-Log {
    param([string]$Message)

    $entry = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message
    $script:Log.Add($entry)

    while ($script:Log.Count -gt 8) {
        $script:Log.RemoveAt(0)
    }
}

# ------------------------------------------------------------
# PROCESS LIST
# ------------------------------------------------------------

function Get-ProcessSnapshot {
    $items = @(Get-Process | Sort-Object ProcessName, Id)

    # Hide protected processes by default.
    if (-not $script:ShowProtected) {
        $items = @($items | Where-Object {
            $script:ProtectedNames -notcontains $_.ProcessName
        })
    }

    $newSnapshot = @()
    $number = 0

    foreach ($p in $items) {
        $number++
        $ram = 0

        try {
            $ram = [math]::Round($p.WorkingSet64 / 1MB, 1)
        } catch {}

        $key = $p.ProcessName.ToLowerInvariant()

        if ($script:ProtectedNames -contains $p.ProcessName) {
            $status = "PROTECTED"
        }
        elseif ($script:Allowed.ContainsKey($key)) {
            $status = "ALLOWED"
        }
        elseif ($script:Denied.ContainsKey($key)) {
            $status = "DENIED"
        }
        else {
            $status = "-"
        }

        $newSnapshot += [pscustomobject]@{
            Number = $number
            PID    = $p.Id
            Name   = $p.ProcessName
            RAM_MB = $ram
            Status = $status
        }
    }

    $script:Snapshot = $newSnapshot
    $script:LastScan = Get-Date
}

# ------------------------------------------------------------
# DASHBOARD
# ------------------------------------------------------------

function Show-Dashboard {
    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "             COMPUTE MODE | PROCESS MANAGER" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    $visibility = if ($script:ShowProtected) { "VISIBLE" } else { "HIDDEN" }

    Write-Host ("Monitoring: ACTIVE     Protected: {0}     Time: {1}" -f `
        $visibility, (Get-Date -Format "HH:mm:ss"))
    Write-Host ""

    Write-Host ("{0,-5} {1,-8} {2,-24} {3,10} {4,12}" -f `
        "No.", "PID", "PROCESS NAME", "RAM (MB)", "STATUS")
    Write-Host ("-" * 68)

    $previousName = ""

    foreach ($p in $script:Snapshot) {
        if ($p.Name -eq $previousName) {
            $displayName = ",,"
        } else {
            $displayName = $p.Name
        }

        Write-Host ("{0,-5} {1,-8} {2,-24} {3,10} {4,12}" -f `
            $p.Number, $p.PID, $displayName, $p.RAM_MB, $p.Status)

        $previousName = $p.Name
    }

    Write-Host ""
    Write-Host "ACTIVITY LOG" -ForegroundColor Yellow
    Write-Host ("-" * 68)

    foreach ($entry in $script:Log) {
        Write-Host $entry
    }

    Write-Host ""
    Write-Host "COMMANDS" -ForegroundColor Cyan
    Write-Host " D(1,3-5)  Deny process names persistently"
    Write-Host " A(2,6)    Allow process names"
    Write-Host " F(2)      Force-stop selected process instance"
    Write-Host " F(2-5)    Force-stop selected instances"
    Write-Host " L         Refresh process list"
    Write-Host " P         Toggle protected-process visibility"
    Write-Host " ?         Show help"
    Write-Host " Q         Exit Compute Mode"
    Write-Host ""
    Write-Host "compute> " -NoNewline
    Write-Host $script:InputBuffer -NoNewline
}

# ------------------------------------------------------------
# RESOLVE NUMBERS AND RANGES
# ------------------------------------------------------------

function Resolve-Selection {
    param([string]$Expression)

    $result = @()

    foreach ($part in ($Expression -split ',')) {
        $part = $part.Trim()

        if ($part -match '^\d+$') {
            $n = [int]$part
            $result += @(
                $script:Snapshot | Where-Object Number -eq $n
            )
        }
        elseif ($part -match '^(\d+)\s*-\s*(\d+)$') {
            $start = [int]$Matches[1]
            $end = [int]$Matches[2]

            if ($end -lt $start) {
                throw "Invalid range: $part"
            }

            $result += @(
                $script:Snapshot | Where-Object {
                    $_.Number -ge $start -and $_.Number -le $end
                }
            )
        }
        else {
            throw "Invalid selection: $part"
        }
    }

    return @($result | Sort-Object Number -Unique)
}

# ------------------------------------------------------------
# SAFE PROCESS TERMINATION
# ------------------------------------------------------------

function Stop-Safely {
    param($Item)

    if ($script:ProtectedNames -contains $Item.Name) {
        Add-Log "BLOCKED: protected process $($Item.Name), PID $($Item.PID)."
        return
    }

    $current = Get-Process -Id $Item.PID

    if (-not $current -or $current.ProcessName -ne $Item.Name) {
        Add-Log "Skipped stale PID $($Item.PID). Refresh with L."
        return
    }

    try {
        Stop-Process -Id $Item.PID -Force -ErrorAction Stop
        Add-Log "Force-stopped $($Item.Name), PID $($Item.PID)."
    }
    catch {
        Add-Log "Could not stop $($Item.Name), PID $($Item.PID)."
    }
}

# ------------------------------------------------------------
# CONTINUOUS DENY RULE MONITORING
# ------------------------------------------------------------

function Apply-Rules {
    foreach ($p in @(Get-Process)) {
        $key = $p.ProcessName.ToLowerInvariant()

        if ($script:ProtectedNames -contains $p.ProcessName) {
            continue
        }

        if ($script:Allowed.ContainsKey($key)) {
            continue
        }

        if ($script:Denied.ContainsKey($key)) {
            Stop-Safely ([pscustomobject]@{
                PID  = $p.Id
                Name = $p.ProcessName
            })
        }
    }
}

# ------------------------------------------------------------
# FORCE-STOP COMMAND
# ------------------------------------------------------------

function Force-StopSelection {
    param([string]$Expression)

    try {
        $selected = @(Resolve-Selection $Expression)

        if ($selected.Count -eq 0) {
            Add-Log "No matching processes. Type L to refresh."
            return
        }

        foreach ($item in $selected) {
            Stop-Safely $item
        }

        Get-ProcessSnapshot
    }
    catch {
        Add-Log "Invalid force-stop selection: $($_.Exception.Message)"
        Add-Log "Use F(2), F(2-5), or F(1,3-5)."
    }
}

# ------------------------------------------------------------
# HELP MENU
# ------------------------------------------------------------

function Show-Help {
    Add-Log "AVAILABLE COMMANDS:"
    Add-Log "D(1,3-5) : Deny process names and target restarts."
    Add-Log "A(2,6)   : Allow process names and clear deny rules."
    Add-Log "F(2)     : Force-stop one selected process instance."
    Add-Log "F(2-5)   : Force-stop selected process instances."
    Add-Log "L        : Refresh the process list."
    Add-Log "P        : Toggle protected-process visibility."
    Add-Log "?        : Display this help menu."
    Add-Log "Q        : Exit Compute Mode."
}

# ------------------------------------------------------------
# COMMAND HANDLER
# ------------------------------------------------------------

function Handle-Command {
    param([string]$Command)

    $Command = $Command.Trim()

    if ($Command -match '^[Qq]$') {
        return $false
    }

    if ($Command -eq "?") {
        Show-Help
        return $true
    }

    if ($Command -match '^[Pp]$') {
        $script:ShowProtected = -not $script:ShowProtected
        Get-ProcessSnapshot

        if ($script:ShowProtected) {
            Add-Log "Protected processes are now visible."
        } else {
            Add-Log "Protected processes are now hidden."
        }

        return $true
    }

    if ($Command -match '^[Ll]$') {
        Get-ProcessSnapshot
        Add-Log "Process list refreshed."
        return $true
    }

    # Force-stop command.
    if ($Command -match '^[Ff]\s*\((.*)\)$') {
        Force-StopSelection $Matches[1]
        return $true
    }

    # Allow / deny commands.
    if ($Command -notmatch '^([AaDd])\s*\((.*)\)$') {
        Add-Log "Invalid command: $Command"
        Add-Log "Type ? to view available commands."
        return $true
    }

    $action = $Matches[1].ToUpperInvariant()
    $expression = $Matches[2]

    try {
        $selected = @(Resolve-Selection $expression)

        if ($selected.Count -eq 0) {
            Add-Log "No matching rows. Type L to refresh."
            return $true
        }

        foreach ($item in $selected) {
            $key = $item.Name.ToLowerInvariant()

            if ($script:ProtectedNames -contains $item.Name) {
                $script:Denied.Remove($key)
                $script:Allowed.Remove($key)
                Add-Log "Protected process selected: $($item.Name). Rule cleared."
                continue
            }

            if ($action -eq "A") {
                $script:Allowed[$key] = $true
                $script:Denied.Remove($key)
                Add-Log "Allowed process name: $($item.Name)."
            }
            else {
                $script:Allowed.Remove($key)
                $script:Denied[$key] = $true
                Add-Log "Denied process name: $($item.Name)."

                foreach ($p in @(Get-Process -Name $item.Name)) {
                    Stop-Safely ([pscustomobject]@{
                        PID  = $p.Id
                        Name = $p.ProcessName
                    })
                }
            }
        }

        Get-ProcessSnapshot
    }
    catch {
        Add-Log "Invalid selection: $($_.Exception.Message)"
        Add-Log "Type ? to view available commands."
    }

    return $true
}

# ------------------------------------------------------------
# MAIN PROGRAM
# ------------------------------------------------------------

Add-Log "Compute Mode started."
Get-ProcessSnapshot
Show-Dashboard

$running = $true

try {
    while ($running) {
        # Monitor denied processes without redrawing the dashboard.
        if (((Get-Date) - $script:LastScan).TotalSeconds -ge $script:RefreshSeconds) {
            Apply-Rules
            $script:LastScan = Get-Date
        }

        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)

            if ($key.Key -eq [ConsoleKey]::Enter) {
                $command = $script:InputBuffer
                $script:InputBuffer = ""

                if ($command.Trim()) {
                    $running = Handle-Command $command
                }

                if ($running) {
                    Show-Dashboard
                }
            }
            elseif ($key.Key -eq [ConsoleKey]::Backspace) {
                if ($script:InputBuffer.Length -gt 0) {
                    $script:InputBuffer = $script:InputBuffer.Substring(
                        0, $script:InputBuffer.Length - 1
                    )
                    Show-Dashboard
                }
            }
            elseif (-not [char]::IsControl($key.KeyChar)) {
                $script:InputBuffer += $key.KeyChar
                Write-Host $key.KeyChar -NoNewline
            }
        }

        Start-Sleep -Milliseconds 50
    }
}
finally {
    Write-Host "`nCompute Mode exited. Monitoring stopped."
    Write-Host "Remaining processes were left running."
}
