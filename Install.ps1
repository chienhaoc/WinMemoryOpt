param (
    [switch]$Uninstall
)

# Enforce Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Please run this script as Administrator."
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$installDir = "C:\Program Files\WinMemoryOpt"
$shortcutPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\WinMemoryOpt.lnk"

if ($Uninstall) {
    Write-Host "Uninstalling WinMemoryOpt..."
    # 1. Stop background process
    Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match "MemoryOptimizer.ps1" } | Stop-Process -Force -ErrorAction SilentlyContinue
    
    # 2. Remove Scheduled Task
    Unregister-ScheduledTask -TaskName "WindowsMemoryOptimizer" -Confirm:$false -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "WindowsMemoryOptimizer" -ErrorAction SilentlyContinue
    
    # 3. Remove Shortcut
    if (Test-Path $shortcutPath) { Remove-Item $shortcutPath -Force }
    
    # 4. Remove Files
    if (Test-Path $installDir) { Remove-Item $installDir -Recurse -Force }
    
    Write-Host "Uninstallation complete." -ForegroundColor Green
    exit
}

Write-Host "Installing WinMemoryOpt..."

# 1. Create directory and copy files
if (-not (Test-Path $installDir)) {
    New-Item -Path $installDir -ItemType Directory | Out-Null
}
Copy-Item -Path "$PSScriptRoot\*" -Destination $installDir -Recurse -Force -Exclude "Install.ps1", ".git", ".github", "Create-Shortcut.ps1"

# Check if EXE exists, otherwise fallback to PS1
$exePath = Join-Path $installDir "WinMemoryOpt.exe"
$hasExe = Test-Path $exePath

# 2. Configure UAC-Bypass Scheduled Task
Write-Host "Configuring Scheduled Task for UAC bypass..."
$taskName = "WindowsMemoryOptimizer"
if ($hasExe) {
    $action = New-ScheduledTaskAction -Execute $exePath
} else {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$installDir\MemoryOptimizer.ps1`" -Background"
}
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 0) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

# 3. Create UAC-Bypassed Shortcuts
$WshShell = New-Object -ComObject WScript.Shell

# Start Menu Shortcut
$smShortcut = $WshShell.CreateShortcut($shortcutPath)
$smShortcut.TargetPath = "schtasks.exe"
$smShortcut.Arguments = "/run /tn `"$taskName`""
$smShortcut.WindowStyle = 7
$smShortcut.IconLocation = "C:\Windows\System32\taskmgr.exe,0"
$smShortcut.Save()

# Desktop Shortcut
$desktopPath = [Environment]::GetFolderPath("Desktop")
$dtShortcut = $WshShell.CreateShortcut((Join-Path $desktopPath "WinMemory Optimizer.lnk"))
$dtShortcut.TargetPath = "schtasks.exe"
$dtShortcut.Arguments = "/run /tn `"$taskName`""
$dtShortcut.WindowStyle = 7
$dtShortcut.IconLocation = "C:\Windows\System32\taskmgr.exe,0"
$dtShortcut.Save()

# 4. Launch App
Write-Host "Launching WinMemoryOpt to finalize setup..."
schtasks /run /tn $taskName | Out-Null

Write-Host "Installation complete! The optimizer is now running quietly in the system tray." -ForegroundColor Green





