# macOS R2 文件上传工具 - 任务清单

## Phase 1: 基础框架与配置管理
*   **Milestone**: 用户能够输入并安全保存 R2 配置信息。

*   **Task 1.1: 项目初始化与依赖集成 (P1)**
    *   **目标**: 创建新的 macOS SwiftUI 项目，并集成 AWS SDK for Swift。
    *   **子步骤**:
        - [x] 1. 在 Xcode 中创建新的 macOS App 项目，选择 SwiftUI 作为用户界面。
        - [x] 2. 通过 Swift Package Manager (SPM) 添加 `AWSSDKSwift` (特别是 `AWSS3`) 依赖。
    *   **所需资源**: Xcode, Swift Package Manager。
    *   **输出内容**: `owl-upload.xcodeproj`, `Package.swift` (或项目配置中更新的SPM依赖)
    *   **状态**: `todo`

*   **Task 1.2: Keychain 辅助类实现 (P1)**
    *   **目标**: 创建一个通用的 Keychain 帮助类，用于安全地存储和读取敏感数据。
    *   **子步骤**:
        - [ ] 1. 设计 `KeychainHelper.swift` 文件。
        - [ ] 2. 实现 `save(key: String, data: Data)` 方法。
        - [ ] 3. 实现 `load(key: String) -> Data?` 方法。
        - [ ] 4. 实现 `delete(key: String)` 方法。
        - [ ] 5. 考虑错误处理和日志记录。
    *   **所需资源**: Keychain Services API 文档。
    *   **输出内容**: `KeychainHelper.swift`
    *   **状态**: `todo`

*   **Task 1.3: 配置视图 (SettingsView) UI 实现 (P2)**
    *   **目标**: 构建用户界面，允许用户输入所有 R2 配置项。
    *   **子步骤**:
        - [ ] 1. 创建 `SettingsView.swift`。
        - [ ] 2. 使用 SwiftUI 控件布局配置项输入区域 (R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET_NAME, R2_DOMAIN, R2_ENDPOINT, R2_PUBLIC_DOMAIN)。
        - [ ] 3. 添加"保存配置"按钮。
    *   **所需资源**: SwiftUI 文档。
    *   **输出内容**: `SettingsView.swift`
    *   **状态**: `todo`

*   **Task 1.4: 配置视图模型 (SettingsViewModel) 逻辑实现 (P1)**
    *   **目标**: 管理配置数据的状态、加载、保存和验证。
    *   **子步骤**:
        - [ ] 1. 创建 `SettingsViewModel.swift` (`ObservableObject`)。
        - [ ] 2. 定义 `@Published` 属性对应配置项。
        - [ ] 3. 实现 `saveSettings()` (使用 `UserDefaults` 和 `KeychainHelper`)。
        - [ ] 4. 实现 `loadSettings()`。
        - [ ] 5. 实现输入验证逻辑。
    *   **所需资源**: `UserDefaults` API, `KeychainHelper.swift`。
    *   **输出内容**: `SettingsViewModel.swift`
    *   **状态**: `todo`

---

## Phase 2: 文件上传核心功能
*   **Milestone**: 用户能够选择文件并将其成功上传到配置的 R2 存储桶。

*   **Task 2.1: R2 服务类 (R2Service) 框架搭建 (P1)**
    *   **目标**: 创建与 R2 (S3兼容) API 交互的服务类框架。
    *   **子步骤**:
        - [ ] 1. 创建 `R2Service.swift`。
        - [ ] 2. 设计初始化方法，接收 R2 配置。
        - [ ] 3. 引入 `AWSS3` 模块。
        - [ ] 4. 配置 `S3Client` 使用自定义端点和凭证。
    *   **所需资源**: AWS SDK for Swift (S3) 文档, `SettingsViewModel.swift`。
    *   **输出内容**: `R2Service.swift` (基本框架)
    *   **状态**: `todo`

*   **Task 2.2: 文件上传逻辑实现 (R2Service) (P1)**
    *   **目标**: 在 `R2Service` 中实现文件上传到 R2 的核心逻辑。
    *   **子步骤**:
        - [ ] 1. 添加 `uploadFile(fileURL: URL, fileName: String, progressHandler: @escaping (Double) -> Void) async throws -> String` 方法。
        - [ ] 2. 使用 `S3Client.putObject()` 上传文件，正确设置请求参数。
        - [ ] 3. 处理 AWS SDK 错误。
        - [ ] 4. 实现进度报告。
    *   **所需资源**: AWS SDK for Swift (S3 `PutObject`) 文档。
    *   **输出内容**: `R2Service.swift` (包含上传功能)
    *   **状态**: `todo`

*   **Task 2.3: 上传视图 (UploadView) UI 实现 (P2)**
    *   **目标**: 构建文件选择、触发上传和显示结果的用户界面。
    *   **子步骤**:
        - [ ] 1. 创建 `UploadView.swift`。
        - [ ] 2. 添加"选择文件"按钮、已选文件名显示、"上传文件"按钮。
        - [ ] 3. 添加 `ProgressView` 显示上传进度。
        - [ ] 4. 添加文本区域显示成功 URL 或错误信息。
        - [ ] 5. 添加"复制URL"按钮。
    *   **所需资源**: SwiftUI 文档, `.fileImporter` 文档。
    *   **输出内容**: `UploadView.swift`
    *   **状态**: `todo`

*   **Task 2.4: 上传视图模型 (UploadViewModel) 逻辑实现 (P1)**
    *   **目标**: 管理文件上传流程的状态和用户交互。
    *   **子步骤**:
        - [ ] 1. 创建 `UploadViewModel.swift` (`ObservableObject`)。
        - [ ] 2. 定义 `@Published` 属性 (selectedFileURL, isUploading, uploadProgress, uploadedFileURLString, errorMessage)。
        - [ ] 3. 实现文件选择逻辑。
        - [ ] 4. 实现 `uploadFile()` 方法 (获取配置、实例化 `R2Service`、调用上传、构建 URL, 处理错误)。
        - [ ] 5. 实现复制 URL 到剪贴板的逻辑。
    *   **所需资源**: `R2Service.swift`, `SettingsViewModel.swift`, SwiftUI `ObservableObject` 文档, `NSPasteboard`。
    *   **输出内容**: `UploadViewModel.swift`
    *   **状态**: `todo`

---

## Phase 3: 应用组装与完善
*   **Milestone**: 应用功能完整，用户体验流畅。

*   **Task 3.1: 主应用视图 (ContentView / AppMain) (P2)**
    *   **目标**: 整合配置视图和上传视图，提供应用主界面。
    *   **子步骤**:
        - [ ] 1. 修改 `AppMain.swift` (或 `ContentView.swift`)。
        - [ ] 2. 使用 `TabView` 或其他导航方式组织 `SettingsView` 和 `UploadView`。
        - [ ] 3. 确保 ViewModels 被正确初始化和注入。
    *   **所需资源**: SwiftUI 导航组件文档。
    *   **输出内容**: 更新后的 `AppMain.swift` / `ContentView.swift`。
    *   **状态**: `todo`

*   **Task 3.2: 错误处理与用户反馈增强 (P3)**
    *   **目标**: 提升应用的健壮性和用户体验。
    *   **子步骤**:
        - [ ] 1. 全面检查所有可能的错误路径。
        - [ ] 2. 在 UI 中以用户友好的方式显示错误信息 (例如，使用 `Alerts`)。
        - [ ] 3. 确保后台任务执行时，UI 状态正确更新。
    *   **所需资源**: SwiftUI `Alert` 文档。
    *   **输出内容**: 各相关 View 和 ViewModel 代码的改进。
    *   **状态**: `todo`

*   **Task 3.3: 应用图标和元数据 (P3)**
    *   **目标**: 为应用添加图标和必要的元数据。
    *   **子步骤**:
        - [ ] 1. 设计或获取一个应用图标。
        - [ ] 2. 在 Xcode 项目中配置应用图标。
        - [ ] 3. 填写应用版本号、Bundle Identifier 等信息。
    *   **所需资源**: App Icon 规范, Xcode。
    *   **输出内容**: 更新后的项目配置, `Assets.xcassets`。
    *   **状态**: `todo`

*   **Task 3.4: (可选) 初步测试与打包 (P3)**
    *   **目标**: 进行基本的功能测试，并尝试打包应用。
    *   **子步骤**:
        - [ ] 1. 手动测试所有核心功能。
        - [ ] 2. 使用 Xcode 的 Archive 功能创建一个 `.app` 包。
    *   **所需资源**: Xcode。
    *   **输出内容**: 测试报告 (非正式), `.app` 文件。
    *   **状态**: `todo` 