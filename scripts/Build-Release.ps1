# Build-Release.ps1
# Automates compiling, zipping, and generating WinGet manifests for WinMemoryOpt

$scriptPath = $PSScriptRoot
if (-not $scriptPath) { $scriptPath = $PWD.Path }
$projectRoot = Split-Path -Parent $scriptPath

Write-Host "--- Starting Release Build Workflow ---" -ForegroundColor Cyan

# 1. Clean previous build directories
$distDir = Join-Path $projectRoot "dist"
$manifestsDir = Join-Path $projectRoot "manifests\o\Optico\WinMemoryOpt\1.1.0"
$zipFile = Join-Path $projectRoot "WinMemoryOpt.zip"

if (Test-Path $distDir) { Remove-Item $distDir -Recurse -Force }
if (Test-Path $manifestsDir) { Remove-Item $manifestsDir -Recurse -Force }
if (Test-Path $zipFile) { Remove-Item $zipFile -Force }

# 2. Compile executable wrapper
Write-Host "Compiling executable wrapper..." -ForegroundColor Yellow
$compileScript = Join-Path $projectRoot "Build-Exe.ps1"
& $compileScript -OutFile "WinMemoryOpt.exe"

if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $projectRoot "WinMemoryOpt.exe"))) {
    Write-Error "Compilation failed. Aborting release build."
    exit 1
}

# 3. Assemble distribution package
Write-Host "Assembling distribution directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $distDir -Force | Out-Null

Copy-Item (Join-Path $projectRoot "WinMemoryOpt.exe") -Destination $distDir
Copy-Item (Join-Path $projectRoot "MemoryOptimizer.ps1") -Destination $distDir
Copy-Item (Join-Path $projectRoot "config.json") -Destination $distDir
Copy-Item (Join-Path $projectRoot "lib") -Destination $distDir -Recurse

# 4. Compress to ZIP
Write-Host "Creating ZIP archive..." -ForegroundColor Yellow
Compress-Archive -Path "$distDir\*" -DestinationPath $zipFile -Force

if (-not (Test-Path $zipFile)) {
    Write-Error "ZIP creation failed."
    exit 1
}
Write-Host "ZIP created successfully: $zipFile" -ForegroundColor Green

# 5. Compute SHA256 Hash
Write-Host "Calculating SHA256 hash of ZIP archive..." -ForegroundColor Yellow
$hashStream = [System.IO.File]::OpenRead($zipFile)
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$hashBytes = $sha256.ComputeHash($hashStream)
$hashStream.Close()
$zipHash = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToUpper()
Write-Host "SHA256: $zipHash" -ForegroundColor Green

# 6. Create Winget manifests directory
New-Item -ItemType Directory -Path $manifestsDir -Force | Out-Null

# 7. Generate Manifest Files
Write-Host "Generating WinGet Manifests..." -ForegroundColor Yellow

# 7.1 Version Manifest
$versionYaml = @"
PackageIdentifier: Optico.WinMemoryOpt
PackageVersion: 1.1.0
DefaultLocale: en-US
ManifestType: version
ManifestVersion: 1.5.0
"@
[System.IO.File]::WriteAllText((Join-Path $manifestsDir "Optico.WinMemoryOpt.version.yaml"), $versionYaml)

# 7.2 Locale English Manifest
$localeEnYaml = @"
PackageIdentifier: Optico.WinMemoryOpt
PackageVersion: 1.1.0
PackageLocale: en-US
Publisher: Optico
PublisherUrl: https://github.com/chienhaoc/WinMemoryOpt
Author: chchen
PackageName: WinMemoryOpt
PackageUrl: https://github.com/chienhaoc/WinMemoryOpt
License: Apache-2.0
ShortDescription: A lightweight and smart background memory optimizer for Windows.
ManifestType: defaultLocale
ManifestVersion: 1.5.0
"@
[System.IO.File]::WriteAllText((Join-Path $manifestsDir "Optico.WinMemoryOpt.locale.en-US.yaml"), $localeEnYaml)

# 7.3 Installer Manifest (contains the dynamic SHA256)
$installerYaml = @"
PackageIdentifier: Optico.WinMemoryOpt
PackageVersion: 1.1.0
InstallerType: zip
NestedInstallerType: portable
NestedInstallerFiles:
  - RelativeFilePath: WinMemoryOpt.exe
    PortableCommandAlias: winmemopt
Installers:
  - Architecture: x64
    InstallerUrl: https://github.com/chienhaoc/WinMemoryOpt/releases/download/v1.1.0/WinMemoryOpt.zip
    InstallerSha256: $zipHash
ManifestType: installer
ManifestVersion: 1.5.0
"@
[System.IO.File]::WriteAllText((Join-Path $manifestsDir "Optico.WinMemoryOpt.installer.yaml"), $installerYaml)

Write-Host "Manifests generated successfully at $manifestsDir" -ForegroundColor Green
Write-Host "Build complete!" -ForegroundColor Green
