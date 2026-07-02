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
- **WMI-Based Auto Trigger**: Automated memory release triggers when usage exceeds the calculated threshold, complete with cooldown guards.
- **i18n & Log Scanning**: Dynamically parses English and Traditional Chinese Windows Event Logs (Event ID `2004`) at startup to identify heavy apps and recommend threshold levels. Auto-localizes UI to system language.
- **Auto-Start on Boot**: Supports registering via Task Scheduler with highest privileges (if run as Admin) or falling back to Registry Run keys (if run as standard user).
- **Settings GUI**: Modify the threshold and release mode directly from a native Windows Form dialog.
- **Log Rotation**: Logs all activities to `memory_opt.log`, automatically rotating and backing up when file size exceeds 2MB.
- **Duplicate Prevention**: Implements a system-wide named `Mutex` to prevent running duplicate instances.

---

## Directory Structure

```text
WinMemoryOpt/
├── MemoryOptimizer.ps1       # Main entry point & Mutex guard
├── test_runner.ps1           # Unit & integration verification script
├── LICENSE                   # MIT License
├── README.md                 # English documentation
├── README.zh-TW.md           # Traditional Chinese documentation
└── lib/
    ├── MemoryRelease.cs      # C# P/Invoke signatures & privilege helpers
    ├── MemoryOptimizerController.ps1 # Optimization logic & log rotation
    ├── EventLogAnalyzer.ps1  # Event log scanning & recommended thresholds
    ├── WmiTrigger.ps1        # WMI event listener registration
    └── TrayApp.ps1           # Windows Forms NotifyIcon & settings dialog
```

---

## Quick Start

### Running the Optimizer
Open a PowerShell console and execute the following command:
```powershell
Powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File ".\MemoryOptimizer.ps1"
```
*(Using `-WindowStyle Hidden` launches the tray app silently in the background without keeping a console window open).*

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

