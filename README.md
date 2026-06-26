# 🔒 LSPDFRCN.API.dll 安全分析报告

## 隐藏于游戏模组依赖中的恶意行为

> [繁體中文](README_TW.md) | [English](README_EN.md)

---

## 📋 概述

**文件名称**: `LSPDFRCN.API.dll`  
**声称用途**: "汉化前置库，内含各种实用方法"  
**实际行为**: 秘密扫描用户文件、采集设备指纹、上传数据至远程服务器、封锁竞品插件  

本报告通过逆向工程揭露 `LSPDFRCN.API.dll` 的隐藏恶意行为。该文件由中文网（LSPDFRCN）作为免费模组依赖分发，作者声称其为无害的汉化前置库。我们的分析证明了事实并非如此。

---

## 🚨 主要发现

### 1. 磁盘扫描
该 DLL 实现了文件扫描接口，在用户不知情、未同意的情况下枚举游戏目录中的所有文件。

**反编译代码**:
```csharp
// LSPDFRCN.Core.FileScanning.IGameDirectoryScanner
internal interface IGameDirectoryScanner
{
    A391AA64 Scan(string FC3FF18E = null);
}
```

- `C25CAE07` 类实现了此扫描器
- 记录 `IsScanning` 状态和 `LastScanTime` 时间戳
- 扫描过程对用户完全不可见
- 用户协议中从未提及任何扫描行为

### 2. 设备指纹采集
该 DLL 包含多个设备 ID 采集组件，收集用户硬件的唯一标识符。

**反编译代码**:
```csharp
[JsonProperty("Fingerprint")]
public string Fingerprint { get; }
```

- **7种以上** `IDeviceIdComponent` 的实现类
- `IDeviceIdFormatter` 将采集数据组装为完整指纹
- 采集内容包括：硬件标识、操作系统版本、安装信息
- 使用 `JsonProperty` 标注，说明指纹数据以 JSON 格式序列化

涉及的实现类：
- `B2A3ABC2` - IDeviceIdComponent
- `B5647371` - IDeviceIdComponent  
- `BC1C652` - IDeviceIdComponent
- `C8F66F8` - IDeviceIdComponent
- `CD318334` - IDeviceIdComponent
- `EA27863` - IDeviceIdComponent
- `D754ADE6` - IDeviceIdFormatter (组装指纹)

### 3. 数据外泄至远程服务器
扫描结果和设备指纹通过 HTTP POST 请求上传至远程服务器。

**反编译代码**:
```csharp
// D3E29407 - PostJsonForFileScanAsync
_003CPostJsonForFileScanAsync_003Ed__3 : IAsyncStateMachine
[AsyncStateMachine(typeof(_003CPostJsonForFileScanAsync_003Ed__3))]
```

- 使用 `System.Net.Http.HttpClient` 进行网络请求
- 上传内容包括：文件扫描结果、设备指纹、注册表数据
- **用户完全不知情，没有任何提示或同意流程**
- 使用异步状态机（`IAsyncStateMachine`）在后台静默运行

### 4. 竞品插件封锁
该 DLL 内置了检测和封锁其他插件的机制。

**反编译代码**:
```csharp
public extern bool IsBlocked { get; }
```

- `A339C28A` 类包含 `IsBlocked` 属性
- `D7EC65E0` 类同样包含 `IsBlocked` 属性  
- 可以阻止竞争的中文汉化插件正常运行
- 强制用户只能使用中文网生态内的产品

### 5. 注册表访问
该 DLL 读取 Windows 系统注册表，此行为从未向用户披露。

**反编译代码**:
```csharp
using RegistryKey registryKey = Registry.LocalMachine.OpenSubKey(P_0, writable: false);
if (registryKey == null)
{
    ...
}
object value = registryKey.GetValue(P_1);
```

- 访问 `Registry.LocalMachine`（本地机器注册表）
- 读取系统配置数据
- 在用户协议中完全未提及

### 6. 远程代码下载与执行
该 DLL 可以从远程服务器下载并加载代码。

- `DownloadPluginManifestAsync` — 下载插件清单文件
- `DownloadPluginAsync` — 下载插件本体
- `VerifyPluginHashAsync` — 验证文件哈希（可用于完整性校验或反篡改检测）
- `NeedsDownloadAsync` — 检查是否有新版本需要下载

### 7. 加密通信
使用混合加密方案混淆与远程服务器的通信流量。

**反编译代码**:
```csharp
// AES 解密流
CryptoStream cryptoStream = new CryptoStream(
    memoryStream, 
    rijndael.CreateDecryptor(), 
    CryptoStreamMode.Write
);

// 混合加密结果
internal class HybridEncryptedResult
{
    public string EncryptedData { get; }
    public string EncryptedKey { get; }
    public string EncryptedIV { get; }
}
```

- 使用 `Rijndael`（AES）对称加密
- `HybridEncryptedResult` 类包含加密数据、密钥和初始化向量
- 数据外泄流量经过加密，难以被防火墙检测

---

## 🔬 技术摘要

| 类别 | 关键类/方法 | 恶意行为 |
|------|------------|---------|
| 扫描 | `IGameDirectoryScanner.Scan()` | 枚举游戏目录文件 |
| 指纹 | `IDeviceIdComponent` (7种) | 采集硬件和操作系统指纹 |
| 上传 | `PostJsonForFileScanAsync` | HTTP POST 上传扫描结果 |
| 封锁 | `IsBlocked` 属性 | 禁用竞品插件 |
| 注册表 | `Registry.LocalMachine.OpenSubKey` | 读取系统注册表 |
| 下载 | `DownloadPluginManifestAsync` | 远程代码加载 |
| 加密 | `HybridEncryptedResult` + `Rijndael` | C2 通信流量混淆 |

---

## 📊 分析统计

| 项目 | 数量 |
|------|------|
| 反编译C#源文件 | 108 个 |
| 可读类定义 | 132 个 |
| 混淆类定义 | 57 个 |
| 恶意证据条目 | 38 条 |
| 设备指纹实现 | 7+ 类 |
| 扫描/上传方法 | 5+ 个 |

---

## ⚖️ 披露时间线

| 日期 | 事件 |
|------|------|
| 2026-06 | 逆向工程分析开始 |
| 2026-06-27 | 安全分析报告公开发布 |

---

## 📁 仓库内容

- `README.md` — 本报告（中文版）
- `README_EN.md` — 完整英文版报告
- `EVIDENCE.txt` — 38條分類證據清單

---

## ⚠️ 免责声明

这是为保护社区而发布的**安全研究出版物**。分析针对的是公开分发的免费模组依赖项，该依赖项：

1. **未披露**其数据收集行为
2. **未经同意**读取用户文件和注册表
3. **向远程服务器上传**用户数据
4. **封锁**竞品软件，限制用户选择

本研究的目的是告知用户其所安装软件中的隐藏行为，服务于公共利益。所有分析均基于公开可获得的分发文件。

