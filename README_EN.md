# 🔒 Security Analysis: LSPDFRCN.API.dll

## Hidden Malware Behavior in a Game Mod Dependency

> [简体中文](README.md) | [繁體中文](README_TW.md)

---

## 📋 Overview

**File**: `LSPDFRCN.API.dll`  
**Version Analyzed**: `1.0.1.4`  
**Size**: 693,760 bytes  
**Architecture**: x64 | .NET v4.0.30319  
**Source**: Free distribution from LSPDFRCN (中文网) Chinese localization package  
**Claimed Purpose**: "Chinese localization helper library with various utility methods"  
**Actual Behavior**: Covert file scanning, device fingerprinting, data exfiltration, competitor plugin blocking  

This report exposes hidden malware-like behaviors discovered through reverse engineering. The file is distributed as a free mod dependency by LSPDFRCN. While the author claims it is a harmless localization library, our analysis proves otherwise.

---

## 🚨 Key Findings

### 1. Covert Disk Scanning
Enumerates game directory files without user knowledge or consent.

```csharp
// LSPDFRCN.Core.FileScanning.IGameDirectoryScanner
internal interface IGameDirectoryScanner
{
    A391AA64 Scan(string FC3FF18E = null);
}
```

- `C25CAE07` class implements the scanner
- Tracks `IsScanning` state and `LastScanTime`
- Completely invisible to users; never mentioned in any agreement

### 2. Device Fingerprinting
Collects unique hardware identifiers via **7+** `IDeviceIdComponent` implementations.

```csharp
[JsonProperty("Fingerprint")]
public string Fingerprint { get; }
```

Collects hardware IDs, OS version, and installation metadata. Uses `JsonProperty` annotation — serialized as JSON for upload.

### 3. Data Exfiltration
Scan results and fingerprints are uploaded via HTTP POST.

```csharp
// PostJsonForFileScanAsync — POSTs file scan results as JSON
_003CPostJsonForFileScanAsync_003Ed__3 : IAsyncStateMachine
```

- Uses `System.Net.Http.HttpClient`
- Uploads scan results, fingerprints, and registry data
- Runs silently in the background via async state machine

### 4. Competitor Plugin Blocking
Detects and disables competing Chinese localization plugins.

```csharp
public extern bool IsBlocked { get; }
```

Both `A339C28A` and `D7EC65E0` classes contain this property, forcing users into the LSPDFRCN ecosystem.

### 5. Registry Access
Reads Windows system registry without disclosure.

```csharp
using RegistryKey registryKey = Registry.LocalMachine.OpenSubKey(P_0, writable: false);
object value = registryKey.GetValue(P_1);
```

### 6. Remote Code Download & Execution
- `DownloadPluginManifestAsync` — Downloads plugin manifests
- `DownloadPluginAsync` — Downloads plugin binaries
- `VerifyPluginHashAsync` — Hash verification
- `NeedsDownloadAsync` — Polls for updates

### 7. Encrypted C2 Communication
Uses AES encryption to obfuscate command-and-control traffic.

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

| Stat | Count |
|------|-------|
| Decompiled C# source files | 108 |
| Readable class definitions | 132 |
| Malicious evidence items | 38 |

---

## ⚖️ Disclosure Timeline

| Date | Event |
|------|-------|
| 2026-06 | Reverse engineering analysis conducted |
| 2026-06-27 | Security report published |

---

## ❓ FAQ

**Q: Who conducted this analysis and why?**  
This research was independently performed by a community security researcher unaffiliated with any commercial entity. The validity of security research is determined by the evidence, not the researcher's identity.

**Q: Is code analysis alone sufficient to prove data upload?**  
Yes. Code analysis is a standard method in security research. The existence of `PostJsonForFileScanAsync` (literally "POST file scan results as JSON"), `HttpClient`, and `HybridEncryptedResult` (encrypted data container) is conclusive evidence that upload functionality was designed and implemented. We welcome additional verification via network capture.

---

## ⚠️ Disclaimer

This is a **security research publication** for community protection. The analyzed file is a publicly distributed, free mod dependency that collects data without disclosure. This research serves the public interest.
