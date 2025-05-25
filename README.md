# 🦉 OwlUploader

一个简洁高效的 **Cloudflare R2 对象存储管理工具**，专为 macOS 平台设计。

> **English Version**: [README_EN.md](README_EN.md)

## ✨ 功能特性

### 🔗 连接管理
- 支持多账户 Cloudflare R2 配置和管理
- 安全的凭证存储（使用 macOS Keychain）
- 实时连接状态监控和错误处理

### 📦 存储桶操作
- 浏览和管理所有可访问的 R2 存储桶
- 直观的存储桶信息展示
- 快速存储桶切换

### 📁 文件管理
- **文件上传**：支持拖拽上传和文件选择器
- **文件下载**：一键下载到本地
- **文件删除**：批量删除操作
- **文件夹管理**：创建和组织文件夹结构
- **文件预览**：支持常见文件类型预览（待实现）

### 🎨 用户体验
- 原生 macOS 设计语言
- 响应式界面布局
- 智能错误提示和操作建议
- 实时操作状态反馈

## 📋 系统要求

- **操作系统**：macOS 13.0 (Ventura) 及以上版本
- **架构**：支持 Intel 和 Apple Silicon (M1/M2) 处理器
- **网络**：需要稳定的互联网连接访问 Cloudflare R2

## 🛠 技术栈

- **开发语言**：Swift 5.9+
- **UI 框架**：SwiftUI
- **网络库**：AWS SDK for Swift (用于 S3 兼容 API)
- **安全存储**：macOS Keychain Services
- **架构模式**：MVVM + ObservableObject

## 🚀 安装和使用

### 从源码构建

1. **克隆仓库**
   ```bash
   git clone https://github.com/yourusername/OwlUploader.git
   cd OwlUploader
   ```

2. **打开项目**
   ```bash
   open OwlUploader.xcodeproj
   ```

3. **构建和运行**
   - 确保 Xcode 版本 15.0 或更高
   - 选择目标设备（Mac）
   - 按 `Cmd + R` 运行项目

### 首次配置

1. 启动应用后，点击 **"账户设置"**
2. 输入您的 Cloudflare R2 凭证：
   - **账户 ID**：在 Cloudflare 控制台中找到
   - **Access Key ID** 和 **Secret Access Key**：创建 R2 API 令牌
   - **端点 URL**：格式为 `https://[账户ID].r2.cloudflarestorage.com`
3. 点击 **"保存并连接"**

## 📖 使用指南

### 连接到 R2
1. 配置账户信息后，应用将自动尝试连接
2. 连接成功后，侧边栏会显示绿色连接指示器
3. 现在可以浏览存储桶和管理文件

### 文件操作
- **上传文件**：将文件拖拽到文件列表区域，或点击上传按钮
- **下载文件**：右键点击文件选择下载，或使用下载按钮
- **创建文件夹**：点击"新建文件夹"按钮
- **删除文件**：选择文件后点击删除按钮

## 🔒 安全性

- 所有凭证信息使用 macOS Keychain 安全存储
- 支持应用沙盒（App Sandbox）模式
- 网络通信使用 HTTPS 加密
- 不会存储或传输用户数据到第三方服务器

## 🤝 贡献指南

我们欢迎社区贡献！请遵循以下步骤：

1. **Fork** 本仓库
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 **Pull Request**

### 开发规范
- 遵循 Swift 编码规范
- 添加适当的代码注释（支持中文注释）
- 确保新功能有对应的测试用例
- 保持代码简洁，单个文件不超过 500 行

## 📝 开发日志

项目的详细开发记录可在 [`docs/dev/`](docs/dev/) 目录中找到，包含：
- 功能实现记录
- 技术决策说明
- 问题解决方案

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE) 开源。

## 🙏 致谢

- [AWS SDK for Swift](https://github.com/awslabs/aws-sdk-swift) - S3 兼容 API 支持
- [Cloudflare R2](https://developers.cloudflare.com/r2/) - 强大的对象存储服务
- SwiftUI 社区 - 提供了大量的开发参考

## 📞 反馈和支持

如果您在使用过程中遇到问题或有功能建议，请：

1. 查看 [Issues](https://github.com/yourusername/OwlUploader/issues) 中是否已有相关问题
2. 创建新的 Issue 详细描述问题或建议
3. 联系开发者：[您的邮箱]

---

**享受使用 OwlUploader 管理您的 Cloudflare R2 存储！** 🦉✨ 