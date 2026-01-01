# OwlUploader 功能文档

> 本目录包含 OwlUploader macOS 应用的所有功能模块文档。

## 📚 文档索引

| 编号 | 功能模块 | 文档链接 | 描述 |
|:----:|---------|----------|------|
| 01 | 账户配置 | [01-account-configuration.md](./01-account-configuration.md) | R2 账户凭证配置与管理 |
| 02 | 存储桶操作 | [02-bucket-operations.md](./02-bucket-operations.md) | 存储桶选择与连接 |
| 03 | 文件导航 | [03-file-navigation.md](./03-file-navigation.md) | 文件列表浏览与路径导航 |
| 04 | 文件上传 | [04-file-upload.md](./04-file-upload.md) | 文件选择器与拖拽上传 |
| 05 | 文件下载与删除 | [05-file-download-delete.md](./05-file-download-delete.md) | 文件下载与删除操作 |
| 06 | 文件夹管理 | [06-folder-management.md](./06-folder-management.md) | 文件夹创建与组织 |
| 07 | 安全存储 | [07-security-keychain.md](./07-security-keychain.md) | Keychain 凭证安全存储 |
| 08 | 系统诊断 | [08-diagnostics.md](./08-diagnostics.md) | 连接诊断与故障排除 |

---

## 🏗️ 技术架构

```
OwlUploader/
├── OwlUploaderApp.swift          # 应用入口
├── ContentView.swift             # 主视图（侧边栏 + 内容区）
├── R2Service.swift              # R2 服务核心（S3 API）
├── R2AccountManager.swift       # 账户管理器
├── AccountSettingsView.swift    # 账户配置界面
├── BucketListView.swift         # 存储桶选择界面
├── FileListView.swift           # 文件列表界面
├── FileListItemView.swift       # 文件列表项组件
├── FileDropView.swift           # 拖拽上传组件
├── CreateFolderSheet.swift      # 创建文件夹弹窗
├── BreadcrumbView.swift         # 面包屑导航组件
├── DiagnosticsView.swift        # 系统诊断界面
├── KeychainService.swift        # Keychain 服务
├── MessageBanner.swift          # 消息通知组件
└── Models/
    ├── R2Account.swift          # 账户模型
    ├── BucketItem.swift         # 存储桶模型
    └── FileObject.swift         # 文件对象模型
```

## 🔧 核心技术栈

- **语言**: Swift 5.9+
- **UI 框架**: SwiftUI
- **网络库**: AWS SDK for Swift (S3 兼容 API)
- **安全存储**: macOS Keychain Services
- **架构模式**: MVVM + ObservableObject

## 📋 系统要求

- macOS 13.0 (Ventura) 及以上版本
- 支持 Intel 和 Apple Silicon 处理器
- 稳定的网络连接

---

**文档版本**: 1.0  
**最后更新**: 2025-01-01
