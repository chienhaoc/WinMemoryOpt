$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$csPath = Join-Path $scriptPath "MemoryRelease.cs"

# Compile P/Invoke type if not already loaded
if (-not ([System.Management.Automation.PSTypeName]"WinMemoryOpt.MemoryHelper").Type) {
    try {
        Add-Type -TypeDefinition (Get-Content $csPath -Raw)
    } catch {
        Write-Error "Failed to compile P/Invoke memory release library: $_"
    }
}

function Write-OptLog {
    param (
        [string]$Level = "INFO",
        [string]$Message
    )
    $logPath = "$((Split-Path -Parent $PSScriptRoot))\memory_opt.log"
    
    # Log Rotation: Rotate log if file size exceeds 2MB
    try {
        if (Test-Path $logPath) {
            $fileInfo = Get-Item $logPath
            if ($fileInfo.Length -gt 2MB) {
                $bakPath = "$((Split-Path -Parent $PSScriptRoot))\memory_opt.log.bak"
                if (Test-Path $bakPath) { Remove-Item $bakPath -Force }
                Rename-Item $logPath "memory_opt.log.bak" -Force
            }
        }
    } catch {
        # Fallback silently if rename fails (e.g. file lock)
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] [$Level] $Message" | Out-File -FilePath $logPath -Append -Encoding utf8
}

function Get-HeavyProcesses {
    param(
        [int]$TopCount = 3,
        [long]$MinWorkingSetMB = 500
    )
    # Get processes actively consuming more than MinWorkingSetMB
    $processes = Get-Process | Where-Object { ($_.WorkingSet64 / 1MB) -gt $MinWorkingSetMB } | Sort-Object WorkingSet64 -Descending | Select-Object -First $TopCount
    $results = @()
    foreach ($p in $processes) {
        $results += [PSCustomObject]@{
            Name = $p.ProcessName
            Id = $p.Id
            WorkingSetMB = [Math]::Round($p.WorkingSet64 / 1MB, 2)
        }
    }
    return $results
}

function Invoke-MemoryRelease {
    param (
        [string]$Mode = "Auto"
    )

    Write-OptLog "INFO" "Memory release triggered. Mode: $Mode"
    
    # Get initial memory state
    $osBefore = Get-CimInstance Win32_OperatingSystem
    $memBefore = $osBefore.FreePhysicalMemory / 1KB # in MB
    $totalMem = $osBefore.TotalVisibleMemorySize / 1KB

    $success = $true
    $details = ""

    # Real-Time Active Response Strategy: Detect and log heavy apps before trimming
    $heavyProcs = Get-HeavyProcesses -TopCount 3 -MinWorkingSetMB 500
    if ($heavyProcs.Count -gt 0) {
        $heavyProcNames = ($heavyProcs | ForEach-Object { "$($_.Name) ($($_.WorkingSetMB) MB)" }) -join ", "
        Write-OptLog "WARN" "Active Response: Detected heavy applications running: $heavyProcNames. Preparing aggressive trim."
    }

    try {
        switch ($Mode) {
            "ProcessWorkingSet" {
                $count = [WinMemoryOpt.MemoryHelper]::PurgeWorkingSets()
                $details = "Trimmed working sets of $count processes."
            }
            "SystemStandbyList" {
                $status = [WinMemoryOpt.MemoryHelper]::PurgeStandbyList($false)
                $details = "Purged standby list. status: 0x$($status.ToString("X"))"
            }
            "ModifiedPageList" {
                $status = [WinMemoryOpt.MemoryHelper]::FlushModifiedPageList()
                $details = "Flushed modified page list. status: 0x$($status.ToString("X"))"
            }
            "SystemWorkingSets" {
                $status = [WinMemoryOpt.MemoryHelper]::PurgeSystemWorkingSets()
                $details = "Purged system-wide working sets. status: 0x$($status.ToString("X"))"
            }
            "Auto" {
                # Auto mode:
                # 1. First trim process working sets to reclaim user space memory
                $count = [WinMemoryOpt.MemoryHelper]::PurgeWorkingSets()
                
                # 2. Purge Standby lists (undocumented API)
                $statusStandby = [WinMemoryOpt.MemoryHelper]::PurgeStandbyList($false)
                
                # 3. Flush modified page list (undocumented API)
                $statusMod = [WinMemoryOpt.MemoryHelper]::FlushModifiedPageList()
                
                $details = "Auto mode: Trimmed $count processes, Standby status: 0x$($statusStandby.ToString("X")), Modified status: 0x$($statusMod.ToString("X"))"
            }
            Default {
                Write-OptLog "WARN" "Unknown release mode: $Mode. Defaulting to Auto."
                $count = [WinMemoryOpt.MemoryHelper]::PurgeWorkingSets()
                $details = "Default mode: Trimmed $count processes."
            }
        }

        # Get final memory state
        $osAfter = Get-CimInstance Win32_OperatingSystem
        $memAfter = $osAfter.FreePhysicalMemory / 1KB
        $saved = [Math]::Round($memAfter - $memBefore, 2)
        $percentageUsageBefore = [Math]::Round((($totalMem - $memBefore) / $totalMem) * 100, 1)
        $percentageUsageAfter = [Math]::Round((($totalMem - $memAfter) / $totalMem) * 100, 1)

        Write-OptLog "SUCCESS" "$details Reclaimed: $saved MB. Memory usage went from $percentageUsageBefore% to $percentageUsageAfter%."
        return [PSCustomObject]@{
            Success = $true
            ReclaimedMB = $saved
            Details = $details
            UsageBefore = $percentageUsageBefore
            UsageAfter = $percentageUsageAfter
            HeavyApps = if ($heavyProcs.Count -gt 0) { $heavyProcNames } else { $null }
        }
    }
    catch {
        Write-OptLog "ERROR" "Failed to execute memory release: $_"
        return [PSCustomObject]@{
            Success = $false
            ReclaimedMB = 0
            Details = "Error: $_"
            UsageBefore = 0
            UsageAfter = 0
            HeavyApps = $null
        }
    }
}

function Invoke-DecisionEngine {
    # 5. Health Gate (健康狀態閘門)
    $os = Get-CimInstance Win32_OperatingSystem
    $totalMem = $os.TotalVisibleMemorySize
    $freeMem = $os.FreePhysicalMemory
    $currentUsagePercent = [Math]::Round((($totalMem - $freeMem) / $totalMem) * 100, 2)
    
    if ($currentUsagePercent -lt 60) {
        Write-OptLog "DEBUG" "Logic -> Memory usage is below 60% ($currentUsagePercent%). Healthy state, action aborted."
        return $false
    }
    
    # 3. Dynamic Defense Posture (防禦姿態分級)
    $defensePosture = "Standard"
    if ($script:WarningsCount -gt 5) { $defensePosture = "Aggressive" }
    elseif ($script:WarningsCount -gt 0) { $defensePosture = "Guarded" }
    
    Write-OptLog "INFO" "Logic -> Triggered Optimization. Defense Posture: $defensePosture. Current Usage: $currentUsagePercent%"
    
    # 2. Universal Foreground App Protection (全模式前景保護)
    $fgPid = [WinMemoryOpt.MemoryHelper]::GetForegroundProcessId()
    $fgProc = $null
    if ($fgPid -gt 0) {
        try { $fgProc = Get-Process -Id $fgPid -ErrorAction SilentlyContinue } catch {}
        if ($fgProc) {
            Write-OptLog "INFO" "Action -> Protecting foreground app: $($fgProc.Name) (PID: $fgPid)"
        }
    }

    # 1. Per-Process API Selection (分級式 API 策略引擎) & 4. Decision Audit Trail (決策審計日誌)
    $heavyProcs = Get-HeavyProcesses -TopCount 10 -MinWorkingSetMB 200
    
    # Known bad actors db (BadAppsDB)
    $badApps = @("chrome", "msedge", "devenv", "Code", "Discord", "Teams")
    
    foreach ($p in $heavyProcs) {
        if ($fgProc -and $p.Id -eq $fgProc.Id) {
            Write-OptLog "INFO" "Action -> Skipped: $($p.Name) (PID: $($p.Id)) | Rule: Foreground App Protection"
            continue
        }
        
        if ($badApps -contains $p.Name) {
            # Heavy suppression for known memory hogs
            [WinMemoryOpt.MemoryHelper]::PurgeProcessWorkingSetById($p.Id) | Out-Null
            Write-OptLog "INFO" "Action -> Suppressing: $($p.Name) (PID: $($p.Id)) | Rule: Matched BadAppsDB (Currently $($p.WorkingSetMB) MB)"
        } else {
            # Gentle trimming for normal heavy apps
            try {
                $proc = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
                if ($proc) {
                    [WinMemoryOpt.MemoryHelper]::EmptyWorkingSet($proc.Handle) | Out-Null
                    Write-OptLog "INFO" "Action -> Micro-optimizing: $($p.Name) (PID: $($p.Id)) | Rule: WorkingSet > 200MB (Currently $($p.WorkingSetMB) MB)"
                }
            } catch {}
        }
    }

    # Finally, purge global OS cache
    $statusStandby = [WinMemoryOpt.MemoryHelper]::PurgeStandbyList($false)
    Write-OptLog "INFO" "Action -> Purging OS Cache | Rule: Defense Posture Sweep. Standby status: 0x$($statusStandby.ToString("X"))"
    
    $osAfter = Get-CimInstance Win32_OperatingSystem
    $memAfter = $osAfter.FreePhysicalMemory / 1KB
    $saved = [Math]::Round($memAfter - ($freeMem / 1KB), 2)
    Write-OptLog "SUCCESS" "Decision Engine completed. Reclaimed: $saved MB."
    
    return [PSCustomObject]@{
        Success = $true
        ReclaimedMB = $saved
    }
}








