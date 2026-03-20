# CLAUDE.md

## Project Overview

OwlUploader — macOS 原生多云对象存储管理工具。支持 Cloudflare R2 和阿里云 OSS（S3 兼容 API 统一抽象）。SwiftUI 构建，面向开发者和内容创作者。当前已发布 v1.0.1。

## Tech Stack

- Language: Swift 5.9+
- Framework: SwiftUI + Combine
- Build: Xcode 15.0+
- Dependencies: AWS SDK for Swift (S3 兼容 API)
- Platform: macOS 13.0+ (Ventura)
- Localization: en + zh-Hans（`Localizable.xcstrings` + `AppStrings.swift` alias `L`）

## Architecture

- MVVM + ObservableObject
- `R2Service` 是 `@MainActor`，纯工具方法用 `nonisolated static`
- Queue managers (`UploadQueueManager`, `DownloadQueueManager`) 都是 `@MainActor`
- `ThumbnailCache` 用 `NSCache` + private `actor LoadingTaskManager`
- `CloudProvider` 枚举抽象多云供应商（`.r2` / `.oss`），`R2Account` 含 `provider` 字段
- Keychain 存 `SecretAccessKey` + `CloudflareAPIToken`（R2 only），账户删除时按 provider 清理
- CDN purge 通过 Cloudflare API（仅 R2），单次最多 30 URLs

## Development Rules

1. 任何代码改动如果与 `docs/` 下的文档不一致，必须同步更新对应文档
2. 产品决策变更（功能取舍、交互调整、设计修改）必须写入对应文档，不能只存在于对话中
3. 不确定的产品问题先问我，不要自行决定
4. 单个文件不超过 500 行
5. 遵循 Swift 官方编码规范

## Common Commands

```bash
# Build (command line)
xcodebuild -project OwlUploader.xcodeproj -scheme OwlUploader -configuration Debug build

# Test
xcodebuild -project OwlUploader.xcodeproj -scheme OwlUploader -configuration Debug test

# Clean
xcodebuild -project OwlUploader.xcodeproj -scheme OwlUploader clean
```

> 日常开发建议直接用 Xcode GUI（Cmd+B 构建，Cmd+U 测试）

## Documentation

- 功能文档 → docs/features/（含 README.md 索引）
- 需求文档 → docs/requirements/（`XXX-短名称.md`，三位数字编号，格式规范见 ~/.claude/CLAUDE.md）
- 开发进度 → docs/progress.md
- 工作日志 → docs/dev/
- 复盘记录 → docs/postmortem/
- 版本记录 → docs/releases/
- 支持文档 → docs/support.md

## Key Files

- `OwlUploader/CloudProvider.swift` — 多云供应商枚举和 OSS Region 定义
- `OwlUploader/R2Service.swift` — 核心业务逻辑（S3 兼容多云）
- `OwlUploader/R2AccountManager.swift` — 账户状态管理
- `OwlUploader/KeychainService.swift` — 安全凭证存储
- `OwlUploader/UploadQueueManager.swift` — 上传队列
- `OwlUploader/Localization/AppStrings.swift` — 本地化字符串（alias `L`）
- `OwlUploader/ContentView.swift` — 主视图容器
