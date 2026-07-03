$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "Please run this script as Administrator!"
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$taskName = "WindowsMemoryOptimizer"
$exePath = Join-Path $PSScriptRoot "WinMemoryOpt.exe"

if (-not (Test-Path $exePath)) {
    Write-Error "WinMemoryOpt.exe not found! Please run Build-Exe.ps1 first."
    Pause
    exit
}

# 1. Ensure Task Scheduler task exists and points to the EXE
Write-Host "Configuring Scheduled Task for UAC bypass..."
$action = New-ScheduledTaskAction -Execute $exePath
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 0) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

# 2. Create Desktop Shortcut
$wshShell = New-Object -ComObject WScript.Shell
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktopPath "WinMemory Optimizer.lnk"

$shortcut = $wshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "schtasks.exe"
$shortcut.Arguments = "/run /tn `"$taskName`""
$shortcut.WindowStyle = 7 # Minimized
$shortcut.IconLocation = "C:\Windows\System32\taskmgr.exe,0" # Fallback nice icon if exe doesn't have one
$shortcut.Description = "Launch Windows Memory Optimizer (No UAC)"
$shortcut.Save()

Write-Host "==============================================" -ForegroundColor Green
Write-Host "Success! Desktop shortcut created." -ForegroundColor Green
Write-Host "You can now double-click 'WinMemory Optimizer' on your desktop to launch without warnings." -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Green


