param (
    [switch]$Background
)

if (-not $Background) {
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -Background" -WindowStyle Hidden
    exit
}

# Windows Memory Optimizer startup entrypoint

# Prevent duplicate executions using a system-wide Mutex
$createdNew = $false
$global:OptimizerMutex = New-Object System.Threading.Mutex($true, "Global\WinMemoryOptimizerMutex", [ref]$createdNew)
if (-not $createdNew) {
    Add-Type -AssemblyName System.Windows.Forms
    $culture = [System.Globalization.CultureInfo]::CurrentCulture.Name
    $msgText = "Windows Memory Optimizer is already running. Please check the system tray."
    $msgTitle = "Program Already Running"
    if ($culture -like "zh-*") {
        $msgText = "Windows Memory Optimizer 已在執行中，請在右下角系統匣查看圖示。"
        $msgTitle = "程式已在執行中"
    }
    [System.Windows.Forms.MessageBox]::Show($msgText, $msgTitle, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    exit
}

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$libPath = Join-Path $scriptPath "lib"
$configPath = Join-Path $scriptPath "config.json"

# Set up logging and libraries
. (Join-Path $libPath "EventLogAnalyzer.ps1")
. (Join-Path $libPath "MemoryOptimizerController.ps1")

Write-OptLog "INFO" "============================================="
Write-OptLog "INFO" "Starting Windows Memory Optimizer Initialization..."

# Default settings
$defaultThreshold = 80
$eventLogDays = 7

# Parse configuration if exists
if (Test-Path $configPath) {
    $config = Get-Content $configPath | ConvertFrom-Json
    $defaultThreshold = $config.Threshold
    $eventLogDays = $config.EventLogDays
} else {
    $config = [PSCustomObject]@{
        Threshold = $defaultThreshold
        Mode = "Auto"
        EventLogDays = $eventLogDays
        PollIntervalSeconds = 5
    }
    $config | ConvertTo-Json | Out-File $configPath -Encoding utf8
}

# 1. Analyze Event Logs
$analysis = Analyze-MemoryLogs -Days $eventLogDays -DefaultThreshold $defaultThreshold

Write-OptLog "INFO" "Recommended trigger threshold from logs: $($analysis.RecommendedThreshold)%"
Write-OptLog "INFO" "Total visible memory: $($analysis.TotalMemoryGB) GB"
Write-OptLog "INFO" "Current memory usage: $($analysis.CurrentUsagePercent)%"

if ($analysis.HeavyApps) {
    Write-OptLog "INFO" "Top memory consuming apps identified from event logs:"
    foreach ($app in $analysis.HeavyApps) {
        Write-OptLog "INFO" "  - $($app.AppName): $($app.TotalMB) MB"
    }
}

# Update config with recommended threshold
$config.Threshold = $analysis.RecommendedThreshold
$config | ConvertTo-Json | Out-File $configPath -Force -Encoding utf8

Write-OptLog "INFO" "Configuration updated. Starting System Tray UI..."

# 2. Launch Tray App
. (Join-Path $libPath "TrayApp.ps1") -ConfigPath $configPath





