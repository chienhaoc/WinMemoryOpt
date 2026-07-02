function Analyze-MemoryLogs {
    param (
        [int]$Days = 7,
        [int]$DefaultThreshold = 80
    )

    Write-OptLog "INFO" "Starting Windows Event Log analysis..."

    $heavyApps = @{}
    $warningsCount = 0
    $threshold = $DefaultThreshold

    try {
        # Event ID 2004 is Windows Resource-Exhaustion-Detector
        $startTime = (Get-Date).AddDays(-$Days)
        $events = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            Id = 2004
            StartTime = $startTime
        } -ErrorAction SilentlyContinue

        if ($events) {
            $warningsCount = $events.Count
            Write-OptLog "INFO" "Found $warningsCount low-memory warnings in the last $Days days."

            foreach ($event in $events) {
                $message = $event.Message
                # Regex to extract process names and memory consumption
                # Format is typically: "process.exe (PID) consumed X bytes" or similar in OS logs
                # Support both English ("consumed X bytes") and Traditional Chinese ("消耗了 X 位元組")
                $matches = [regex]::Matches($message, '(?i)([a-zA-Z0-9_\-\.]+)\s*\(\d+\)\s*(?:consumed|消耗了)\s*(\d+)\s*(?:bytes|位元組)')
                foreach ($match in $matches) {
                    $appName = $match.Groups[1].Value
                    $bytes = [double]$match.Groups[2].Value
                    if ($heavyApps.ContainsKey($appName)) {
                        $heavyApps[$appName] += $bytes
                    } else {
                        $heavyApps[$appName] = $bytes
                    }
                }
            }
        } else {
            Write-OptLog "INFO" "No Windows Resource-Exhaustion-Detector warnings found in the last $Days days."
        }
    } catch {
        Write-OptLog "WARN" "Could not read Windows Event Logs (might require Administrator privileges). Using default threshold logic."
    }

    # Analyze physical memory size to adjust threshold
    $osInfo = Get-CimInstance Win32_OperatingSystem
    $totalMemoryGB = [Math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 2)
    $freeMemoryGB = [Math]::Round($osInfo.FreePhysicalMemory / 1MB, 2)
    $currentUsagePercent = [Math]::Round((($osInfo.TotalVisibleMemorySize - $osInfo.FreePhysicalMemory) / $osInfo.TotalVisibleMemorySize) * 100, 2)

    Write-OptLog "INFO" "Current physical memory usage: $currentUsagePercent% ($freeMemoryGB GB free of $totalMemoryGB GB total)"

    # If we have low-memory warnings, set a more aggressive threshold
    if ($warningsCount -gt 5) {
        $threshold = 75
        Write-OptLog "INFO" "High frequency of low-memory warnings. Recommending aggressive threshold: $threshold%"
    } elseif ($warningsCount -gt 0) {
        $threshold = 80
        Write-OptLog "INFO" "Low-memory warnings detected. Recommending threshold: $threshold%"
    } else {
        $threshold = $DefaultThreshold
        Write-OptLog "INFO" "System appears stable. Recommending default threshold: $threshold%"
    }

    # Format heavy apps output for report
    $heavyAppsReport = @()
    if ($heavyApps.Count -gt 0) {
        $heavyAppsReport = $heavyApps.GetEnumerator() | 
            Sort-Object Value -Descending | 
            Select-Object -First 5 | 
            ForEach-Object {
                [PSCustomObject]@{
                    AppName = $_.Key
                    TotalBytesConsumed = $_.Value
                    TotalMB = [Math]::Round($_.Value / 1MB, 2)
                }
            }
    }

    return [PSCustomObject]@{
        RecommendedThreshold = $threshold
        WarningsCount = $warningsCount
        TotalMemoryGB = $totalMemoryGB
        CurrentUsagePercent = $currentUsagePercent
        HeavyApps = $heavyAppsReport
    }
}






