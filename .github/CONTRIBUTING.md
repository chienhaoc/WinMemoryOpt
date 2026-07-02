# Contributing to WinMemoryOpt

First off, thank you for considering contributing to WinMemoryOpt! It's people like you that make WinMemoryOpt such a great tool.

## Where do I go from here?

If you've noticed a bug or have a feature request, make sure to check our [Issues](https://github.com/chienhaoc/WinMemoryOpt/issues) to see if someone else has already created a ticket. If not, go ahead and [make one](https://github.com/chienhaoc/WinMemoryOpt/issues/new/choose)!

## Setting up your environment

1. Fork the repo and clone it to your local machine.
2. We highly recommend using VSCode with the PowerShell Extension.
3. Ensure you have `PSScriptAnalyzer` installed: `Install-Module PSScriptAnalyzer -Scope CurrentUser`
4. Run `Invoke-ScriptAnalyzer .\ -Recurse` before submitting any PRs to ensure code quality.

## Pull Request Process

1. Create a new branch for your feature or bugfix.
2. Commit your changes using descriptive commit messages.
3. Ensure all `.ps1` files are saved with **UTF-8 with BOM** encoding (CRITICAL for Windows PowerShell 5.1).
4. Update the `CHANGELOG.md` with your changes.
5. Push to your fork and submit a Pull Request!
