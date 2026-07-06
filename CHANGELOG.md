# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-07-06

### Added
- **Smart Decision Engine**: Replaced the previous basic trigger with a sophisticated `DecisionEngine` that runs safely within the UI thread to bypass WMI event blocking.
- **Per-Process API Selection**: Implemented a `BadAppsDB` list. Known memory hogs (Chrome, Edge, VS Code, Discord, Teams) are aggressively suppressed, while standard apps receive gentle trimming.
- **Universal Foreground Protection**: The engine now actively detects and skips the foreground application using `GetForegroundProcessId()`, guaranteeing zero stutter during active use.
- **Dynamic Defense Posture**: The system now dynamically shifts between `Standard`, `Guarded`, and `Aggressive` postures based on historical crash counts from Windows Event Logs.
- **Decision Audit Trail**: The log file now provides structured reasoning for every action (e.g., `Action -> Suppressing: chrome.exe | Rule: Matched BadAppsDB`).
- **Health Gate**: Added a hard 60% memory usage gate inside the decision logic to completely eliminate edge-case oscillation and event storms.

### Fixed
- **Critical Blocking Bug**: Fixed an issue where the WMI `__InstanceModificationEvent` was successfully detecting memory spikes but the action block was permanently suspended by the `[System.Windows.Forms.Application]::Run()` UI loop. The trigger mechanism now uses the synchronous UI timer.

## [1.0.0] - 2026-07-04

### Added
- **Focus Mode**: A one-click mode that forces background applications into a low-resource state. Includes a 5-second delayed activation to allow users to switch to their target foreground application.
- **EcoQoS Integration**: Implemented Windows 11 EcoQoS API (`SetProcessInformation` with `PROCESS_POWER_THROTTLING_STATE`) to place background apps in Efficiency Mode.
- **Targeted Trimmer**: A UI feature displaying the top 5 memory-consuming processes, allowing users to manually trim specific applications.
- **WMI Event Subscription**: Replaced CPU-intensive polling with a lightweight WMI Event Subscription mechanism to monitor available memory.
- **Log-Based Recommendation**: Automatic analysis of Windows Event Logs (Event ID 2004) to recommend an optimal memory optimization threshold.
- **Native Executable Wrapper**: Dynamic compilation of `WinMemoryOpt.exe` using `csc.exe` to provide a seamless, console-free launch experience.
- **Zero-UAC Installation**: Integrated Task Scheduler into the `Install.ps1` script to allow the tool to run silently in the background with administrative privileges without UAC prompts.
- **Dynamic System Tray Icon**: The tray icon now changes color (Green/Orange/Red) dynamically based on the current memory availability state.
- **Automated Setup**: Added `Install.ps1` and `Uninstall.ps1` for easy lifecycle management.
- **CI/CD Pipeline**: GitHub Actions for script analysis and automated release packaging.
- **Localization**: Added Traditional Chinese documentation (`README.zh-TW.md`).
- **Community Health**: Added `CONTRIBUTING.md` and Issue templates.

### Changed
- **Encoding Standards**: All PowerShell scripts explicitly set to UTF-8 BOM encoding to ensure full compatibility with Windows PowerShell 5.1 and multi-language environments.
- **Security Enhancements**: Scheduled task path wrappers now use double quotes to prevent path injection vulnerabilities.

### Fixed
- Fixed an issue where the `ProcessInformationClass` enum value for EcoQoS was incorrectly set to `11` instead of `4`.
- Fixed variable scoping issues (`$this` vs `$sender`) in PowerShell Event Handlers for the system tray.
- Fixed an application crash caused by attempting to overwrite the read-only `$PID` variable during process iteration.
- Fixed WMI Trigger printing Job output to the console during startup.
- Fixed `System.Windows.Forms.Application::Run()` hanging behavior in `TrayApp.ps1` by removing the hidden Form wrapper.
