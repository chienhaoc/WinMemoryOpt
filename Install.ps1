param (
    [switch]$Uninstall
)

# Enforce Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Please run this script as Administrator."
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
Copy-Item -Path "$PSScriptRoot\*" -Destination $installDir -Recurse -Force -Exclude "Install.ps1", ".git", ".github"

# 2. Create Start Menu Shortcut
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$installDir\MemoryOptimizer.ps1`""
$Shortcut.WorkingDirectory = $installDir
$Shortcut.WindowStyle = 7 # Minimized
$Shortcut.IconLocation = "shell32.dll,22" # Default system icon (gears)
$Shortcut.Save()

# 3. Launch App to initialize registry/scheduled tasks
Write-Host "Launching WinMemoryOpt to finalize setup..."
Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$installDir\MemoryOptimizer.ps1`"" -WindowStyle Hidden

Write-Host "Installation complete! The optimizer is now running in the system tray." -ForegroundColor Green

