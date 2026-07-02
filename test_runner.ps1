# Memory Optimizer Test Runner and Verification

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$libPath = Join-Path $scriptPath "lib"
$configPath = Join-Path $scriptPath "config.json"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Windows Memory Optimizer Verification & Test" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

$successAll = $true

# Test 1: Verify all files exist
Write-Host "`n[Test 1] Verifying project files existence..." -ForegroundColor Yellow
$files = @(
    "MemoryOptimizer.ps1",
    "lib\MemoryRelease.cs",
    "lib\MemoryOptimizerController.ps1",
    "lib\EventLogAnalyzer.ps1",
    "lib\WmiTrigger.ps1",
    "lib\TrayApp.ps1"
)
foreach ($file in $files) {
    $filePath = Join-Path $scriptPath $file
    if (Test-Path $filePath) {
        Write-Host "  [OK] File exists: $file" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] File missing: $file" -ForegroundColor Red
        $successAll = $false
    }
}

# Test 2: Compile P/Invoke library
Write-Host "`n[Test 2] Testing C# P/Invoke compilation..." -ForegroundColor Yellow
try {
    . (Join-Path $libPath "MemoryOptimizerController.ps1")
    if (([System.Management.Automation.PSTypeName]"WinMemoryOpt.MemoryHelper").Type) {
        Write-Host "  [OK] C# MemoryHelper class successfully compiled and loaded." -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] MemoryHelper class is not loaded." -ForegroundColor Red
        $successAll = $false
    }
} catch {
    Write-Host "  [FAIL] Compilation error: $_" -ForegroundColor Red
    $successAll = $false
}

# Test 3: Log Analyzer
Write-Host "`n[Test 3] Testing Windows Event Log Analyzer..." -ForegroundColor Yellow
try {
    . (Join-Path $libPath "EventLogAnalyzer.ps1")
    $analysis = Analyze-MemoryLogs -Days 7 -DefaultThreshold 80
    Write-Host "  [OK] Log Analyzer completed successfully." -ForegroundColor Green
    Write-Host "       - Recommended Threshold: $($analysis.RecommendedThreshold)%" -ForegroundColor Gray
    Write-Host "       - Low Memory Warnings Count (last 7 days): $($analysis.WarningsCount)" -ForegroundColor Gray
    Write-Host "       - Total Memory: $($analysis.TotalMemoryGB) GB" -ForegroundColor Gray
    Write-Host "       - Current Usage: $($analysis.CurrentUsagePercent)%" -ForegroundColor Gray
    if ($analysis.HeavyApps) {
        Write-Host "       - Top Heavy Apps identified:" -ForegroundColor Gray
        foreach ($app in $analysis.HeavyApps) {
            Write-Host "         * $($app.AppName): $($app.TotalMB) MB" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "  [FAIL] Event log analyzer error: $_" -ForegroundColor Red
    $successAll = $false
}

# Test 4: Memory Release functions (dry-run & execution check)
Write-Host "`n[Test 4] Testing Memory Release APIs (Public & Undocumented)..." -ForegroundColor Yellow

$modes = @("ProcessWorkingSet", "SystemStandbyList", "ModifiedPageList", "SystemWorkingSets", "Auto")
foreach ($mode in $modes) {
    try {
        Write-Host "  Testing Mode: $mode" -ForegroundColor Gray
        $res = Invoke-MemoryRelease -Mode $mode
        if ($res.Success) {
            Write-Host "    [OK] Mode '$mode' executed successfully." -ForegroundColor Green
            Write-Host "         Reclaimed: $($res.ReclaimedMB) MB | Detail: $($res.Details)" -ForegroundColor Gray
        } else {
            # Some undocumented APIs might fail if not elevated, but we catch and check it
            if ($res.Details -like "*AccessDenied*" -or $res.Details -like "*Privilege*") {
                Write-Host "    [WARN] Mode '$mode' returned access denied (requires Admin rights, expected behavior under normal user)." -ForegroundColor Yellow
            } else {
                Write-Host "    [FAIL] Mode '$mode' failed: $($res.Details)" -ForegroundColor Red
                $successAll = $false
            }
        }
    } catch {
        Write-Host "    [FAIL] Mode '$mode' threw exception: $_" -ForegroundColor Red
        $successAll = $false
    }
}

# Test 5: WMI Event Registration Setup
Write-Host "`n[Test 5] Testing WMI Event Registration syntax..." -ForegroundColor Yellow
try {
    . (Join-Path $libPath "WmiTrigger.ps1")
    # Register with a dummy scriptblock
    Register-MemoryWmiEvent -ThresholdPercent 99 -Action { Write-Host "WMI Event Fired" }
    
    # Verify the event subscription exists
    $sub = Get-EventSubscriber -SourceIdentifier "MemoryThresholdEvent" -ErrorAction SilentlyContinue
    if ($sub) {
        Write-Host "  [OK] WMI Event Trigger successfully registered." -ForegroundColor Green
        # Clean up
        Unregister-MemoryWmiEvent
        Write-Host "  [OK] WMI Event Trigger successfully cleaned up." -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] WMI Event Trigger subscription not found." -ForegroundColor Red
        $successAll = $false
    }
} catch {
    Write-Host "  [FAIL] WMI registration error: $_" -ForegroundColor Red
    $successAll = $false
}

# Test 6: Configuration read/write test
Write-Host "`n[Test 6] Testing Configuration handling..." -ForegroundColor Yellow
try {
    $tempConfig = [PSCustomObject]@{
        Threshold = 75
        Mode = "SystemStandbyList"
        EventLogDays = 14
        PollIntervalSeconds = 10
    }
    $tempConfig | ConvertTo-Json | Out-File $configPath -Force
    $loaded = Get-Content $configPath | ConvertFrom-Json
    if ($loaded.Threshold -eq 75 -and $loaded.Mode -eq "SystemStandbyList") {
        Write-Host "  [OK] Configuration read/write verification succeeded." -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Loaded configuration values mismatch." -ForegroundColor Red
        $successAll = $false
    }
} catch {
    Write-Host "  [FAIL] Configuration file operation error: $_" -ForegroundColor Red
    $successAll = $false
}

Write-Host "`n=============================================" -ForegroundColor Cyan
if ($successAll) {
    Write-Host "ALL TESTS AND FEATURE VERIFICATIONS PASSED!" -ForegroundColor Green
} else {
    Write-Host "SOME TESTS FAILED. Please review output." -ForegroundColor Red
}
Write-Host "=============================================" -ForegroundColor Cyan




