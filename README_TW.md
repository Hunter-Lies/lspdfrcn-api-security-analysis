# 🔒 LSPDFRCN.API.dll 安全分析報告

## 隱藏於遊戲模組依賴中的惡意行為

> [简体中文](README.md) | [English](README_EN.md)

---

## 📋 概述

**檔案名稱**：`LSPDFRCN.API.dll`  
**分析版本**：`1.0.1.4`  
**檔案大小**：693,760 位元組  
**架構**：x64 | .NET v4.0.30319  
**來源**：中文網（LSPDFRCN）免費散佈的漢化前置包  
**聲稱用途**："漢化前置庫，內含各種實用方法"  
**實際行為**：秘密掃描使用者檔案、蒐集裝置指紋、上傳資料至遠端伺服器、封鎖競品插件  

本報告透過逆向工程揭露 `LSPDFRCN.API.dll` 的隱藏惡意行為。該檔案由中文網（LSPDFRCN）作為免費模組依賴散佈。作者聲稱其為無害的漢化前置庫，但分析證明其包含多項未經揭露的惡意功能。

---

## 🚨 主要發現

### 1. 磁碟掃描
在使用者不知情、未同意的情況下列舉遊戲目錄檔案。

```csharp
// LSPDFRCN.Core.FileScanning.IGameDirectoryScanner
internal interface IGameDirectoryScanner
{
    A391AA64 Scan(string FC3FF18E = null);
}
```

- `C25CAE07` 類別實作此掃描器
- 記錄 `IsScanning` 狀態和 `LastScanTime` 時間戳
- 掃描過程對使用者完全不可見，使用者協定中從未提及

### 2. 裝置指紋蒐集
收集使用者硬體的唯一識別碼，包含 **7 種以上** `IDeviceIdComponent` 實作。

```csharp
[JsonProperty("Fingerprint")]
public string Fingerprint { get; }
```

蒐集內容包括：硬體識別碼、作業系統版本、安裝資訊。使用 `JsonProperty` 標註，以 JSON 格式序列化用於上傳。

### 3. 資料上傳至遠端伺服器
掃描結果和裝置指紋透過 HTTP POST 上傳。

```csharp
// PostJsonForFileScanAsync — 將掃描資料以 JSON 格式 POST 傳送
_003CPostJsonForFileScanAsync_003Ed__3 : IAsyncStateMachine
```

- 使用 `System.Net.Http.HttpClient`
- 上傳檔案掃描結果、裝置指紋、登錄檔資料
- 背景非同步靜默執行，使用者無任何提示

### 4. 競品插件封鎖
偵測並禁用其他中文漢化插件。

```csharp
public extern bool IsBlocked { get; }
```

`A339C28A` 和 `D7EC65E0` 類別均包含此屬性，強制使用者只能使用中文網生態內的產品。

### 5. 登錄檔讀取
讀取 Windows 系統登錄檔，從未向使用者揭露。

```csharp
using RegistryKey registryKey = Registry.LocalMachine.OpenSubKey(P_0, writable: false);
object value = registryKey.GetValue(P_1);
```

### 6. 遠端程式碼下載與執行
- `DownloadPluginManifestAsync` — 下載插件清單
- `DownloadPluginAsync` — 下載插件本體
- `VerifyPluginHashAsync` — 雜湊驗證
- `NeedsDownloadAsync` — 檢查更新

### 7. 加密通訊
使用 AES 加密混淆 C2 流量。

```csharp
CryptoStream cryptoStream = new CryptoStream(
    memoryStream, rijndael.CreateDecryptor(), CryptoStreamMode.Write);

internal class HybridEncryptedResult
{
    public string EncryptedData { get; }
    public string EncryptedKey { get; }
    public string EncryptedIV { get; }
}
```

---

## 🔬 技術摘要

| 類別 | 關鍵類別/方法 | 惡意行為 |
|------|------------|---------|
| 掃描 | `IGameDirectoryScanner.Scan()` | 列舉遊戲目錄檔案 |
| 指紋 | `IDeviceIdComponent`（7種）| 蒐集硬體和作業系統指紋 |
| 上傳 | `PostJsonForFileScanAsync` | HTTP POST 上傳掃描結果 |
| 封鎖 | `IsBlocked` 屬性 | 禁用競品插件 |
| 登錄檔 | `Registry.LocalMachine.OpenSubKey` | 讀取系統登錄檔 |
| 下載 | `DownloadPluginManifestAsync` | 遠端程式碼載入 |
| 加密 | `HybridEncryptedResult` + `Rijndael` | C2 通訊流量混淆 |

| 統計項 | 數量 |
|--------|------|
| 反編譯 C# 原始檔 | 108 |
| 可讀類別定義 | 132 |
| 惡意證據條目 | 38 |

---

## ⚖️ 揭露時間線

| 日期 | 事件 |
|------|------|
| 2026-06 | 逆向工程分析 |
| 2026-06-27 | 安全報告公開發佈 |

---

## ❓ 常見質疑與回應

**Q: 分析者身分和動機？**  
本報告由社群安全研究者獨立完成，與任何商業實體無關。安全研究的有效性不取決於研究者身分，程式碼行為是客觀事實。

**Q: 上傳行為只有程式碼分析，缺乏網路抓包證據？**  
程式碼分析是安全研究的標準方法。`PostJsonForFileScanAsync`（以JSON POST傳送檔案掃描結果）、`HttpClient`、`HybridEncryptedResult`（加密資料結構）的存在，本身就是上傳功能已被設計實作的確定證據。歡迎其他研究者進行網路抓包驗證。

---

## ⚠️ 免責聲明

本研究服務於公共利益，告知使用者其所安裝軟體中的未揭露行為。分析基於公開可獲得的散佈檔案。
