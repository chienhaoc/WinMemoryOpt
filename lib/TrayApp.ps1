param (
    [string]$ConfigPath = "$((Split-Path -Parent $PSScriptRoot))\config.json"
)

# Load assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Source dependency controller
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptPath "MemoryOptimizerController.ps1")
. (Join-Path $scriptPath "EventLogAnalyzer.ps1")
. (Join-Path $scriptPath "WmiTrigger.ps1")

# Load configuration
if (Test-Path $ConfigPath) {
    $config = Get-Content $ConfigPath | ConvertFrom-Json
} else {
    $config = [PSCustomObject]@{
        Threshold = 80
        Mode = "Auto"
        EventLogDays = 7
        PollIntervalSeconds = 5
    }
    $config | ConvertTo-Json | Out-File $ConfigPath -Encoding utf8
}

# -----------------------------------------------------------------------------
# i18n & Localization Resources
# -----------------------------------------------------------------------------
$culture = [System.Globalization.CultureInfo]::CurrentCulture.Name
$lang = "en-US"
if ($culture -like "zh-*") {
    $lang = "zh-TW"
}

$resources = @{
    "en-US" = @{
        "Title" = "Windows Memory Optimizer"
        "TitleMonitor" = "Memory Optimizer (WMI Active)"
        "MenuTitle" = "Memory Optimizer (WMI Monitoring)"
        "MenuAutoMonitor" = "Enable Auto Monitoring"
        "MenuStartOnBoot" = "Start on Boot"
        "MenuSettings" = "Settings..."
        "MenuReinit" = "Reinitialize (Scan Logs)"
        "MenuManual" = "Manual Optimize"
        "MenuLogs" = "Query Logs"
        "MenuConfig" = "Query Config"
        "MenuExit" = "Exit/Close App"
        
        "BalloonReinitTitle" = "Reinitialization Complete"
        "BalloonReinitText" = "New Threshold set to: {0}%`nLow memory warnings found: {1}"
        "BalloonReleaseTitle" = "Optimization Complete"
        "BalloonReleaseText" = "Successfully reclaimed: {0} MB`nMemory usage: {1}% -> {2}%"
        "BalloonReleaseFail" = "Optimization Failed"
        "BalloonReleaseFailText" = "Error: {0}"
        
        "BalloonWmiTitle" = "WMI Auto Reclaim"
        "BalloonWmiText" = "Memory usage reached threshold {0}%. Reclaimed {1} MB."
        "BalloonMonitorEnabled" = "Monitoring Enabled"
        "BalloonMonitorEnabledText" = "WMI automatic memory monitoring is active."
        "BalloonMonitorDisabled" = "Monitoring Paused"
        "BalloonMonitorDisabledText" = "Automatic monitoring paused. Manual release is still available."
        "BalloonBootEnabled" = "Setting Updated"
        "BalloonBootEnabledText" = "Auto-start on boot enabled."
        "BalloonBootDisabled" = "Setting Updated"
        "BalloonBootDisabledText" = "Auto-start on boot disabled."
        "BalloonHeavyTitle" = "Active Response: Heavy App Trimmed"
        "BalloonHeavyText" = "Memory threshold reached. Aggressively trimmed: {0}"
        
        "TooltipUsage" = "RAM: {0}% | VM: {1}%`nThreshold: {2}% | Triggers: {3}"
        "TooltipPaused" = "RAM: {0}% | VM: {1}%`n(Monitoring Paused)"
        "TooltipUsageCompact" = "R:{0}% V:{1}% | T:{2}% | C:{3}"
        
        "StatsTitle" = "System Memory Status"
        "StatsText" = "Current Statistics:`n---------------------`nThreshold: {0}%`nRAM Usage: {1}% ({2} GB Free / {3} GB Total)`nVM Usage: {4}% ({5} GB Free / {6} GB Total)`nAuto Release Count: {7} times`nRelease Mode: {8}`nMonitoring State: {9}"
        
        "StateActive" = "Monitoring"
        "StatePaused" = "Paused"
        
        "SettingsTitle" = "Settings - Windows Memory Optimizer"
        "SettingsThreshold" = "Optimization Threshold (%):"
        "SettingsMode" = "Memory Release Mode:"
        "SettingsApply" = "Apply"
        "SettingsCancel" = "Cancel"
        "SettingsError" = "Input Error"
        "SettingsErrorText" = "Please enter a valid threshold between 1 and 100."
        "DescAuto" = "Recommended: Intelligent Mode. Safely compresses app memory and clears standby caches for maximum yield."
        "DescProcessWorkingSet" = "Safe: Process Working Set. Compresses idle memory of running apps to the pagefile without flushing system caches."
        "DescSystemStandbyList" = "Aggressive: Standby List. Clears the Windows file cache. Frees massive RAM but may slightly increase disk reads on app launch."
        "DescModifiedPageList" = "Extreme: Modified Page List. Forces unwritten modified pages to disk. Use when memory is critically exhausted."
        "DescSystemWorkingSets" = "Global: System Working Sets. Unconditionally compresses memory for all system services. High yield, may cause stuttering."
        
        "MsgBootAlready" = "Windows Memory Optimizer is already running, please check the system tray icon."
        "MsgBootTitle" = "Program Already Running"
        
        "LogStart" = "Application started. Initial Threshold: {0}%, Mode: {1}"
        "LogExit" = "Application exiting."
        "LogWmiPause" = "Automatic WMI monitoring paused by user."
        "LogWmiResume" = "Automatic WMI monitoring resumed by user."
        "LogBootEnable" = "Enabled auto-start via Registry Run key."
        "LogBootEnableSched" = "Enabled auto-start via Task Scheduler (Highest Privileges)."
        "LogBootDisable" = "Disabled auto-start on boot."
        "MenuTrim" = "Targeted App Trimmer..."
        "TrimTitle" = "Targeted App Trimmer"
        "TrimDesc" = "Select specific high-memory applications to aggressively compress their memory footprint to disk."
        "TrimRefresh" = "Refresh List"
        "TrimExecute" = "Trim Selected"
        "TrimSuccess" = "Successfully trimmed {0} selected process(es)."
        "MenuFocusMode" = "🚀 Enable Focus Mode"
        "MenuFocusModeOff" = "🛑 Disable Focus Mode"
        "FocusStarting" = "Focus Mode Starting"
        "FocusStartingText" = "Focus Mode will activate in 5 seconds. Please switch to your game/app now!"
        "FocusEnabled" = "Focus Mode Enabled"
        "FocusEnabledText" = "Protected foreground app. Suppressed {0} background apps."
        "FocusDisabled" = "Focus Mode Disabled"
        "FocusDisabledText" = "Restored CPU priority for {0} background apps."
    };
    "zh-TW" = @{
        "Title" = "Windows 記憶體最佳化"
        "TitleMonitor" = "記憶體最佳化工具 (WMI 監控中)"
        "MenuTitle" = "記憶體最佳化工具 (WMI 監控中)"
        "MenuAutoMonitor" = "啟用自動監控"
        "MenuStartOnBoot" = "隨開機自動啟動"
        "MenuSettings" = "設定管理..."
        "MenuReinit" = "重新初始化 (掃描 Log)"
        "MenuManual" = "手動記憶體釋放"
        "MenuLogs" = "Log 查詢"
        "MenuConfig" = "設定檔查詢"
        "MenuExit" = "離開/關閉 App"
        
        "BalloonReinitTitle" = "重新初始化完成"
        "BalloonReinitText" = "新臨界值門檻已設為: {0}%`n分析結果低記憶體警告次數: {1}"
        "BalloonReleaseTitle" = "手動釋放完成"
        "BalloonReleaseText" = "成功釋放: {0} MB`n使用率: {1}% -> {2}%"
        "BalloonReleaseFail" = "手動釋放失敗"
        "BalloonReleaseFailText" = "錯誤: {0}"
        
        "BalloonWmiTitle" = "WMI 自動釋放記憶體"
        "BalloonWmiText" = "記憶體使用率已達臨界值 {0}%，WMI 自動釋放完成！`n成功釋放: {1} MB"
        "BalloonMonitorEnabled" = "監控已啟用"
        "BalloonMonitorEnabledText" = "WMI 自動記憶體監控已回復。"
        "BalloonMonitorDisabled" = "監控已暫停"
        "BalloonMonitorDisabledText" = "自動記憶體監控已暫停，仍可使用手動釋放。"
        "BalloonBootEnabled" = "設定成功"
        "BalloonBootEnabledText" = "已啟用隨開機自動啟動功能。"
        "BalloonBootDisabled" = "設定成功"
        "BalloonBootDisabledText" = "已停用開機啟動功能。"
        "BalloonHeavyTitle" = "即時壓制: 肥大程式已壓縮"
        "BalloonHeavyText" = "記憶體達臨界點，已自動將以下巨獸程式壓縮回硬碟: {0}"
        
        "TooltipUsage" = "RAM: {0}% | 虛擬: {1}%`n門檻: {2}% | 次數: {3}"
        "TooltipPaused" = "RAM: {0}% | 虛擬: {1}%`n(已暫停自動監控)"
        "TooltipUsageCompact" = "R:{0}% V:{1}% | 門:{2}% | 次:{3}"
        
        "StatsTitle" = "系統記憶體狀態"
        "StatsText" = "目前統計資訊：`n---------------------`n目前的門檻臨界值: {0}%`nRAM 使用率: {1}% ({2} GB 空閒 / {3} GB 總計)`n虛擬記憶體: {4}% ({5} GB 空閒 / {6} GB 總計)`n自動記憶體釋放次數: {7} 次`n目前的釋放模式: {8}`n自動監控狀態: {9}"
        
        "StateActive" = "監控中"
        "StatePaused" = "已暫停監控"
        
        "SettingsTitle" = "設定管理 - Windows 記憶體最佳化"
        "SettingsThreshold" = "優化臨界值門檻 (百分比 %):"
        "SettingsMode" = "記憶體釋放模式:"
        "SettingsApply" = "套用"
        "SettingsCancel" = "取消"
        "SettingsError" = "輸入錯誤"
        "SettingsErrorText" = "請輸入介於 1 到 100 之間的有效門檻數值。"
        "DescAuto" = "推薦：智慧綜合模式。先壓縮應用程式記憶體，再清理系統備用快取，兼顧安全與最大釋放量。"
        "DescProcessWorkingSet" = "安全：僅應用程式工作集。將目前執行中軟體的閒置記憶體壓縮回硬碟，不影響系統快取。"
        "DescSystemStandbyList" = "激進：清理備用清單快取。強制清空系統為加速開啟程式而保留的快取，能釋放大量空間。"
        "DescModifiedPageList" = "極限：強制寫入已修改分頁。將還沒存入硬碟的記憶體資料強制寫回，通常在記憶體極度枯竭時使用。"
        "DescSystemWorkingSets" = "全域：清理系統工作集。無差別壓縮包含系統核心服務的記憶體，釋放量大但可能造成短暫卡頓。"
        
        "MsgBootAlready" = "Windows Memory Optimizer 已在執行中，請在右下角系統匣查看圖示。"
        "MsgBootTitle" = "程式已在執行中"
        
        "LogStart" = "應用程式啟動。初始臨界值: {0}%, 釋放模式: {1}"
        "LogExit" = "應用程式結束。"
        "LogWmiPause" = "使用者暫停了 WMI 自動監控。"
        "LogWmiResume" = "使用者啟用了 WMI 自動監控。"
        "LogBootEnable" = "已啟用隨開機啟動 (登錄表)。"
        "LogBootEnableSched" = "已啟用隨開機啟動 (工作排程最高權限)。"
        "LogBootDisable" = "已停用隨開機啟動。"
        "MenuTrim" = "特定應用瘦身..."
        "TrimTitle" = "特定應用記憶體瘦身"
        "TrimDesc" = "勾選佔用過高記憶體的特定應用程式，手動強制將它們的閒置記憶體壓縮回硬碟。"
        "TrimRefresh" = "重新整理"
        "TrimExecute" = "瘦身勾選項"
        "TrimSuccess" = "成功為 {0} 個選取的應用程式執行瘦身！"
        "MenuFocusMode" = "🚀 啟用遊戲/專注模式"
        "MenuFocusModeOff" = "🛑 解除遊戲/專注模式"
        "FocusStarting" = "準備啟動專注模式"
        "FocusStartingText" = "專注模式將於 5 秒後啟動，請立即切換至您想加速的遊戲/軟體視窗！"
        "FocusEnabled" = "專注模式已啟動"
        "FocusEnabledText" = "已鎖定前景視窗！並強制壓制了 {0} 個背景耗能程式。"
        "FocusDisabled" = "專注模式已解除"
        "FocusDisabledText" = "已恢復 {0} 個背景程式的正常 CPU 優先權。"
    }
}

function Get-String {
    param([string]$Key)
    if ($resources.ContainsKey($lang) -and $resources[$lang].ContainsKey($Key)) {
        return $resources[$lang][$Key]
    }
    return $resources["en-US"][$Key]
}

# -----------------------------------------------------------------------------
# Global Statistics & Initialization
# -----------------------------------------------------------------------------
$script:TriggerCount = 0
$script:CurrentThreshold = $config.Threshold
$script:ReleaseMode = $config.Mode
$script:LastTriggerTime = $null
$script:MonitoringActive = $true
$script:FocusModeActive = $false
$script:SuppressedPids = @()

# Write startup log
Write-OptLog "INFO" ((Get-String "LogStart") -f $script:CurrentThreshold, $script:ReleaseMode)

# Create Form is not needed for a NotifyIcon-only app, removing hidden form.

# Helper to generate a dynamic memory percentage icon
$script:LastIconHandle = [IntPtr]::Zero

function Update-DynamicIcon {
    param (
        [int]$Percentage
    )
    
    try {
        $bmp = New-Object System.Drawing.Bitmap(32, 32)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        
        # Color: Grey if paused, Green (<70), Orange (<85), Red (>=85)
        $color = if (-not $script:MonitoringActive) {
            [System.Drawing.Color]::FromArgb(127, 140, 141) # Grey
        } elseif ($Percentage -lt 70) {
            [System.Drawing.Color]::FromArgb(46, 204, 113) # Green
        } elseif ($Percentage -lt 85) {
            [System.Drawing.Color]::FromArgb(230, 126, 34) # Orange
        } else {
            [System.Drawing.Color]::FromArgb(231, 76, 60) # Red
        }
        
        $brush = New-Object System.Drawing.SolidBrush($color)
        $g.FillEllipse($brush, 1, 1, 30, 30)
        
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)
        $g.DrawEllipse($pen, 1, 1, 30, 30)
        
        $font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        
        $text = $Percentage.ToString()
        $textSize = $g.MeasureString($text, $font)
        
        $x = (32 - $textSize.Width) / 2
        $y = (32 - $textSize.Height) / 2 + 1
        
        $g.DrawString($text, $font, $textBrush, $x, $y)
        
        $g.Dispose()
        $brush.Dispose()
        $pen.Dispose()
        $font.Dispose()
        $textBrush.Dispose()
        
        $hIcon = $bmp.GetHicon()
        $icon = [System.Drawing.Icon]::FromHandle($hIcon)
        $bmp.Dispose()
        
        $oldIcon = $notifyIcon.Icon
        $notifyIcon.Icon = $icon
        
        if ($script:LastIconHandle -ne [IntPtr]::Zero) {
            [void][WinMemoryOpt.MemoryHelper]::DestroyIconHandle($script:LastIconHandle)
        }
        if ($oldIcon) {
            $oldIcon.Dispose()
        }
        
        $script:LastIconHandle = $hIcon
    } catch {
        $notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
    }
}

# Update Hover Tooltip function (Max 63 chars)
function Update-Tooltip {
    $os = Get-CimInstance Win32_OperatingSystem
    $currentUsage = [Math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
    
    $totalVM = $os.TotalVirtualMemorySize
    $freeVM = $os.FreeVirtualMemory
    $vmUsage = [Math]::Round((($totalVM - $freeVM) / $totalVM) * 100, 1)
    
    if (-not $script:MonitoringActive) {
        $text = (Get-String "TooltipPaused") -f $currentUsage, $vmUsage
    } else {
        $text = (Get-String "TooltipUsage") -f $currentUsage, $vmUsage, $script:CurrentThreshold, $script:TriggerCount
    }
    
    if ($text.Length -gt 63) {
        $text = (Get-String "TooltipUsageCompact") -f $currentUsage, $vmUsage, $script:CurrentThreshold, $script:TriggerCount
    }
    
    $notifyIcon.Text = $text
    Update-DynamicIcon -Percentage ([int]$currentUsage)
}

# Auto-start on boot helpers
function Check-IsStartOnBoot {
    $task = Get-ScheduledTask -TaskName "WindowsMemoryOptimizer" -ErrorAction SilentlyContinue
    if ($task) { return $true }
    $reg = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "WindowsMemoryOptimizer" -ErrorAction SilentlyContinue
    if ($reg) { return $true }
    return $false
}

function Set-StartOnBoot {
    param([bool]$Enable)
    $taskName = "WindowsMemoryOptimizer"
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    
    if ($Enable) {
        try {
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if ($isAdmin) {
                $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$((Split-Path -Parent $PSScriptRoot))\MemoryOptimizer.ps1`" -Background"
                $trigger = New-ScheduledTaskTrigger -AtLogOn
                $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
                $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
                Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
                Remove-ItemProperty -Path $regPath -Name $taskName -ErrorAction SilentlyContinue
                Write-OptLog "INFO" (Get-String "LogBootEnableSched")
                return $true
            }
        } catch {
            # Fallback to Registry Run Key
        }
        
        Set-ItemProperty -Path $regPath -Name $taskName -Value "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$((Split-Path -Parent $PSScriptRoot))\MemoryOptimizer.ps1`" -Background"
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        Write-OptLog "INFO" (Get-String "LogBootEnable")
        return $true
    } else {
        Remove-ItemProperty -Path $regPath -Name $taskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        Write-OptLog "INFO" (Get-String "LogBootDisable")
        return $false
    }
}

# Settings GUI Form
function Show-SettingsForm {
    $settingsForm = New-Object System.Windows.Forms.Form
    $settingsForm.Text = Get-String "SettingsTitle"
    $settingsForm.Size = New-Object System.Drawing.Size(320, 290)
    $settingsForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $settingsForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $settingsForm.MaximizeBox = $false
    $settingsForm.MinimizeBox = $false
    $settingsForm.ShowInTaskbar = $true

    $lblThreshold = New-Object System.Windows.Forms.Label
    $lblThreshold.Text = Get-String "SettingsThreshold"
    $lblThreshold.Location = New-Object System.Drawing.Point(20, 20)
    $lblThreshold.Size = New-Object System.Drawing.Size(240, 20)
    [void]$settingsForm.Controls.Add($lblThreshold)

    $txtThreshold = New-Object System.Windows.Forms.TextBox
    $txtThreshold.Text = $script:CurrentThreshold.ToString()
    $txtThreshold.Location = New-Object System.Drawing.Point(20, 45)
    $txtThreshold.Size = New-Object System.Drawing.Size(100, 20)
    [void]$settingsForm.Controls.Add($txtThreshold)

    $lblMode = New-Object System.Windows.Forms.Label
    $lblMode.Text = Get-String "SettingsMode"
    $lblMode.Location = New-Object System.Drawing.Point(20, 80)
    $lblMode.Size = New-Object System.Drawing.Size(200, 20)
    [void]$settingsForm.Controls.Add($lblMode)

    $cmbMode = New-Object System.Windows.Forms.ComboBox
    $cmbMode.Location = New-Object System.Drawing.Point(20, 105)
    $cmbMode.Size = New-Object System.Drawing.Size(200, 25)
    $cmbMode.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    
    $modesList = @("Auto", "ProcessWorkingSet", "SystemStandbyList", "ModifiedPageList", "SystemWorkingSets")
    foreach ($m in $modesList) {
        [void]$cmbMode.Items.Add($m)
    }
    $cmbMode.SelectedItem = $script:ReleaseMode
    [void]$settingsForm.Controls.Add($cmbMode)

    $lblModeDesc = New-Object System.Windows.Forms.Label
    $lblModeDesc.Location = New-Object System.Drawing.Point(20, 140)
    $lblModeDesc.Size = New-Object System.Drawing.Size(260, 45)
    $lblModeDesc.ForeColor = [System.Drawing.Color]::DimGray
    [void]$settingsForm.Controls.Add($lblModeDesc)

    $cmbMode.Add_SelectedIndexChanged({
        $modeStr = "Desc" + $cmbMode.SelectedItem.ToString()
        $lblModeDesc.Text = Get-String $modeStr
    })
    # Trigger event initially
    $modeStrInit = "Desc" + $cmbMode.SelectedItem.ToString()
    $lblModeDesc.Text = Get-String $modeStrInit

    $btnApply = New-Object System.Windows.Forms.Button
    $btnApply.Text = Get-String "SettingsApply"
    $btnApply.Location = New-Object System.Drawing.Point(60, 200)
    $btnApply.DialogResult = [System.Windows.Forms.DialogResult]::OK
    [void]$settingsForm.Controls.Add($btnApply)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = Get-String "SettingsCancel"
    $btnCancel.Location = New-Object System.Drawing.Point(170, 200)
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    [void]$settingsForm.Controls.Add($btnCancel)

    $settingsForm.AcceptButton = $btnApply
    $settingsForm.CancelButton = $btnCancel

    $result = $settingsForm.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $newThreshold = 0
        if ([int]::TryParse($txtThreshold.Text, [ref]$newThreshold) -and $newThreshold -gt 0 -and $newThreshold -le 100) {
            $script:CurrentThreshold = $newThreshold
            $script:ReleaseMode = $cmbMode.SelectedItem.ToString()

            $config.Threshold = $script:CurrentThreshold
            $config.Mode = $script:ReleaseMode
            $config | ConvertTo-Json | Out-File $ConfigPath -Force -Encoding utf8

            Write-OptLog "INFO" "Configuration updated via UI. Threshold: $script:CurrentThreshold%, Mode: $script:ReleaseMode"
            
            if ($script:MonitoringActive) {
                Register-WmiEventTrigger
            }

            $notifyIcon.ShowBalloonTip(3000, (Get-String "SettingsTitle"), ((Get-String "BalloonReinitText") -f $script:CurrentThreshold, 0), [System.Windows.Forms.ToolTipIcon]::Info)
            Update-Tooltip
        } else {
            [System.Windows.Forms.MessageBox]::Show((Get-String "SettingsErrorText"), (Get-String "SettingsError"), [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    }
    
    $settingsForm.Dispose()
}


# Targeted App Trimmer GUI Form
function Show-ProcessTrimmerForm {
    $trimForm = New-Object System.Windows.Forms.Form
    $trimForm.Text = Get-String "TrimTitle"
    $trimForm.Size = New-Object System.Drawing.Size(420, 360)
    $trimForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $trimForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $trimForm.MaximizeBox = $false
    $trimForm.MinimizeBox = $false
    $trimForm.ShowInTaskbar = $true

    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Text = Get-String "TrimDesc"
    $lblInfo.Location = New-Object System.Drawing.Point(10, 10)
    $lblInfo.Size = New-Object System.Drawing.Size(380, 40)
    [void]$trimForm.Controls.Add($lblInfo)

    $listView = New-Object System.Windows.Forms.ListView
    $listView.Location = New-Object System.Drawing.Point(10, 50)
    $listView.Size = New-Object System.Drawing.Size(380, 200)
    $listView.View = [System.Windows.Forms.View]::Details
    $listView.FullRowSelect = $true
    $listView.CheckBoxes = $true
    [void]$listView.Columns.Add("Process Name", 180)
    [void]$listView.Columns.Add("Memory (MB)", 100)
    [void]$listView.Columns.Add("PID", 60)
    [void]$trimForm.Controls.Add($listView)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = Get-String "TrimRefresh"
    $btnRefresh.Location = New-Object System.Drawing.Point(60, 270)
    $btnRefresh.Size = New-Object System.Drawing.Size(120, 30)
    
    $btnTrim = New-Object System.Windows.Forms.Button
    $btnTrim.Text = Get-String "TrimExecute"
    $btnTrim.Location = New-Object System.Drawing.Point(220, 270)
    $btnTrim.Size = New-Object System.Drawing.Size(120, 30)

    [void]$trimForm.Controls.Add($btnRefresh)
    [void]$trimForm.Controls.Add($btnTrim)

    function Reload-ProcessList {
        $listView.Items.Clear()
        $procs = Get-HeavyProcesses -TopCount 15 -MinWorkingSetMB 100
        foreach ($p in $procs) {
            $item = New-Object System.Windows.Forms.ListViewItem($p.Name)
            [void]$item.SubItems.Add($p.WorkingSetMB.ToString())
            [void]$item.SubItems.Add($p.Id.ToString())
            $item.Checked = $true
            [void]$listView.Items.Add($item)
        }
    }

    $btnRefresh.Add_Click({ Reload-ProcessList })

    $btnTrim.Add_Click({
        $trimmedCount = 0
        $trimmedNames = @()
        foreach ($item in $listView.Items) {
            if ($item.Checked) {
                $targetPid = [int]$item.SubItems[2].Text
                $pName = $item.SubItems[0].Text
                if ([WinMemoryOpt.MemoryHelper]::PurgeProcessWorkingSetById($targetPid)) {
                    $trimmedCount++
                    $trimmedNames += $pName
                }
            }
        }
        if ($trimmedCount -gt 0) {
            $namesStr = $trimmedNames -join ", "
            Write-OptLog "SUCCESS" "Targeted App Trimmer manually compressed $trimmedCount app(s): $namesStr"
        }
        [System.Windows.Forms.MessageBox]::Show(((Get-String "TrimSuccess") -f $trimmedCount), (Get-String "TrimTitle"), [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        Reload-ProcessList
    })

    Reload-ProcessList
    $trimForm.ShowDialog() | Out-Null
    $trimForm.Dispose()
}

# Create Context Menu
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

# 1. Title / Info Item (Disabled)
$infoItem = New-Object System.Windows.Forms.ToolStripMenuItem
$infoItem.Text = Get-String "MenuTitle"
$infoItem.Enabled = $false
[void]$contextMenu.Items.Add($infoItem)

[void]$contextMenu.Items.Add("-")

# 2. Toggle Monitor (Pause/Resume)
$monitorItem = New-Object System.Windows.Forms.ToolStripMenuItem
$monitorItem.Text = Get-String "MenuAutoMonitor"
$monitorItem.Checked = $script:MonitoringActive
$monitorItem.Add_Click({
    $script:MonitoringActive = -not $script:MonitoringActive
    $this.Checked = $script:MonitoringActive
    if ($script:MonitoringActive) {
        Register-WmiEventTrigger
        Write-OptLog "INFO" (Get-String "LogWmiResume")
        $notifyIcon.ShowBalloonTip(2000, (Get-String "BalloonMonitorEnabled"), (Get-String "BalloonMonitorEnabledText"), [System.Windows.Forms.ToolTipIcon]::Info)
    } else {
        Unregister-MemoryWmiEvent
        Write-OptLog "INFO" (Get-String "LogWmiPause")
        $notifyIcon.ShowBalloonTip(2000, (Get-String "BalloonMonitorDisabled"), (Get-String "BalloonMonitorDisabledText"), [System.Windows.Forms.ToolTipIcon]::Info)
    }
    Update-Tooltip
})
[void]$contextMenu.Items.Add($monitorItem)

# 3. Toggle Start on Boot
$bootItem = New-Object System.Windows.Forms.ToolStripMenuItem
$bootItem.Text = Get-String "MenuStartOnBoot"
$bootItem.Checked = Check-IsStartOnBoot
$bootItem.Add_Click({
    $isNowBoot = -not $this.Checked
    $success = Set-StartOnBoot -Enable $isNowBoot
    $this.Checked = $success
    if ($success) {
        $notifyIcon.ShowBalloonTip(2000, (Get-String "BalloonBootEnabled"), (Get-String "BalloonBootEnabledText"), [System.Windows.Forms.ToolTipIcon]::Info)
    } else {
        $notifyIcon.ShowBalloonTip(2000, (Get-String "BalloonBootDisabled"), (Get-String "BalloonBootDisabledText"), [System.Windows.Forms.ToolTipIcon]::Info)
    }
})
[void]$contextMenu.Items.Add($bootItem)

# 4. Settings Management
$settingsItem = New-Object System.Windows.Forms.ToolStripMenuItem
$settingsItem.Text = Get-String "MenuSettings"
$settingsItem.Add_Click({
    Show-SettingsForm
})
[void]$contextMenu.Items.Add($settingsItem)

[void]$contextMenu.Items.Add("-")

# 5. Reinitialize
$reinitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$reinitItem.Text = Get-String "MenuReinit"
$reinitItem.Add_Click({
    Write-OptLog "INFO" "User clicked Reinitialize."
    $analysis = Analyze-MemoryLogs -Days $config.EventLogDays -DefaultThreshold $config.Threshold
    $script:CurrentThreshold = $analysis.RecommendedThreshold
    
    if ($script:MonitoringActive) {
        Register-WmiEventTrigger
    }
    
    Write-OptLog "INFO" "Reinitialized. New Threshold set to: $script:CurrentThreshold%"
    $notifyIcon.ShowBalloonTip(3000, (Get-String "BalloonReinitTitle"), ((Get-String "BalloonReinitText") -f $script:CurrentThreshold, $analysis.WarningsCount), [System.Windows.Forms.ToolTipIcon]::Info)
    Update-Tooltip
})
[void]$contextMenu.Items.Add($reinitItem)

# 5.5. Targeted Trimmer
$trimItem = New-Object System.Windows.Forms.ToolStripMenuItem
$trimItem.Text = Get-String "MenuTrim"
$trimItem.Add_Click({
    Show-ProcessTrimmerForm
})
[void]$contextMenu.Items.Add($trimItem)

# 5.6 Focus Mode (Delayed Trigger)
$focusItem = New-Object System.Windows.Forms.ToolStripMenuItem
$focusItem.Text = Get-String "MenuFocusMode"
$focusItem.Add_Click({
    if ($script:FocusModeActive) {
        # Disable Focus Mode
        $restoredCount = 0
        foreach ($targetPid in $script:SuppressedPids) {
            if ([WinMemoryOpt.MemoryHelper]::SetEfficiencyMode($targetPid, $false)) {
                $restoredCount++
            }
        }
        $script:SuppressedPids = @()
        $script:FocusModeActive = $false
        $focusItem.Text = Get-String "MenuFocusMode"
        Write-OptLog "INFO" "Focus Mode Disabled. Restored $restoredCount apps."
        $notifyIcon.ShowBalloonTip(3000, (Get-String "FocusDisabled"), ((Get-String "FocusDisabledText") -f $restoredCount), [System.Windows.Forms.ToolTipIcon]::Info)
    } else {
        # Start 5s countdown
        Write-OptLog "INFO" "Focus Mode countdown started."
        $notifyIcon.ShowBalloonTip(5000, (Get-String "FocusStarting"), (Get-String "FocusStartingText"), [System.Windows.Forms.ToolTipIcon]::Warning)
        
        $script:focusTimer = New-Object System.Windows.Forms.Timer
        $script:focusTimer.Interval = 5000
        $script:focusTimer.Add_Tick({
            $script:focusTimer.Stop()
            $script:focusTimer.Dispose()
            
            # 1. Get Foreground PID
            $fgPid = [WinMemoryOpt.MemoryHelper]::GetForegroundProcessId()
            
            # 2. Get heavy background apps
            $heavyApps = Get-HeavyProcesses -TopCount 10 -MinWorkingSetMB 150
            $suppressedCount = 0
            $script:SuppressedPids = @()
            
            foreach ($app in $heavyApps) {
                # Protect foreground app and ourself
                if ($app.Id -ne $fgPid -and $app.Id -ne $PID) {
                    # Trim Memory
                    [WinMemoryOpt.MemoryHelper]::PurgeProcessWorkingSetById($app.Id) | Out-Null
                    # Apply Efficiency Mode
                    if ([WinMemoryOpt.MemoryHelper]::SetEfficiencyMode($app.Id, $true)) {
                        $script:SuppressedPids += $app.Id
                        $suppressedCount++
                    }
                }
            }
            
            $script:FocusModeActive = $true
            $focusItem.Text = Get-String "MenuFocusModeOff"
            Write-OptLog "INFO" "Focus Mode Activated! Suppressed $suppressedCount apps. Protected Foreground PID: $fgPid"
            $notifyIcon.ShowBalloonTip(3000, (Get-String "FocusEnabled"), ((Get-String "FocusEnabledText") -f $suppressedCount), [System.Windows.Forms.ToolTipIcon]::Info)
        })
        $script:focusTimer.Start()
    }
})
[void]$contextMenu.Items.Add($focusItem)

[void]$contextMenu.Items.Add("-")

# 6. Manual Release
$releaseItem = New-Object System.Windows.Forms.ToolStripMenuItem
$releaseItem.Text = Get-String "MenuManual"
$releaseItem.Add_Click({
    $res = Invoke-MemoryRelease -Mode $script:ReleaseMode
    if ($res.Success) {
        $script:TriggerCount++
        $notifyIcon.ShowBalloonTip(3000, (Get-String "BalloonReleaseTitle"), ((Get-String "BalloonReleaseText") -f $res.ReclaimedMB, $res.UsageBefore, $res.UsageAfter), [System.Windows.Forms.ToolTipIcon]::Info)
    } else {
        $notifyIcon.ShowBalloonTip(3000, (Get-String "BalloonReleaseFail"), ((Get-String "BalloonReleaseFailText") -f $res.Details), [System.Windows.Forms.ToolTipIcon]::Error)
    }
    Update-Tooltip
})
[void]$contextMenu.Items.Add($releaseItem)

[void]$contextMenu.Items.Add("-")

# 7. Query Logs
$logItem = New-Object System.Windows.Forms.ToolStripMenuItem
$logItem.Text = Get-String "MenuLogs"
$logItem.Add_Click({
    $logPath = "$((Split-Path -Parent $PSScriptRoot))\memory_opt.log"
    if (Test-Path $logPath) {
        [System.Diagnostics.Process]::Start("notepad.exe", $logPath)
    }
})
[void]$contextMenu.Items.Add($logItem)

# 8. Query Config
$configItem = New-Object System.Windows.Forms.ToolStripMenuItem
$configItem.Text = Get-String "MenuConfig"
$configItem.Add_Click({
    if (Test-Path $ConfigPath) {
        [System.Diagnostics.Process]::Start("notepad.exe", $ConfigPath)
    }
})
[void]$contextMenu.Items.Add($configItem)

[void]$contextMenu.Items.Add("-")

# 9. Exit
$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitItem.Text = Get-String "MenuExit"
$exitItem.Add_Click({
    Write-OptLog "INFO" (Get-String "LogExit")
    $uiTimer.Stop()
    Unregister-MemoryWmiEvent
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    if ($script:LastIconHandle -ne [IntPtr]::Zero) {
        [void][WinMemoryOpt.MemoryHelper]::DestroyIconHandle($script:LastIconHandle)
    }
    # Form is no longer needed
    [System.Windows.Forms.Application]::Exit()
})
[void]$contextMenu.Items.Add($exitItem)

# Create Notify Icon
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.ContextMenuStrip = $contextMenu

# Double click popup basic info
$notifyIcon.Add_DoubleClick({
    $os = Get-CimInstance Win32_OperatingSystem
    $currentUsage = [Math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
    $freeGB = [Math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $totalGB = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    
    $totalVM = $os.TotalVirtualMemorySize
    $freeVM = $os.FreeVirtualMemory
    $vmUsage = [Math]::Round((($totalVM - $freeVM) / $totalVM) * 100, 1)
    $freeVMGB = [Math]::Round($freeVM / 1MB, 2)
    $totalVMGB = [Math]::Round($totalVM / 1MB, 2)
    
    $statusStr = if ($script:MonitoringActive) { Get-String "StateActive" } else { Get-String "StatePaused" }
    
    $msg = (Get-String "StatsText") -f $script:CurrentThreshold, $currentUsage, $freeGB, $totalGB, $vmUsage, $freeVMGB, $totalVMGB, $script:TriggerCount, $script:ReleaseMode, $statusStr
    
    $notifyIcon.ShowBalloonTip(5000, (Get-String "StatsTitle"), $msg, [System.Windows.Forms.ToolTipIcon]::Info)
})

$notifyIcon.Visible = $true

# Helper to register WMI Trigger
function Register-WmiEventTrigger {
    $actionBlock = {
        # Check if we triggered too recently to prevent endless loop triggers (cooldown of 30 seconds)
        $now = Get-Date
        if ($script:LastTriggerTime -and ($now - $script:LastTriggerTime).TotalSeconds -lt 30) {
            return
        }
        $script:LastTriggerTime = $now

        $res = Invoke-MemoryRelease -Mode $script:ReleaseMode
        if ($res.Success) {
            $script:TriggerCount++
            $notifyIcon.ShowBalloonTip(4000, (Get-String "BalloonWmiTitle"), ((Get-String "BalloonWmiText") -f $script:CurrentThreshold, $res.ReclaimedMB), [System.Windows.Forms.ToolTipIcon]::Info)
        }
        Update-Tooltip
    }
    Register-MemoryWmiEvent -ThresholdPercent $script:CurrentThreshold -Action $actionBlock | Out-Null
}

# Register WMI Event Trigger if monitoring active
if ($script:MonitoringActive) {
    Register-WmiEventTrigger
}

# Timer just for updating UI Tooltip every 5 seconds
$uiTimer = New-Object System.Windows.Forms.Timer
$uiTimer.Interval = $config.PollIntervalSeconds * 1000
$uiTimer.Add_Tick({
    Update-Tooltip
})

# Initial setup
Update-Tooltip
$uiTimer.Start()

# Auto-close balloon helper
$balloonTimer = New-Object System.Windows.Forms.Timer
$balloonTimer.Add_Tick({
    $balloonTimer.Stop()
    if ($notifyIcon) {
        $notifyIcon.Visible = $false
        $notifyIcon.Visible = $true
    }
})

function Show-AutoCloseBalloon {
    param($DurationMs, $Title, $Text, $Icon)
    $notifyIcon.ShowBalloonTip($DurationMs, $Title, $Text, $Icon)
    if ($DurationMs -gt 0) {
        $balloonTimer.Interval = $DurationMs
        $balloonTimer.Stop()
        $balloonTimer.Start()
    }
}
# Run the Application Message Loop
[System.Windows.Forms.Application]::Run()





















