# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Auto-detach functionality for background execution via `MemoryOptimizer.ps1`.
- Setup simple installation script `Install.ps1`.
- GitHub Actions CI/CD for script analysis and automated release packaging.
- Community health files (CONTRIBUTING, ISSUE_TEMPLATE).

### Changed
- All PowerShell scripts explicitly set to UTF-8 BOM encoding for Windows PowerShell 5.1 compatibility.
- Scheduled task path wrappers use double quotes to prevent path injection.

### Fixed
- Fixed WMI Trigger printing Job output to the console during startup.
- Fixed `System.Windows.Forms.Application::Run()` hanging behavior in `TrayApp.ps1` by removing hidden Form wrapper.
