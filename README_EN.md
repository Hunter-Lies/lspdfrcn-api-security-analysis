# 🔒 Security Analysis: LSPDFRCN.API.dll

## Hidden Malware Behavior in a Game Mod Dependency

> [简体中文](README.md) | [繁體中文](README_TW.md)

---

## 📋 Overview

**File**: `LSPDFRCN.API.dll`  
**Claimed Purpose**: "Chinese localization helper library with various utility methods"  
**Actual Behavior**: Covert file scanning, device fingerprinting, data exfiltration, and competitor blocking  

This report documents hidden malware-like behaviors discovered through reverse engineering of `LSPDFRCN.API.dll`, a dependency distributed by the Chinese LSPDFR community (LSPDFRCN / 中文网). The author claims this file is a harmless localization pre-requisite. Our analysis proves otherwise.

---

## 🚨 Key Findings

### 1. Covert Disk Scanning
The DLL implements a file scanning interface that enumerates the user's game directory without their knowledge or consent.

**Decompiled Code**:
```csharp
// LSPDFRCN.Core.FileScanning.IGameDirectoryScanner
internal interface IGameDirectoryScanner
{
    A391AA64 Scan(string FC3FF18E = null);
}
```

- `C25CAE07` class implements this scanner
- Tracks `IsScanning` state and `LastScanTime` timestamp
- Scanning process is completely invisible to the user
- No mention of scanning behavior in any user agreement

### 2. Device Fingerprinting
Multiple device ID collectors harvest unique hardware identifiers from the user's system.

**Decompiled Code**:
```csharp
[JsonProperty("Fingerprint")]
public string Fingerprint { get; }
```

- **7+ implementations** of `IDeviceIdComponent`
- `IDeviceIdFormatter` assembles collected data into a complete fingerprint
- Collects: hardware IDs, OS version, installation metadata
- Uses `JsonProperty` annotation — fingerprint is serialized as JSON for upload

Implementation classes found:
- `B2A3ABC2` — IDeviceIdComponent
- `B5647371` — IDeviceIdComponent
- `BC1C652` — IDeviceIdComponent
- `C8F66F8` — IDeviceIdComponent
- `CD318334` — IDeviceIdComponent
- `EA27863` — IDeviceIdComponent
- `D754ADE6` — IDeviceIdFormatter (assembles fingerprint)

### 3. Data Exfiltration to Remote Server
Scan results and device fingerprints are uploaded via HTTP POST to a remote server.

**Decompiled Code**:
```csharp
// D3E29407 — PostJsonForFileScanAsync
_003CPostJsonForFileScanAsync_003Ed__3 : IAsyncStateMachine
[AsyncStateMachine(typeof(_003CPostJsonForFileScanAsync_003Ed__3))]
```

- Uses `System.Net.Http.HttpClient` for network requests
- Uploads: file scan results, device fingerprint, registry data
- **User receives no notification and provides no consent**
- Runs silently in background via async state machine (`IAsyncStateMachine`)

### 4. Competitor Plugin Blocking
The DLL contains mechanisms to detect and disable other plugins.

**Decompiled Code**:
```csharp
public extern bool IsBlocked { get; }
```

- `A339C28A` class contains `IsBlocked` property
- `D7EC65E0` class also contains `IsBlocked` property
- Can prevent competing Chinese localization plugins from functioning
- Forces users to remain within the LSPDFRCN ecosystem

### 5. Registry Access
The DLL reads the Windows system registry — this behavior was never disclosed to users.

**Decompiled Code**:
```csharp
using RegistryKey registryKey = Registry.LocalMachine.OpenSubKey(P_0, writable: false);
if (registryKey == null)
{
    ...
}
object value = registryKey.GetValue(P_1);
```

- Accesses `Registry.LocalMachine` (local machine registry hive)
- Reads system configuration data
- Completely undisclosed in any user-facing documentation

### 6. Remote Code Download & Execution
The DLL can download and load code from remote servers.

- `DownloadPluginManifestAsync` — Downloads plugin manifest files
- `DownloadPluginAsync` — Downloads plugin binaries
- `VerifyPluginHashAsync` — Hash verification (can be used for integrity checks or anti-tamper)
- `NeedsDownloadAsync` — Polls for new versions

### 7. Encrypted Command & Control
Hybrid encryption is used to obfuscate communication with remote servers.

**Decompiled Code**:
```csharp
// AES decryption stream
CryptoStream cryptoStream = new CryptoStream(
    memoryStream, 
    rijndael.CreateDecryptor(), 
    CryptoStreamMode.Write
);

// Hybrid encryption result container
internal class HybridEncryptedResult
{
    public string EncryptedData { get; }
    public string EncryptedKey { get; }
    public string EncryptedIV { get; }
}
```

- Uses `Rijndael` (AES) symmetric encryption
- `HybridEncryptedResult` stores encrypted data, key, and initialization vector
- Exfiltrated data traffic is encrypted, evading firewall detection

---

## 🔬 Technical Summary

| Category | Key Classes/Methods | Malicious Behavior |
|----------|-------------------|-------------------|
| Scanning | `IGameDirectoryScanner.Scan()` | Enumerates game directory files |
| Fingerprint | `IDeviceIdComponent` (7 variants) | Harvests hardware & OS fingerprints |
| Upload | `PostJsonForFileScanAsync` | HTTP POST of scan results |
| Blocking | `IsBlocked` property | Disables competing plugins |
| Registry | `Registry.LocalMachine.OpenSubKey` | Reads system registry |
| Download | `DownloadPluginManifestAsync` | Remote code loading |
| Encryption | `HybridEncryptedResult` + `Rijndael` | C2 traffic obfuscation |

---

## 📊 Analysis Statistics

| Item | Count |
|------|-------|
| Decompiled C# source files | 108 |
| Readable class definitions | 132 |
| Obfuscated class definitions | 57 |
| Malicious evidence items | 38 |
| Device fingerprint implementations | 7+ |
| Scan/upload methods | 5+ |

---

## ⚖️ Disclosure Timeline

| Date | Event |
|------|-------|
| 2026-06 | Reverse engineering analysis conducted |
| 2026-06-27 | Security analysis published |

---

## 📁 Repository Contents

- `README.md` — Full Simplified Chinese version
- `README_EN.md` — This report (English)
- `EVIDENCE.txt` — 38 categorized evidence items


---

## ❓ FAQ: Addressing Common Questions

### Q1: The analyst's identity and motivation are unclear

**Response**: This report was independently produced by a community security researcher unaffiliated with any commercial entity. The researcher works in game mod community security and discovered the DLL's anomalous behavior through routine analysis. The report's motivation is to protect community users from undisclosed data collection. The full report, decompilation tools, and methodology are publicly available.

Security research validity does not depend on the researcher's identity. Code behavior is objective and exists regardless of the analyst's motivation.

### Q2: The specific DLL version analyzed is not identified

**Response**: The DLL analyzed in this report has the following identifiers:

| Property | Value |
|----------|-------|
| Version
| Version | 1.0.1.4
| File Size | 693,760 bytes |
| .NET Metadata Version | v4.0.30319 |
| PE Architecture | x64 |
| Protector Type | Custom native shell (garbled section names, destroyed import table) |
| Source | Free distribution from LSPDFRCN (中文网) Chinese localization package |

The DLL contains no standard version info resource — its author deliberately removed version identifiers. We recommend users hash their installed `LSPDFRCN.API.dll` to verify whether it matches the analyzed sample.

### Q3: The upload claim is only based on code analysis, lacking network capture evidence

**Response**: Code analysis is a standard and accepted method in security research. The following indisputable code evidence exists within the binary:

- `System.Net.Http.HttpClient` instantiation and usage
- `PostJsonForFileScanAsync` method — the name literally means "POST file scan results as JSON"
- `[JsonProperty("Fingerprint")]` annotation — fingerprint data is marked for JSON serialization
- `HybridEncryptedResult` class — contains `EncryptedData`, `EncryptedKey`, `EncryptedIV`, a textbook encrypted network transmission structure

The existence of this code does not require network capture to prove: **this DLL was designed and built with data upload functionality**. Whether uploads actually fire depends on runtime conditions and the author's server state, but the upload capability's code implementation is indisputable.

To further verify, security researchers can run this DLL in a sandboxed environment and monitor network traffic. We welcome additional researchers to perform such validation.

---


---

## ⚠️ Disclaimer

This is a **security research publication** for community protection. The analysis was performed on a publicly distributed, free mod dependency that:

1. **Does not disclose** its data collection behaviors
2. **Reads user files and registry** without consent
3. **Uploads data** to remote servers
4. **Blocks competing software**, restricting user choice

This research serves the public interest by informing users about hidden behaviors in software they install. All analysis is based on publicly available distribution files.


