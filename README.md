# Windows Memory Optimizer (WinMemoryOpt)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue.svg)](#)

A lightweight, PowerShell-wrapped background memory optimization utility for Windows. It runs quietly in the system tray, monitors physical memory via WMI, and reclaims memory using both documented Win32 APIs and undocumented Windows NT system APIs.

---

## Features

- **Dynamic System Tray Icon (Premium UI)**: Displays live memory usage directly on the icon, color-coded by load (Green < 70%, Orange < 85%, Red >= 85%).
- **Multi-Mode Optimization**:
  - **Process Working Set Trimming** (Public Win32 API): Iterates and trims the working sets of processes.
  - **Standby Memory List Purging** (Undocumented NT API): Clears system standby caches.
  - **Modified Page List Flushing** (Undocumented NT API): Flushes modified pages to disk.
- **1-Click Focus/Gaming Mode**: Provides a delayed 5-second trigger to lock onto your foreground app, automatically aggressively compressing the memory of resource-heavy background apps (e.g., Chrome, Discord) and applying Windows 11's **EcoQoS Efficiency Mode** (Power Throttling) to squeeze out maximum CPU/RAM performance for your game or intensive work.
- **Targeted App Trimmer**: A real-time leaderboard of high-consuming background apps inside the Settings dialog, allowing you to precision-trim memory for a single out-of-control application with one click.
- **WMI-Based Auto Trigger**: Automated memory release triggers when usage exceeds the calculated threshold, complete with cooldown guards.
- **i18n & Log Scanning**: Dynamically parses English and Traditional Chinese Windows Event Logs (Event ID `2004`) at startup to identify heavy apps and recommend threshold levels. Auto-localizes UI to system language.
- **Auto-Start on Boot**: Supports registering via Task Scheduler with highest privileges (if run as Admin) or falling back to Registry Run keys (if run as standard user).
- **Settings GUI**: Modify the threshold and release mode directly from a native Windows Form dialog.
- **Log Rotation**: Logs all activities to `memory_opt.log`, automatically rotating and backing up when file size exceeds 2MB.
- **Duplicate Prevention**: Implements a system-wide named `Mutex` to prevent running duplicate instances.
- **Auto-Detach Execution**: Running `MemoryOptimizer.ps1` automatically detects the environment and spawns a detached background process, returning control to your terminal immediately.
- **Enterprise-Grade Infrastructure**: Includes a 1-click `Install.ps1` setup script, a full GitHub Actions CI/CD pipeline (Linting & Auto-Releases), and Community Health standard files (Issue Templates, Contributing Guidelines).

---

## Directory Structure

```text
WinMemoryOpt/
├── Install.ps1               # 1-Click Installation & Uninstallation script
├── MemoryOptimizer.ps1       # Main entry point, Mutex guard & Auto-Detach launcher
├── test_runner.ps1           # Unit & integration verification script
├── LICENSE                   # MIT License
├── README.md                 # English documentation
├── README.zh-TW.md           # Traditional Chinese documentation
├── CHANGELOG.md              # Project version history
├── .github/                  # CI/CD Workflows, Issue Templates & Contributing Guidelines
└── lib/
    ├── MemoryRelease.cs      # C# P/Invoke signatures & privilege helpers
    ├── MemoryOptimizerController.ps1 # Optimization logic & log rotation
    ├── EventLogAnalyzer.ps1  # Event log scanning & recommended thresholds
    ├── WmiTrigger.ps1        # WMI event listener registration
    └── TrayApp.ps1           # Windows Forms NotifyIcon & settings dialog
```

---

## Quick Start

### Installation (Recommended)
Simply right-click `Install.ps1` and select **Run with PowerShell** (or run it as Administrator in a console).
It will automatically:
1. Copy the application to `C:\Program Files\WinMemoryOpt`.
2. Create a Start Menu shortcut.
3. Launch the background system tray app.

*To uninstall, simply run `.\Install.ps1 -Uninstall`.*

### Manual Quick Start
Open a PowerShell console and execute:
```powershell
.\MemoryOptimizer.ps1
```
*(The script features **Auto-Detach**. It will silently spawn a hidden background process and return your terminal prompt instantly.)*

### Permissions Note
WinMemoryOpt runs smoothly under both **Administrator** and **Standard User** accounts:
- **As Administrator**: The app can optimize background services and clear system-wide caches using undocumented NT APIs.
- **As Standard User**: The app gracefully falls back to trimming user-owned application working sets (which usually consume the bulk of RAM) and logging status warnings for elevated calls.

---

## Interactions

- **Hover**: Shows a compact status tooltip with current usage, active threshold, and cumulative release count.
- **Double-Click**: Pops up a detailed system notification balloon with full memory stats.
- **Right-Click**: Opens the context menu to toggle automated WMI monitoring, configure auto-start, open the Settings Form, scan event logs, query logs, or exit.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

