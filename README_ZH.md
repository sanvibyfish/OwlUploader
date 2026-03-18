<p align="center">
  <img src="OwlUploader/Assets.xcassets/AppIcon.appiconset/256.png" width="128" height="128" alt="OwlUploader Icon">
</p>

<h1 align="center">OwlUploader</h1>

<p align="center">
  macOS 原生 <strong>Cloudflare R2</strong> 对象存储管理工具。<br>
  SwiftUI 构建，面向开发者和内容创作者。
</p>

<p align="center">
  <a href="https://github.com/sanvibyfish/OwlUploader/releases/latest">
    <img src="https://img.shields.io/github/v/release/sanvibyfish/OwlUploader?style=for-the-badge&logo=github&label=下载" alt="下载最新版本" height="32">
  </a>
</p>

<p align="center">
  <a href="README.md">English</a>
</p>

---

## 功能特性

### 连接管理
- 支持多账户 Cloudflare R2 配置，快速切换
- 凭证安全存储（macOS Keychain）
- 实时连接状态监控

### 存储桶操作
- 浏览和管理所有可访问的 R2 存储桶
- 自定义公开域名配置（支持多域名）
- 通过 Cloudflare API 清除 CDN 缓存

### 文件管理
- **上传** — 拖拽上传、文件夹上传、批量上传，支持冲突检测
- **下载** — 单文件、批量、文件夹下载
- **删除** — 单文件和批量删除（优化的批量 API）
- **重命名** — 文件和文件夹重命名，实时名称验证
- **移动** — 右键菜单移动到其他目录，支持批量
- **预览** — 图片、视频、音频、PDF、文本格式
- **复制链接** — 一键复制；多域名时展开子菜单选择

### 高级功能
- Finder 风格前进/后退导航历史
- 多选操作：Cmd+Click 添加，Shift+Click 范围选择
- 搜索、类型筛选、列排序
- 上传/下载/移动队列，支持取消和重试
- 自动任务去重
- 上传冲突解决（替换 / 保留两者 / 跳过）
- 覆盖上传后自动清除 CDN 缓存

### 用户体验
- 原生 macOS 设计（SwiftUI）
- Finder 风格表格视图和图标视图
- 面包屑导航
- 深色模式适配
- 中英文本地化支持

## 系统要求

| 要求 | 最低版本 |
|------|---------|
| macOS | 15.4+ |
| 架构 | Intel 和 Apple Silicon |
| 网络 | 稳定的互联网连接 |

## 技术栈

- **开发语言**: Swift 5.9+
- **UI 框架**: SwiftUI
- **网络库**: AWS SDK for Swift（S3 兼容 API）
- **安全存储**: macOS Keychain Services
- **架构模式**: MVVM + ObservableObject

## 从源码构建

```bash
git clone https://github.com/sanvibyfish/OwlUploader.git
cd OwlUploader
open OwlUploader.xcodeproj
```

- 需要 Xcode 16.0+
- 选择 Mac 目标，按 `Cmd + R` 运行

## 快速开始

1. 启动 OwlUploader，打开**账户设置**
2. 输入 Cloudflare R2 凭证：
   - **账户 ID**（在 Cloudflare 控制台中找到）
   - **Access Key ID** 和 **Secret Access Key**（R2 API 令牌）
   - **端点 URL**: `https://[账户ID].r2.cloudflarestorage.com`
3. 点击**保存并连接**
4. 可选：添加公共域名用于链接生成

## 安全性

- 凭证使用 macOS Keychain 安全存储（非明文）
- 已启用应用沙盒
- 所有网络通信使用 HTTPS
- 不会向第三方服务器发送数据

## 贡献

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改
4. 推送并创建 Pull Request

**规范**：遵循 Swift 编码规范，单文件不超过 500 行，新功能需有对应测试。

## 许可证

[GNU GPL v3](LICENSE)

## 致谢

- [AWS SDK for Swift](https://github.com/awslabs/aws-sdk-swift) — S3 兼容 API
- [Cloudflare R2](https://developers.cloudflare.com/r2/) — 对象存储服务

## 反馈

- [GitHub Issues](https://github.com/sanvibyfish/OwlUploader/issues)
- 邮箱: sanvibyfish@gmail.com
