# 07. 安全存储 (Security & Keychain)

## 功能概述

安全存储模块使用 macOS Keychain Services 安全存储敏感凭证信息（如 Secret Access Key），确保用户数据的安全性。

## 核心组件

| 文件 | 职责 |
|------|-----|
| `KeychainService.swift` | Keychain 操作封装 |
| `R2AccountManager.swift` | 账户凭证管理 |
| `R2Account.swift` | 账户标识符生成 |

## 安全机制

### 🔒 Keychain 存储

- **加密存储**: macOS 系统级加密保护
- **应用隔离**: 只有 OwlUploader 可访问
- **用户认证**: 可选要求用户密码/Touch ID
- **云同步**: 不同步到 iCloud Keychain

### 📦 存储分离

| 数据类型 | 存储位置 | 安全级别 |
|---------|---------|---------|
| Account ID | UserDefaults | 普通 |
| Access Key ID | UserDefaults | 普通 |
| Endpoint URL | UserDefaults | 普通 |
| **Secret Access Key** | **Keychain** | **高** |

## API 接口

### KeychainService 类

```swift
class KeychainService {
    static let shared = KeychainService()
    
    // 存储字符串
    func store(_ value: String, service: String, account: String) throws
    
    // 读取字符串
    func retrieve(service: String, account: String) throws -> String
    
    // 更新字符串
    func update(_ value: String, service: String, account: String) throws
    
    // 删除项目
    func delete(service: String, account: String) throws
    
    // 检查是否存在
    func exists(service: String, account: String) -> Bool
}
```

### R2Account 扩展

```swift
extension KeychainService {
    func storeSecretAccessKey(_ key: String, for account: R2Account) throws
    func retrieveSecretAccessKey(for account: R2Account) throws -> String
    func updateSecretAccessKey(_ key: String, for account: R2Account) throws
    func deleteSecretAccessKey(for account: R2Account) throws
    func hasSecretAccessKey(for account: R2Account) -> Bool
}
```

## 错误处理

### KeychainError 枚举

```swift
enum KeychainError: Error {
    case invalidData          // 数据格式无效
    case itemNotFound         // 项目不存在
    case duplicateItem        // 项目已存在
    case unexpectedError(status: OSStatus)  // 系统错误
}
```

### 错误码说明

| OSStatus | 含义 |
|----------|-----|
| errSecSuccess (0) | 操作成功 |
| errSecItemNotFound (-25300) | 未找到项目 |
| errSecDuplicateItem (-25299) | 项目已存在 |
| errSecAuthFailed (-25293) | 认证失败 |

## 实现细节

### 存储 Query 构建

```swift
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: account,
    kSecValueData as String: data
]
```

### 读取 Query 构建

```swift
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: account,
    kSecReturnData as String: true,
    kSecMatchLimit as String: kSecMatchLimitOne
]
```

## 安全最佳实践

1. **不日志敏感信息**: 代码中不打印 Secret Access Key
2. **及时清理**: 删除账户时同步删除 Keychain 项目
3. **错误处理**: 优雅处理 Keychain 访问失败
4. **唯一标识**: 使用账户 ID 生成唯一 Keychain key

## 网络安全

- **HTTPS 通信**: 所有 R2 API 请求使用 HTTPS
- **App Sandbox**: 应用运行在沙箱环境中
- **网络权限**: 只请求必要的网络权限

## 相关链接

- [账户配置](./01-account-configuration.md)
- [系统诊断](./08-diagnostics.md)
