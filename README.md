# 🔒 LSPDFRCN.API.dll 安全分析报告

## 隐藏于游戏模组依赖中的恶意行为

> [繁體中文](README_TW.md) | [English](README_EN.md)

---

## 📋 概述

**文件名称**：`LSPDFRCN.API.dll`  
**分析版本**：`1.0.1.4`  
**文件大小**：693,760 字节  
**架构**：x64 | .NET v4.0.30319  
**来源**：中文网（LSPDFRCN）免费分发的汉化前置包  
**声称用途**："汉化前置库，内含各种实用方法"  
**实际行为**：秘密扫描用户文件、采集设备指纹、上传数据至远程服务器、封锁竞品插件  

本报告通过逆向工程揭露 `LSPDFRCN.API.dll` 的隐藏恶意行为。该文件由中文网（LSPDFRCN）作为免费模组依赖分发。作者声称其为无害的汉化前置库，但分析证明其包含多项未经披露的恶意功能。

---

## 🚨 主要发现

### 1. 磁盘扫描
在用户不知情、未同意的情况下列举游戏目录文件。

```csharp
// LSPDFRCN.Core.FileScanning.IGameDirectoryScanner
internal interface IGameDirectoryScanner
{
    A391AA64 Scan(string FC3FF18E = null);
}
```

- `C25CAE07` 类实现此扫描器
- 记录 `IsScanning` 状态和 `LastScanTime` 时间戳
- 扫描过程对用户完全不可见，用户协议中从未提及

### 2. 设备指纹采集
收集用户硬件的唯一标识符，包含 **7 种以上** `IDeviceIdComponent` 实现。

```csharp
[JsonProperty("Fingerprint")]
public string Fingerprint { get; }
```

采集内容包括：硬件标识、操作系统版本、安装信息。使用 `JsonProperty` 标注，以 JSON 格式序列化用于上传。

### 3. 数据上传至远程服务器
扫描结果和设备指纹通过 HTTP POST 上传。

```csharp
// PostJsonForFileScanAsync — 将扫描数据以 JSON 格式 POST 发送
_003CPostJsonForFileScanAsync_003Ed__3 : IAsyncStateMachine
```

- 使用 `System.Net.Http.HttpClient`
- 上传文件扫描结果、设备指纹、注册表数据
- 后台异步静默运行，用户无任何提示

### 4. 竞品插件封锁
检测并禁用其他中文汉化插件。

```csharp
public extern bool IsBlocked { get; }
```

`A339C28A` 和 `D7EC65E0` 类均包含此属性，强制用户只能使用中文网生态内的产品。

### 5. 注册表读取
读取 Windows 系统注册表，从未向用户披露。

```csharp
using RegistryKey registryKey = Registry.LocalMachine.OpenSubKey(P_0, writable: false);
object value = registryKey.GetValue(P_1);
```

### 6. 远程代码下载与执行
- `DownloadPluginManifestAsync` — 下载插件清单
- `DownloadPluginAsync` — 下载插件本体
- `VerifyPluginHashAsync` — 哈希验证
- `NeedsDownloadAsync` — 检查更新

### 7. 加密通信
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

## 🔬 技术摘要

| 类别 | 关键类/方法 | 恶意行为 |
|------|------------|---------|
| 扫描 | `IGameDirectoryScanner.Scan()` | 枚举游戏目录文件 |
| 指纹 | `IDeviceIdComponent`（7种）| 采集硬件和操作系统指纹 |
| 上传 | `PostJsonForFileScanAsync` | HTTP POST 上传扫描结果 |
| 封锁 | `IsBlocked` 属性 | 禁用竞品插件 |
| 注册表 | `Registry.LocalMachine.OpenSubKey` | 读取系统注册表 |
| 下载 | `DownloadPluginManifestAsync` | 远程代码加载 |
| 加密 | `HybridEncryptedResult` + `Rijndael` | C2 通信流量混淆 |

| 统计项 | 数量 |
|--------|------|
| 反编译 C# 源文件 | 108 |
| 可读类定义 | 132 |
| 恶意证据条目 | 38 |

---

## ⚖️ 披露时间线

| 日期 | 事件 |
|------|------|
| 2026-06 | 逆向工程分析 |
| 2026-06-27 | 安全报告公开发布 |

---

## ❓ 常见质疑与回应

**Q: 分析者身份和动机？**  
本报告由社区安全研究者独立完成，与任何商业实体无关。安全研究的有效性不取决于研究者身份，代码行为是客观事实。

**Q: 上传行为只有代码分析，缺乏网络抓包证据？**  
代码分析是安全研究的标准方法。`PostJsonForFileScanAsync`（以JSON POST发送文件扫描结果）、`HttpClient`、`HybridEncryptedResult`（加密数据结构）的存在，本身就是上传功能已被设计实现的确定证据。欢迎其他研究者进行网络抓包验证。

---

## ⚠️ 免责声明

本研究服务于公共利益，告知用户其所安装软件中的未披露行为。分析基于公开可获得的分发文件。
