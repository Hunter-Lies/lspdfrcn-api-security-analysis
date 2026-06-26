# 🔒 LSPDFRCN.API.dll 安全分析报告 | Security Analysis

## 隐藏于游戏模组中的恶意行为 | Hidden Malware in Game Mod

---

> [English version below](#-english-version)

---

## 📋 概述

**文件**: `LSPDFRCN.API.dll`  
**声称用途**: "汉化前置库，内含各种实用方法"  
**实际行为**: 秘密扫描用户文件、采集设备指纹、上传数据至远程服务器、封锁竞品插件  

本报告通过逆向工程揭露 `LSPDFRCN.API.dll` 的隐藏恶意行为。该文件由中文网（LSPDFRCN）作为免费依赖分发，作者声称其为无害的汉化前置库。我们的分析证明了事实并非如此。

---

## 🚨 主要发现

### 1. 磁盘扫描 | Disk Scanning
DLL 实现了文件扫描接口，在用户不知情的情况下枚举游戏目录：
```csharp
internal interface IGameDirectoryScanner {
    A391AA64 Scan(string FC3FF18E = null);
}
```
- `C25CAE07` 类实现此扫描器
- 记录 `IsScanning` 状态和 `LastScanTime`
- 未经用户同意枚举文件

### 2. 设备指纹采集 | Device Fingerprinting
多个设备ID采集器收集唯一硬件标识符：
```csharp
[JsonProperty("Fingerprint")]
public string Fingerprint { get; }
```
- 7+ 种 `IDeviceIdComponent` 实现
- `IDeviceIdFormatter` 组装指纹
- 采集硬件、操作系统和安装数据

### 3. 数据外泄 | Data Exfiltration
扫描结果通过 HTTP POST 上传至远程服务器：
```csharp
// PostJsonForFileScanAsync - 将扫描数据作为JSON发送
```
- 使用 `System.Net.Http.HttpClient`
- 上传文件扫描结果、设备指纹和注册表数据
- 无用户通知或同意

### 4. 竞品插件封锁 | Competitor Blocking
DLL 可以禁用其他插件：
```csharp
public extern bool IsBlocked { get; }
```
- 封锁竞争的中文汉化插件
- 强制生态锁定

### 5. 注册表访问 | Registry Access
```csharp
using RegistryKey registryKey = Registry.LocalMachine.OpenSubKey(..., writable: false);
object value = registryKey.GetValue(...);
```
- 读取 Windows 注册表，未披露
- 访问系统配置数据

### 6. 远程代码下载与执行 | Remote Code Execution
- `DownloadPluginManifestAsync` - 下载插件清单
- `DownloadPluginAsync` - 下载并加载插件
- `VerifyPluginHashAsync` - 哈希验证
- `NeedsDownloadAsync` - 检查更新

### 7. 加密通信 | Encrypted Communication
```csharp
CryptoStream cryptoStream = new CryptoStream(memoryStream, rijndael.CreateDecryptor(), CryptoStreamMode.Write);
```
- 混合 RSA/AES 加密用于 C2 通信
- 混淆数据外泄流量

---

## 🔬 技术摘要 | Technical Summary

| 类别 | 类/方法 | 行为 |
|------|---------|------|
| 扫描 | `IGameDirectoryScanner.Scan()` | 枚举游戏目录文件 |
| 指纹 | `IDeviceIdComponent` (7种) | 硬件和操作系统指纹 |
| 上传 | `PostJsonForFileScanAsync` | HTTP POST 扫描结果 |
| 封锁 | `IsBlocked` 属性 | 禁用竞品插件 |
| 注册表 | `Registry.LocalMachine.OpenSubKey` | 读取系统注册表 |
| 下载 | `DownloadPluginManifestAsync` | 远程代码加载 |
| 加密 | `HybridEncryptedResult` + `Rijndael` | C2 流量混淆 |

---

## ⚖️ 披露时间线 | Disclosure Timeline

| 日期 | 事件 |
|------|------|
| 2026-06 | 逆向工程分析 |
| 2026-06-27 | 安全分析公开发布 |

---

## ⚠️ 免责声明 | Disclaimer

这是为保护社区而发布的**安全研究出版物**。分析针对的是公开分发的免费模组依赖项，该依赖项：
1. 未披露其数据收集行为
2. 未经同意读取用户文件和注册表
3. 向远程服务器上传数据
4. 封锁竞品软件

本研究通过告知用户其所安装软件中的隐藏行为来服务公共利益。

---

## 🇬🇧 English Version

### Overview
**File**: `LSPDFRCN.API.dll`  
**Claimed**: "Chinese localization helper with utility methods"  
**Actual**: Covert file scanning, device fingerprinting, data exfiltration, competitor plugin blocking  

This report exposes hidden malware-like behaviors discovered through reverse engineering.

### Key Findings
1. **Disk Scanning** — `IGameDirectoryScanner` enumerates game directory files without consent
2. **Device Fingerprinting** — 7+ `IDeviceIdComponent` implementations harvest hardware IDs, with `[JsonProperty("Fingerprint")]` annotation
3. **Data Exfiltration** — `PostJsonForFileScanAsync` uploads scan results + registry data via `HttpClient`
4. **Competitor Blocking** — `IsBlocked` property disables competing plugins
5. **Registry Access** — `Registry.LocalMachine.OpenSubKey` reads system registry
6. **Remote Code Execution** — `DownloadPluginManifestAsync` downloads and loads remote code
7. **Encrypted C2** — `HybridEncryptedResult` + `Rijndael` obfuscates exfiltration traffic

### This is a security research publication serving the public interest.
