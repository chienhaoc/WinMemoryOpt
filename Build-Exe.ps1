param (
    [string]$OutFile = "WinMemoryOpt.exe"
)

$scriptPath = $PSScriptRoot
if (-not $scriptPath) { $scriptPath = $PWD.Path }
$wrapperCsPath = Join-Path $scriptPath "Wrapper.cs"
$manifestPath = Join-Path $scriptPath "app.manifest"

$csCode = @"
using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Reflection;
using System.Runtime.InteropServices;

[assembly: AssemblyTitle("Windows Memory Optimizer")]
[assembly: AssemblyDescription("Portable memory optimizer for Windows")]
[assembly: AssemblyProduct("WinMemoryOpt")]
[assembly: AssemblyCopyright("Copyright 2026")]
[assembly: AssemblyVersion("1.0.0.0")]

namespace WinMemoryOptApp
{
    class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            try
            {
                string appDir = AppDomain.CurrentDomain.BaseDirectory;
                string scriptPath = Path.Combine(appDir, "MemoryOptimizer.ps1");

                if (!File.Exists(scriptPath)) { 
                    System.Windows.Forms.MessageBox.Show("Cannot find MemoryOptimizer.ps1 in " + appDir, "Error", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
                    return; 
                }

                InitialSessionState iss = InitialSessionState.CreateDefault();
                iss.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass;

                using (Runspace runspace = RunspaceFactory.CreateRunspace(iss))
                {
                    runspace.ApartmentState = System.Threading.ApartmentState.STA;
                    runspace.Open();
                    runspace.SessionStateProxy.Path.SetLocation(appDir);

                    using (Pipeline pipeline = runspace.CreatePipeline())
                    {
                        Command cmd = new Command(scriptPath);
                        cmd.Parameters.Add("Background", true);
                        pipeline.Commands.Add(cmd);
                        pipeline.Invoke();
                    }
                }
            }
            catch (Exception ex)
            {
                System.Windows.Forms.MessageBox.Show(ex.ToString(), "Fatal Error", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
            }
        }
    }
}
"@

$manifestCode = @"
<?xml version="1.0" encoding="utf-8"?>
<assembly manifestVersion="1.0" xmlns="urn:schemas-microsoft-com:asm.v1">
  <assemblyIdentity version="1.0.0.0" name="WinMemoryOpt"/>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">
    <security>
      <requestedPrivileges xmlns="urn:schemas-microsoft-com:asm.v3">
        <requestedExecutionLevel level="requireAdministrator" uiAccess="false" />
      </requestedPrivileges>
    </security>
  </trustInfo>
</assembly>
"@

Set-Content -Path $wrapperCsPath -Value $csCode -Encoding UTF8
Set-Content -Path $manifestPath -Value $manifestCode -Encoding UTF8

$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$sma = [PSObject].Assembly.Location

Write-Host "Compiling $OutFile using System.Management.Automation from $sma..."
& $csc /nologo /target:winexe /out:"$scriptPath\$OutFile" /reference:"$sma" /reference:System.Windows.Forms.dll /win32manifest:"$manifestPath" "$wrapperCsPath"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Compilation successful: $OutFile" -ForegroundColor Green
    Remove-Item $wrapperCsPath -Force
    Remove-Item $manifestPath -Force
} else {
    Write-Host "Compilation failed." -ForegroundColor Red
}
