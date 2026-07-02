# Windows 記憶體最佳化工具 (WinMemoryOpt)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue.svg)](#)

這是一個以 PowerShell 包裝的 Windows 背景輕量化記憶體最佳化工具。它常駐於系統匣，透過 WMI 監控系統實體記憶體，並結合 Win32 公開 API 與 Windows NT 未公開系統 API 進行多模式的記憶體釋放。

---

## 功能特點

- **動態工作列圖示 (Premium UI)**：工作列圖示直接顯示即時記憶體使用率百分比，並依負載以顏色標示（綠色 < 70%、橘色 < 85%、紅色 $\ge$ 85%）。
- **多釋放模式支援**：
  - **程序工作集整理 (Process Working Set)** (公開 Win32 API)：遍歷並壓縮程序的工作記憶體。
  - **系統快取清理 (System Standby List)** (未公開 NT API)：清空系統 Standby 備用快取（*Reduce Memory* 使用的同款 API）。
  - **已修改頁面寫入 (Modified Page List)** (未公開 NT API)：強制寫入已修改頁面至硬碟以騰出 active 實體記憶體。
- **WMI 自動監控觸發**：當記憶體使用率達到臨界值時，透過 WMI 註冊事件自動觸發釋放，並具備 30 秒冷卻保護避免連續觸發。
- **語系相容日誌掃描 (i18n)**：啟動時自動掃描 Windows 事件檢視器（事件 ID `2004`），相容**英文**與**繁體中文**的 OS 日誌，分析記憶體高消耗應用程式並動態推薦優化門檻，且 UI 自動適應作業系統語系。
- **隨開機自動啟動**：支援透過 **工作排程器 (Task Scheduler)** 以最高權限（管理員）註冊啟動，或於一般權限下安全降級使用 **Registry Run 登錄表** 開機啟動。
- **設定管理視窗 (GUI)**：右鍵選單直接開啟設定對話框，即時調整門檻值與釋放模式並寫入設定。
- **日誌滾動 (Log Rotation)**：詳細記錄所有動作至 `memory_opt.log`，當日誌大小超過 **2MB** 時自動備份滾動，防止檔案無限增長。
- **防重疊執行**：採用系統級具名 `Mutex` 鎖，若偵測到重複執行會彈出警告提示並自動關閉新實例。
- **背景自動脫離 (Auto-Detach)**：當您在終端機執行 `MemoryOptimizer.ps1` 時，程式會自動偵測並生成一個隱藏的背景子程序來常駐，同時立刻將終端機的使用權還給您。
- **企業級基礎設施 (Enterprise-Grade)**：內建 `Install.ps1` 一鍵安裝腳本、GitHub Actions CI/CD 自動化流水線（包含靜態語法分析與自動打包 Release），以及完善的開源社群治理文件 (貢獻指南、Issue Templates 等)。

---

## 專案目錄結構

```text
WinMemoryOpt/
├── Install.ps1               # 一鍵安裝與反安裝腳本
├── MemoryOptimizer.ps1       # 主程式引導進入點、Mutex 鎖與背景脫離啟動器
├── test_runner.ps1           # 單元與整合功能驗證腳本
├── LICENSE                   # MIT 授權條款
├── README.md                 # 英文說明文件
├── README.zh-TW.md           # 繁體中文說明文件
├── CHANGELOG.md              # 專案版本更新日誌
├── .github/                  # CI/CD 工作流程、Issue 表單模板與貢獻指南
└── lib/
    ├── MemoryRelease.cs      # C# P/Invoke 宣告與 Windows 權限調整 helper
    ├── MemoryOptimizerController.ps1 # 記憶體優化控制與日誌滾動邏輯
    ├── EventLogAnalyzer.ps1  # 事件檢視器日誌掃描與動態門檻推薦
    ├── WmiTrigger.ps1        # WMI 監控事件註冊與清除
    └── TrayApp.ps1           # Windows Forms 系統匣 UI 與設定對話框
```

---

## 快速開始

### 自動安裝 (推薦做法)
對著 `Install.ps1` 點擊滑鼠右鍵並選擇 **用 PowerShell 執行**（或在終端機中以系統管理員身分執行）。
它會自動：
1. 將應用程式部署至 `C:\Program Files\WinMemoryOpt`。
2. 在「開始功能表」建立應用程式捷徑。
3. 自動啟動並常駐於系統匣中。

*若要解除安裝，只需執行 `.\Install.ps1 -Uninstall` 即可。*

### 手動快速啟動
打開 PowerShell 終端機並執行：
```powershell
.\MemoryOptimizer.ps1
```
*(主程式具備 **背景自動脫離** 功能，它會安靜地在背景產生常駐行程，並立刻將終端機畫面還給您)*

### 執行權限說明
WinMemoryOpt 相容於**系統管理員**與**一般使用者**權限：
- **管理員權限執行**：可釋放系統服務程序、清理全域 Standby 系統快取等高級系統 API 功能。
- **一般權限執行**：會安全且優雅地降級，只針對當前使用者名下的應用程式（通常佔用 90% 以上實體 RAM）進行工作集清理，並在日誌記錄系統級 API 的存取限制警告。

---

## 操作與互動

- **滑鼠懸停**：顯示 compact 提示，包含目前使用率、門檻與釋放次數。
- **連按兩下**：跳出詳細的系統狀態統計通知。
- **按滑鼠右鍵**：開啟功能選單，可啟用/暫停監控、切換開機啟動、管理設定、開啟 Log、手動釋放記憶體或退出程式。

---

## 授權條款

本專案基於 MIT 授權條款開源 - 詳見 [LICENSE](LICENSE) 檔案。

