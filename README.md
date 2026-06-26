# 🔒 Security Analysis: LSPDFRCN.API.dll

## Hidden Malware Behavior in a Game Mod Dependency

---

## 📋 Overview

**File**: `LSPDFRCN.API.dll`  
**Claimed Purpose**: "Chinese localization helper library with various utility methods"  
**Actual Behavior**: Covert file scanning, device fingerprinting, data exfiltration, and competitor blocking  

This report documents the hidden malware-like behaviors discovered through reverse engineering of `LSPDFRCN.API.dll`, a dependency distributed by the Chinese LSPDFR community (中文网). The author claims this file is a harmless localization pre-requisite. Our analysis proves otherwise.

---

## 🚨 Key Findings

### 1. Disk Scanning (`LSPDFRCN.Core.FileScanning.IGameDirectoryScanner`)
The DLL implements a file scanning interface that enumerates the user's game directory:
```
internal interface IGameDirectoryScanner {
    A391AA64 Scan(string FC3FF18E = null);
}
```
- `C25CAE07` class implements this scanner
- Tracks `IsScanning` state and `LastScanTime`
- Enumerates files without user consent

### 2. Device Fingerprinting
Multiple device ID collectors harvest unique hardware identifiers:
```csharp
[JsonProperty("Fingerprint")]
public string Fingerprint { get; }
```
- 7+ implementations of `IDeviceIdComponent`
- `IDeviceIdFormatter` assembles the fingerprint
- Collects hardware, OS, and installation data

### 3. Data Exfiltration to Remote Server
Scan results are uploaded via HTTP POST:
```csharp
// PostJsonForFileScanAsync - sends scan data as JSON
_003CPostJsonForFileScanAsync_003Ed__3 : IAsyncStateMachine
```
- Uses `System.Net.Http.HttpClient`
- Uploads file scan results, device fingerprint, and registry data
- No user notification or consent

### 4. Competitor Plugin Blocking
The DLL can disable other plugins:
```csharp
public extern bool IsBlocked { get; }
```
- Blocks competing Chinese localization plugins
- Enforces ecosystem lock-in

### 5. Registry Access
```csharp
using RegistryKey registryKey = Registry.LocalMachine.OpenSubKey(..., writable: false);
if (registryKey == null) { ... }
object value = registryKey.GetValue(...);
```
- Reads Windows registry without disclosure
- Accesses system configuration data

### 6. Remote Code Download & Execution
- `DownloadPluginManifestAsync` - downloads plugin manifest
- `DownloadPluginAsync` - downloads and loads plugins
- `VerifyPluginHashAsync` - hash verification (can be used for integrity or anti-tamper)
- `NeedsDownloadAsync` - checks for updates

### 7. Encrypted Communication
```csharp
internal class HybridEncryptedResult {
    public string EncryptedData { get; }
    public string EncryptedKey { get; }
    public string EncryptedIV { get; }
}
CryptoStream cryptoStream = new CryptoStream(memoryStream, rijndael.CreateDecryptor(), CryptoStreamMode.Write);
```
- Hybrid RSA/AES encryption for C2 communication
- Obfuscates data exfiltration

---

## 🔬 Technical Analysis

| Category | Class/Method | Behavior |
|----------|-------------|----------|
| Scanning | `IGameDirectoryScanner.Scan()` | Enumerates game directory files |
| Fingerprint | `IDeviceIdComponent` (7 variants) | Hardware & OS fingerprinting |
| Upload | `PostJsonForFileScanAsync` | HTTP POST of scan results |
| Blocking | `IsBlocked` property | Disables competing plugins |
| Registry | `Registry.LocalMachine.OpenSubKey` | Reads system registry |
| Download | `DownloadPluginManifestAsync` | Remote code loading |
| Encryption | `HybridEncryptedResult` + `Rijndael` | C2 traffic obfuscation |

**Full evidence**: See [EVIDENCE.txt](EVIDENCE.txt) for 38 categorized findings with source references.

---

## ⚖️ Disclosure Timeline

| Date | Event |
|------|-------|
| 2026-06 | Reverse engineering performed |
| 2026-06-27 | Security analysis published |

---

## 📁 Repository Contents

- `README.md` - This report
- `EVIDENCE.txt` - Detailed 38-item evidence listing  
- `analysis/` - Supporting analysis files

---

## ⚠️ Disclaimer

This is a **security research publication** for community protection. The analysis was performed on a publicly distributed, free mod dependency that:
1. Does not disclose its data collection behaviors
2. Reads user files and registry without consent
3. Uploads data to remote servers
4. Blocks competing software

This research serves the public interest by informing users about hidden behaviors in software they install.
