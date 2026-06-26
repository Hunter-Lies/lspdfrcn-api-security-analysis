# 🔒 LSPDFRCN.API.dll 安全分析報告

## 隱藏於遊戲模組依賴中的惡意行為

> [简体中文](README.md) | [English](README_EN.md)

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

## ❓ 常見質疑與回應

### 質疑一：分析者身分和動機不明

**回應**：本報告由社群安全研究者獨立完成，與任何商業實體無關。研究者從事遊戲模組社群安全工作，發現該 DLL 的行為異常後進行逆向分析。報告的動機是保護社群使用者免受未揭露的資料收集行為侵害。報告全文、反編譯工具及方法論均公開可查。

安全研究不因研究者身分而改變事實。程式碼行為是客觀存在的，不隨分析者的動機而轉移。

### 質疑二：未指明分析的 DLL 版本

**回應**：本報告分析的 DLL 檔案識別資訊如下：

| 屬性 | 值 |
|------|-----|
| 檔案大小 | 693,760 位元組 |
| .NET 中繼資料版本 | v4.0.30319 |
| PE 架構 | x64 |
| 保護器類型 | 自訂原生殼（段名損壞、匯入表銷毀） |
| 來源 | 中文網（LSPDFRCN）免費散佈的漢化前置包 |

該 DLL 未包含標準版本資訊資源，其作者刻意移除了版本識別碼。我們建議使用者自行對已安裝的 `LSPDFRCN.API.dll` 進行雜湊校驗以確認是否為同一檔案。

### 質疑三：上傳行為僅基於程式碼分析，缺乏網路抓包證據

**回應**：程式碼分析是安全研究的標準方法。檔案中明確存在以下無可辯駁的程式碼證據：

- `System.Net.Http.HttpClient` 的實例化和使用
- `PostJsonForFileScanAsync` 方法——名稱直接表明"將檔案掃描結果以 JSON 格式 POST 傳送"
- `[JsonProperty("Fingerprint")]` 標註——裝置指紋資料被標記為 JSON 序列化
- `HybridEncryptedResult` 類別——包含 `EncryptedData`、`EncryptedKey`、`EncryptedIV`，這是典型的加密網路傳輸結構

以上程式碼的存在不需要網路抓包即可證明：**該 DLL 設計並實作了資料上傳功能**。是否實際觸發了上傳取決於執行環境和作者的伺服器端狀態，但上傳能力的程式碼實作是確定無疑的。

要進一步驗證，安全研究人員可以在沙箱環境中執行該 DLL 並監控網路流量。我們歡迎更多研究者進行此類驗證。

---


---

## ⚠️ 免責聲明

這是為保護社群而發佈的**安全研究出版物**。分析針對的是公開散佈的免費模組依賴項，該依賴項：

1. **未揭露**其資料收集行為
2. **未經同意**讀取使用者檔案和登錄檔
3. **向遠端伺服器上傳**使用者資料
4. **封鎖**競品軟體，限制使用者選擇

本研究的目的在於告知使用者其所安裝軟體中的隱藏行為，服務於公共利益。所有分析均基於公開可獲得的散佈檔案。



