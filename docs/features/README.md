# OwlUploader 功能文档

> 本目录包含 OwlUploader macOS 应用的所有功能模块文档。

---

## 📖 项目概述

### 简介

OwlUploader 是一款专为 macOS 平台设计的 **Cloudflare R2 对象存储管理工具**。它提供了简洁直观的图形界面，让用户能够轻松管理 R2 存储桶中的文件，支持上传、下载、删除、文件夹管理等核心功能。

### 核心价值

- **原生体验**: 采用 SwiftUI 构建，完美融入 macOS 生态系统
- **安全可靠**: 使用 macOS Keychain 安全存储敏感凭证
- **高效便捷**: 支持拖拽上传、批量操作、队列管理等高级功能
- **开发者友好**: 清晰的架构设计，易于扩展和维护

### 目标用户

- 使用 Cloudflare R2 存储的开发者
- 需要频繁管理云存储文件的内容创作者
- 希望拥有原生 macOS 体验的 R2 用户

---

## 🏛️ 架构设计

### 整体架构

应用采用 **MVVM (Model-View-ViewModel)** 架构模式，结合 SwiftUI 的 `ObservableObject` 实现响应式数据绑定。

```
┌─────────────────────────────────────────────────────────────────┐
│                         Presentation Layer                       │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌────────────┐ │
│  │ ContentView │ │ FileListView│ │ BucketList  │ │ Settings   │ │
│  │ (主视图)    │ │ (文件管理)  │ │ (存储桶)    │ │ (TabView)  │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └────────────┘ │
│  ┌─────────────┐                                                │
│  │ WelcomeView │ ← 欢迎页面（品牌展示 + 状态引导）               │
│  └─────────────┘                                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Business Layer                           │
│  ┌─────────────────────┐  ┌─────────────────────┐               │
│  │     R2Service       │  │  R2AccountManager   │               │
│  │  (核心业务逻辑)      │  │  (账户状态管理)      │               │
│  │  - 文件上传/下载     │  │  - 账户配置         │               │
│  │  - 存储桶操作       │  │  - 连接状态         │               │
│  │  - 文件夹管理       │  │  - 凭证验证         │               │
│  └─────────────────────┘  └─────────────────────┘               │
│  ┌─────────────────────┐  ┌─────────────────────┐               │
│  │ UploadQueueManager  │  │  MoveQueueManager   │               │
│  │   (上传队列管理)     │  │   (移动队列管理)     │               │
│  └─────────────────────┘  └─────────────────────┘               │
│  ┌─────────────────────┐                                        │
│  │   MessageManager    │                                        │
│  │   (消息通知管理)     │                                        │
│  └─────────────────────┘                                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Data Layer                               │
│  ┌─────────────────────┐  ┌─────────────────────┐               │
│  │   KeychainService   │  │   AWS SDK (S3)      │               │
│  │   (安全凭证存储)     │  │   (网络通信)         │               │
│  └─────────────────────┘  └─────────────────────┘               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Models                                   │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                 │
│  │ R2Account  │  │ BucketItem │  │ FileObject │                 │
│  │ (账户模型) │  │ (存储桶)   │  │ (文件对象) │                 │
│  └────────────┘  └────────────┘  └────────────┘                 │
└─────────────────────────────────────────────────────────────────┘
```

### 核心组件职责

| 组件 | 职责 | 关键特性 |
|------|------|----------|
| **R2Service** | 核心业务逻辑层 | S3 API 封装、错误处理、重试机制 |
| **R2AccountManager** | 账户状态管理 | 多账户支持、连接状态监控 |
| **KeychainService** | 安全凭证存储 | macOS Keychain 集成 |
| **UploadQueueManager** | 上传队列管理 | 并发控制、进度追踪、断点续传 |
| **MoveQueueManager** | 移动队列管理 | 拖拽移动、冲突处理、批量移动 |
| **MessageManager** | 消息通知系统 | Toast 提示、错误反馈 |

### 数据流向

```
用户操作 → View → ViewModel (ObservableObject) → Service → API/Storage
                        ↓
              @Published 状态更新
                        ↓
                   View 刷新
```

---

## 📁 目录结构

```
OwlUploader/
├── OwlUploaderApp.swift          # 应用入口与生命周期管理
├── ContentView.swift             # 主视图容器（侧边栏 + 内容区）
├── AppCommands.swift             # 应用菜单命令与快捷键
│
├── Views/
│   ├── SidebarView.swift         # 侧边栏导航组件
│   ├── AccountSettingsView.swift # 账户配置界面
│   ├── BucketListView.swift      # 存储桶选择界面
│   ├── FileListView.swift        # 文件列表界面
│   ├── FileDropView.swift        # 拖拽上传组件
│   ├── FilePreviewView.swift     # 文件预览组件
│   ├── CreateFolderSheet.swift   # 创建文件夹弹窗
│   ├── BreadcrumbView.swift      # 面包屑导航组件
│   ├── DiagnosticsView.swift     # 系统诊断界面
│   ├── SearchFilterBar.swift     # 搜索过滤栏组件
│   ├── FinderToolbar.swift       # Finder风格工具栏
│   ├── PathBar.swift             # 路径导航栏
│   ├── FileGridView.swift        # 图标网格视图
│   ├── FileGridItemView.swift    # 网格项组件（缩略图）
│   └── FileTableView.swift       # 表格视图（列头+排序）
│
├── Queue/
│   ├── CombinedQueueView.swift   # 合并队列视图（上传+移动）
│   ├── MoveQueueManager.swift    # 移动队列管理器
│   ├── QueueTask.swift           # 队列任务协议
│   └── UploadQueueManager.swift  # 上传队列管理器
│
├── DesignSystem/
│   ├── ViewModeManager.swift     # 视图模式管理器
│   ├── SelectionManager.swift    # 选择状态管理器
│   ├── NavigationHistoryManager.swift # 导航历史管理器
│   ├── AnimationConstants.swift  # 动画与过渡常量
│   ├── ThumbnailCache.swift      # 缩略图缓存管理
│   ├── AppColors.swift           # 语义颜色定义
│   ├── AppTypography.swift       # 字体规范
│   ├── AppSpacing.swift          # 间距规范
│   └── Components/
│       ├── StatusBadge.swift     # 状态徽章
│       ├── EmptyStateView.swift  # 空状态视图
│       ├── AppButtonStyles.swift # 按钮样式
│       └── ActionHintCard.swift  # 操作提示卡片
│
├── Localization/
│   ├── LanguageManager.swift     # 语言管理器
│   ├── AppStrings.swift          # 类型安全字符串命名空间
│   └── Localizable.xcstrings     # 本地化字符串资源
│
├── Services/
│   ├── R2Service.swift           # R2 服务核心（S3 API 封装）
│   ├── R2AccountManager.swift    # 账户管理器
│   └── KeychainService.swift     # Keychain 安全存储服务
│
├── Models/
│   ├── R2Account.swift           # 账户数据模型
│   ├── BucketItem.swift          # 存储桶数据模型
│   └── FileObject.swift          # 文件对象数据模型
│
├── Components/
│   └── MessageBanner.swift       # 消息通知横幅组件
│
└── Assets.xcassets/              # 资源文件（图标、颜色等）
```

---

## 🔧 核心技术栈

| 技术 | 版本 | 用途 |
|------|------|------|
| **Swift** | 5.9+ | 开发语言 |
| **SwiftUI** | - | UI 框架 |
| **AWS SDK for Swift** | - | S3 兼容 API 通信 |
| **macOS Keychain Services** | - | 安全凭证存储 |
| **Combine** | - | 响应式编程 |

### 架构模式

- **MVVM**: Model-View-ViewModel 分层架构
- **ObservableObject**: SwiftUI 状态管理
- **Dependency Injection**: 服务层依赖注入
- **Singleton**: 核心服务单例模式 (R2Service.shared)

---

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
| 09 | **Finder UI 设计规范** | [09-finder-ui-design.md](./09-finder-ui-design.md) | UI 组件、交互模式、视觉规范 |
| 10 | **文件重命名** | [10-file-rename.md](./10-file-rename.md) | 文件与文件夹重命名功能 |

---

## 📋 系统要求

| 要求 | 最低版本 | 推荐版本 |
|------|----------|----------|
| **操作系统** | macOS 13.0 (Ventura) | macOS 14.0 (Sonoma) |
| **处理器** | Intel / Apple Silicon | Apple Silicon (M1+) |
| **内存** | 4GB | 8GB+ |
| **网络** | 稳定的互联网连接 | - |
| **Xcode** (开发) | 15.0 | 15.0+ |

---

## 🔐 安全设计

### 凭证安全

- **Keychain 存储**: Secret Access Key 等敏感信息使用 macOS Keychain 加密存储
- **内存安全**: 敏感数据在使用后及时清除
- **App Sandbox**: 应用运行在沙盒环境中，限制文件系统访问

### 网络安全

- **HTTPS**: 所有网络通信使用 TLS 加密
- **凭证传输**: 使用 AWS Signature V4 签名，凭证不明文传输

### 权限控制

- 仅请求必要的系统权限（网络访问、文件读取）
- 支持用户选择文件的安全访问模式

---

## 🚀 快速开始

### 1. 获取 R2 凭证

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 进入 R2 对象存储页面
3. 创建 API 令牌，获取 Access Key ID 和 Secret Access Key
4. 记录账户 ID

### 2. 配置应用

1. 启动 OwlUploader
2. 点击侧边栏「账户设置」
3. 填写凭证信息并保存

### 3. 开始使用

- 选择存储桶 → 浏览文件 → 上传/下载/管理

---

## 🔄 错误处理机制

应用实现了完善的错误处理体系：

| 错误类型 | 处理策略 | 用户反馈 |
|----------|----------|----------|
| 网络错误 | 自动重试（3次） | Toast 提示 + 重试按钮 |
| 认证错误 | 引导重新配置 | 跳转账户设置页面 |
| 权限错误 | 显示详细原因 | 操作建议提示 |
| 文件错误 | 跳过/重试选项 | 错误列表展示 |

---

## 📈 未来规划

### 已完成
- [x] 多账户快速切换
- [x] 文件搜索与过滤
- [x] 深色模式适配
- [x] Finder 风格 UI（视图模式、工具栏、路径导航）
- [x] 图片缩略图预览
- [x] 文件预览功能（图片、视频、音频、PDF、文本）
- [x] 文件下载功能
- [x] 批量操作（多选删除、下载）
- [x] 文件移动功能（右键菜单移动到其他目录）
- [x] 文件重命名功能（智能验证、实时反馈）
- [x] 本地化支持（中文/英文）
- [x] 导航历史（前进/后退）
- [x] 合并队列视图（上传+移动）

### 规划中
- [ ] 文件夹上传（保持目录结构）
- [ ] 上传/下载历史记录
- [ ] 文件共享链接生成（过期设置）
- [ ] 批量重命名（模式替换）

---

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/xxx`)
3. 提交更改 (`git commit -m 'feat: xxx'`)
4. 推送分支 (`git push origin feature/xxx`)
5. 创建 Pull Request

### 代码规范

- 遵循 Swift 官方编码规范
- 添加必要的代码注释
- 保持单个文件不超过 500 行
- 新功能需要有对应的测试用例

---

**文档版本**: 2.0  
**最后更新**: 2026-01-01  
**维护者**: OwlUploader Team
