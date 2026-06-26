# 🔒 LSPDFRCN.API.dll 安全分析報告

## 隱藏於遊戲模組依賴中的惡意行為

> [简体中文](README.md) | [English](README_EN.md) | [English](README_EN.md)

---

## 📋 概述

**檔案名稱**: `LSPDFRCN.API.dll`  
**聲稱用途**: "漢化前置庫，內含各種實用方法"  
**實際行為**: 秘密掃描使用者檔案、蒐集裝置指紋、上傳資料至遠端伺服器、封鎖競品插件  

本報告透過逆向工程揭露 `LSPDFRCN.API.dll` 的隱藏惡意行為。該檔案由中文網（LSPDFRCN）作為免費模組依賴發佈，作者聲稱其為無害的漢化前置庫。我們的分析證明事實並非如此。

---

## 🚨 主要發現

### 1. 磁碟掃描
該 DLL 實作了檔案掃描介面，在使用者不知情、未同意的情況下列舉遊戲目錄中的所有檔案。

**反編譯程式碼**:
```csharp
// LSPDFRCN.Core.FileScanning.IGameDirectoryScanner
internal interface IGameDirectoryScanner
{
    A391AA64 Scan(string FC3FF18E = null);
}
```

- `C25CAE07` 類別實作了此掃描器
- 記錄 `IsScanning` 狀態和 `LastScanTime` 時間戳
- 掃描過程對使用者完全不可見
- 使用者協定中從未提及任何掃描行為

### 2. 裝置指紋蒐集
該 DLL 包含多個裝置 ID 蒐集元件，收集使用者硬體的唯一識別碼。

**反編譯程式碼**:
```csharp
[JsonProperty("Fingerprint")]
public string Fingerprint { get; }
```

- **7種以上** `IDeviceIdComponent` 的實作類別
- `IDeviceIdFormatter` 將蒐集資料組裝為完整指紋
- 蒐集內容包括：硬體識別碼、作業系統版本、安裝資訊
- 使用 `JsonProperty` 標註，說明指紋資料以 JSON 格式序列化

涉及的實作類別：
- `B2A3ABC2` - IDeviceIdComponent
- `B5647371` - IDeviceIdComponent  
- `BC1C652` - IDeviceIdComponent
- `C8F66F8` - IDeviceIdComponent
- `CD318334` - IDeviceIdComponent
- `EA27863` - IDeviceIdComponent
- `D754ADE6` - IDeviceIdFormatter (組裝指紋)

### 3. 資料外洩至遠端伺服器
掃描結果和裝置指紋透過 HTTP POST 請求上傳至遠端伺服器。

**反編譯程式碼**:
```csharp
// D3E29407 - PostJsonForFileScanAsync
_003CPostJsonForFileScanAsync_003Ed__3 : IAsyncStateMachine
[AsyncStateMachine(typeof(_003CPostJsonForFileScanAsync_003Ed__3))]
```

- 使用 `System.Net.Http.HttpClient` 進行網路請求
- 上傳內容包括：檔案掃描結果、裝置指紋、登錄檔資料
- **使用者完全不知情，沒有任何提示或同意流程**
- 使用非同步狀態機（`IAsyncStateMachine`）在背景靜默執行

### 4. 競品插件封鎖
該 DLL 內建了偵測和封鎖其他插件的機制。

**反編譯程式碼**:
```csharp
public extern bool IsBlocked { get; }
```

- `A339C28A` 類別包含 `IsBlocked` 屬性
- `D7EC65E0` 類別同樣包含 `IsBlocked` 屬性  
- 可以阻止競爭的中文漢化插件正常運作
- 強制使用者只能使用中文網生態內的產品

### 5. 登錄檔存取
該 DLL 讀取 Windows 系統登錄檔，此行為從未向使用者揭露。

**反編譯程式碼**:
```csharp
using RegistryKey registryKey = Registry.LocalMachine.OpenSubKey(P_0, writable: false);
if (registryKey == null)
{
    ...
}
object value = registryKey.GetValue(P_1);
```

- 存取 `Registry.LocalMachine`（本機登錄檔）
- 讀取系統設定資料
- 在使用者協定中完全未提及

### 6. 遠端程式碼下載與執行
該 DLL 可從遠端伺服器下載並載入程式碼。

- `DownloadPluginManifestAsync` — 下載插件清單檔案
- `DownloadPluginAsync` — 下載插件本體
- `VerifyPluginHashAsync` — 驗證檔案雜湊（可用於完整性檢查或反竄改偵測）
- `NeedsDownloadAsync` — 檢查是否有新版本需要下載

### 7. 加密通訊
使用混合加密方案混淆與遠端伺服器的通訊流量。

**反編譯程式碼**:
```csharp
// AES 解密串流
CryptoStream cryptoStream = new CryptoStream(
    memoryStream, 
    rijndael.CreateDecryptor(), 
    CryptoStreamMode.Write
);

// 混合加密結果
internal class HybridEncryptedResult
{
    public string EncryptedData { get; }
    public string EncryptedKey { get; }
    public string EncryptedIV { get; }
}
```

- 使用 `Rijndael`（AES）對稱加密
- `HybridEncryptedResult` 類別包含加密資料、金鑰和初始化向量
- 資料外洩流量經過加密，難以被防火牆偵測

---

## 🔬 技術摘要

| 類別 | 關鍵類別/方法 | 惡意行為 |
|------|------------|---------|
| 掃描 | `IGameDirectoryScanner.Scan()` | 列舉遊戲目錄檔案 |
| 指紋 | `IDeviceIdComponent` (7種) | 蒐集硬體和作業系統指紋 |
| 上傳 | `PostJsonForFileScanAsync` | HTTP POST 上傳掃描結果 |
| 封鎖 | `IsBlocked` 屬性 | 禁用競品插件 |
| 登錄檔 | `Registry.LocalMachine.OpenSubKey` | 讀取系統登錄檔 |
| 下載 | `DownloadPluginManifestAsync` | 遠端程式碼載入 |
| 加密 | `HybridEncryptedResult` + `Rijndael` | C2 通訊流量混淆 |

---

## 📊 分析統計

| 項目 | 數量 |
|------|------|
| 反編譯 C# 原始檔 | 108 個 |
| 可讀類別定義 | 132 個 |
| 混淆類別定義 | 57 個 |
| 惡意證據條目 | 38 條 |
| 裝置指紋實作 | 7+ 類別 |
| 掃描/上傳方法 | 5+ 個 |

---

## ⚖️ 揭露時間線

| 日期 | 事件 |
|------|------|
| 2026-06 | 逆向工程分析開始 |
| 2026-06-27 | 安全分析報告公開發佈 |

---

## 📁 倉庫內容

- `README_TW.md` — 本報告（繁體中文版）
- `README.md` — 簡體中文版
- `README_EN.md` — 完整英文版報告
- `EVIDENCE.txt` — 38條分類證據清單

---

## ⚠️ 免責聲明

這是為保護社群而發佈的**安全研究出版物**。分析針對的是公開散佈的免費模組依賴項，該依賴項：

1. **未揭露**其資料收集行為
2. **未經同意**讀取使用者檔案和登錄檔
3. **向遠端伺服器上傳**使用者資料
4. **封鎖**競品軟體，限制使用者選擇

本研究的目的在於告知使用者其所安裝軟體中的隱藏行為，服務於公共利益。所有分析均基於公開可獲得的散佈檔案。

