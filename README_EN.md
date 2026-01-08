# 🦉 OwlUploader

A clean and efficient **Cloudflare R2 Object Storage Management Tool** designed specifically for macOS.

> **中文版本**: [README.md](README.md)

## ✨ Features

### 🔗 Connection Management
- Support for multiple Cloudflare R2 account configuration and management
- Secure credential storage (using macOS Keychain)
- Real-time connection status monitoring and error handling
- Quick account switching

### 📦 Bucket Operations
- Browse and manage all accessible R2 buckets
- Intuitive bucket information display
- Quick bucket switching
- Custom public domain configuration

### 📁 File Management
- **File Upload**: Drag-and-drop upload, folder upload, batch upload
- **File Download**: Single file download, batch download
- **File Deletion**: Single file deletion, batch deletion (optimized batch API)
- **File Rename**: Support file and folder renaming with real-time name validation
- **File Move**: Right-click menu to move to other directories, batch move support
- **Folder Management**: Create, delete, rename folders
- **File Preview**: Support image, video, audio, PDF, text format preview
- **Copy Link**: One-click copy file public access link

### 🎯 Advanced Features
- **Navigation History**: Forward/backward navigation, similar to Finder
- **Multi-selection**: Cmd+Click to add selection, Shift+Click for range selection
- **Search & Filter**: File name search, type filtering, sorting
- **Queue Management**: Upload/download/move queues with cancel and retry support
- **Task Deduplication**: Automatically skip duplicate tasks

### 🎨 User Experience
- Native macOS design language (SwiftUI)
- Finder-style interface (Table View / Icon View)
- Breadcrumb navigation and path bar
- Perfect dark mode support
- Simplified Chinese and English localization
- Intelligent error prompts and operation suggestions
- Real-time operation status feedback

## 📋 System Requirements

- **Operating System**: macOS 15.4 and later
- **Architecture**: Support for Intel and Apple Silicon processors
- **Network**: Stable internet connection required to access Cloudflare R2

## 🛠 Tech Stack

- **Development Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Network Library**: AWS SDK for Swift (for S3-compatible API)
- **Secure Storage**: macOS Keychain Services
- **Architecture Pattern**: MVVM + ObservableObject

## 🚀 Installation and Usage

### 📥 Download

👉 [Download OwlUploader on App Store](https://apps.apple.com/cn/app/owluploader/id6746383161?l=en-GB&mt=12)

- **Latest Version**: v1.1.0
- **File Size**: 18.3 MB
- **System Requirements**: macOS 15.4 and later

### Build from Source

1. **Clone Repository**
   ```bash
   git clone https://github.com/yourusername/OwlUploader.git
   cd OwlUploader
   ```

2. **Open Project**
   ```bash
   open OwlUploader.xcodeproj
   ```

3. **Build and Run**
   - Ensure Xcode version 16.0 or higher
   - Select target device (Mac)
   - Press `Cmd + R` to run the project

### Initial Configuration

1. After launching the app, click **"Account Settings"**
2. Enter your Cloudflare R2 credentials:
   - **Account ID**: Found in Cloudflare dashboard
   - **Access Key ID** and **Secret Access Key**: Create R2 API token
   - **Endpoint URL**: Format as `https://[AccountID].r2.cloudflarestorage.com`
3. Click **"Save and Connect"**

## 📖 Usage Guide

### Connecting to R2
1. After configuring account information, the app will automatically attempt to connect
2. Once connected successfully, the sidebar will show a green connection indicator
3. You can now browse buckets and manage files

### File Operations
- **Upload Files**: Drag files to the file list area, or click the upload button
- **Download Files**: Right-click on files to select download, or use the download button
- **Create Folders**: Click the "New Folder" button
- **Delete Files**: Select files and click the delete button

## 🔒 Security

- All credential information is securely stored using macOS Keychain
- Supports App Sandbox mode
- Network communications use HTTPS encryption
- Does not store or transmit user data to third-party servers

## 🤝 Contributing

We welcome community contributions! Please follow these steps:

1. **Fork** this repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a **Pull Request**

### Development Guidelines
- Follow Swift coding conventions
- Add appropriate code comments (Chinese comments supported)
- Ensure new features have corresponding test cases
- Keep code clean, single files under 500 lines

## 📝 Development Log

Detailed development records can be found in the [`docs/dev/`](docs/dev/) directory, including:
- Feature implementation records
- Technical decision explanations
- Problem solutions

## 📄 License

This project is open sourced under the [GNU GPL v3](LICENSE).

## 🙏 Acknowledgments

- [AWS SDK for Swift](https://github.com/awslabs/aws-sdk-swift) - S3-compatible API support
- [Cloudflare R2](https://developers.cloudflare.com/r2/) - Powerful object storage service
- SwiftUI Community - Provided extensive development references

## 📞 Feedback and Support

If you encounter issues or have feature suggestions during use, please:

1. Check [Issues](https://github.com/yourusername/OwlUploader/issues) for existing related problems
2. Create a new Issue with detailed description of the problem or suggestion
3. Contact developer: sanvibyfish@gmail.com

---

**Enjoy using OwlUploader to manage your Cloudflare R2 storage!** 🦉✨ 