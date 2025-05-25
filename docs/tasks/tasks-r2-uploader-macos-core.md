# 任务清单 - macOS R2 Uploader (核心功能)

**最后更新**: 2025-05-26

## 阶段一：基础框架与配置管理 (Milestone: 应用可以连接到用户R2账户并展示存储桶)

### Task 1.1: 项目初始化与依赖集成 (P1)
- **目标**: 创建新的 macOS SwiftUI 项目，并集成必要的 AWS SDK for Swift。
- **子步骤**:
    - [x] 创建名为 `OwlUploader` 的 Xcode 项目 (macOS, SwiftUI App)。 (已在 DEV-2025-05-25 完成)
    - [x] 通过 Swift Package Manager 添加 `AWS SDK for Swift` 依赖，确保包含 `AWSS3` 和 `AWSClientRuntime`。 (已在 DEV-2025-05-25 指导用户完成)
    - [x] 验证 SDK 是否能成功编译到项目中。
- **所需资源**: Xcode, Swift Package Manager, AWS SDK for Swift (AWSS3).
- **输出内容**: 可编译的 Xcode 项目骨架，集成了 AWS SDK。

### Task 1.2: R2 账户配置模型与 Keychain 存储 (P1) ✅
- **目标**: 定义 R2 账户的数据模型，并实现使用 Keychain 安全存储和读取账户凭证的功能。
- **子步骤**:
    - [x] 定义 `R2Account` 结构体/类，包含 `accountID`, `accessKeyID`, `secretAccessKey`, `endpointURL`。
    - [x] 实现一个 `KeychainService`，封装 Keychain 的增、删、改、查操作，用于存储 `secretAccessKey`。
    - [x] `R2Account` 中的其他非敏感信息 (如 `accountID`, `accessKeyID`, `endpointURL`) 可以考虑使用 `UserDefaults` 存储，或与 `secretAccessKey` 一并序列化后存入 Keychain（取决于具体设计）。
    - [x] 提供加载现有账户配置的逻辑。
- **所需资源**: Swift, Keychain Services API.
- **输出内容**: `R2Account.swift`, `KeychainService.swift`, `R2AccountManager.swift`。

### Task 1.3: 账户配置 UI (P1)
- **目标**: 创建用户界面，允许用户输入和保存 R2 账户信息。
- **子步骤**:
    - [x] 设计一个简单的 SwiftUI 视图 (`AccountSettingsView.swift`)，包含输入 Account ID, Access Key ID, Secret Access Key, Endpoint URL 的文本框。
    - [x] 实现"保存"按钮逻辑，调用 `KeychainService` 和 `UserDefaults` (如果使用) 存储配置。
    - [x] 实现加载配置到 UI 的逻辑，用户再次打开配置界面时能看到已存信息（除了 Secret Key，一般不回显）。
    - [x] 提供一个默认的 Cloudflare R2 Endpoint URL 建议值或占位符。
    - [x] 基本的输入验证 (例如，确保关键字段不为空)。
- **所需资源**: SwiftUI.
- **输出内容**: `AccountSettingsView.swift`。

### Task 1.4: R2/S3 服务层基础与存储桶列表获取 (P2) ✅
- **目标**: 初始化 S3 客户端，并实现列出用户账户下所有存储桶的功能。
- **子步骤**:
    - [x] 创建 `R2Service.swift` 或类似的服务类，用于封装所有与 R2 的交互。
    - [x] 在 `R2Service` 中实现一个方法，使用已配置的账户凭证初始化 `S3Client`。
    - [x] 实现 `listBuckets()` 方法，调用 S3 客户端的 `ListBuckets` API。
    - [x] 定义 `BucketItem` 数据模型 (`BucketItem.swift`)。
    - [x] 处理 API 调用可能出现的错误 (网络、认证等)。
- **所需资源**: AWS SDK for Swift (AWSS3), `R2Account`.
- **输出内容**: `R2Service.swift` (部分), `BucketItem.swift`。

### Task 1.5: 存储桶选择 UI (P2) ✅
- **目标**: 在主界面上展示存储桶列表，并允许用户选择一个。
- **子步骤**:
    - [x] 在主 SwiftUI 视图 (`ContentView.swift` 或新建的 `BucketListView.swift`) 中，调用 `R2Service.listBuckets()` 获取数据。
    - [x] 使用 `List` 将存储桶名称展示给用户。
    - [x] 实现用户选择存储桶的交互，并将选中的存储桶信息保存在应用状态中，供后续操作使用。
    - [x] 处理列表加载中、加载失败、列表为空等状态的 UI 显示。
- **所需资源**: SwiftUI, `R2Service`, `BucketItem`.
- **输出内容**: 更新后的主 UI，能展示并选择存储桶。

## 阶段二：文件列表核心功能 (Milestone: 应用能展示文件列表，支持文件夹导航、创建文件夹、上传文件)

### Task 2.1: 文件/文件夹对象模型 (P1) ✅
- **目标**: 定义表示 R2 中文件和文件夹的数据模型。
- **子步骤**:
    - [x] 定义 `FileObject.swift` 结构体/类，包含 `name`, `key` (完整路径), `size`, `lastModifiedDate`, `isDirectory` (布尔值), `eTag` 等属性。
    - [x] 确保模型能够区分文件和文件夹。
- **所需资源**: Swift.
- **输出内容**: `FileObject.swift`。

### Task 2.2: 列出文件与文件夹功能 (P1)
- **目标**: 在 `R2Service` 中实现列出指定存储桶和路径下文件及文件夹的功能。
- **子步骤**:
    - [x] 在 `R2Service` 中实现 `listObjects(bucket: String, prefix: String?)` 方法。
    - [x] 使用 S3 客户端的 `ListObjectsV2` API，注意处理 `prefix` (用于表示当前文件夹路径) 和 `delimiter` (通常设为 `/` 以区分文件夹和文件)。
    - [x] 将 API 返回结果转换为 `FileObject` 数组。
    - [x] 处理 S3 API 返回的 `CommonPrefixes` (表示文件夹) 和 `Contents` (表示文件)。
    - [x] 支持分页加载（如果对象数量多，初期可简化为加载前N个）。
- **所需资源**: AWS SDK for Swift (AWSS3), `FileObject`.
- **输出内容**: `R2Service.swift` (更新)。

### Task 2.3: 文件列表 UI 展示 (P1) ✅
- **目标**: 创建 SwiftUI 视图以列表形式展示文件和文件夹。
- **子步骤**:
    - [x] 创建 `FileListView.swift`。
    - [x] 调用 `R2Service.listObjects()` 获取数据。
    - [x] 使用 `List` 和自定义行视图 (`FileListItemView.swift`) 展示每个 `FileObject`。
    - [x] 行视图应显示图标（区分文件/文件夹）、名称、大小（文件）、最后修改日期。
    - [x] 处理列表加载中、加载失败、当前文件夹为空等状态。
- **所需资源**: SwiftUI, `R2Service`, `FileObject`.
- **输出内容**: `FileListView.swift`, `FileListItemView.swift`。

### Task 2.4: 文件夹导航功能 (P2) ✅
- **目标**: 实现双击文件夹进入，以及返回上一级或路径导航。
- **子步骤**:
    - [x] 在 `FileListView` 中，为文件夹类型的行添加双击手势或按钮。
    - [x] 点击后，更新当前路径状态，并重新调用 `listObjects()` 加载新路径内容。
    - [x] 实现返回上一级文件夹的按钮和逻辑。
    - [x] （可选）实现面包屑导航栏 (`BreadcrumbView.swift`)，显示当前路径并允许点击跳转。
- **所需资源**: SwiftUI, 应用状态管理。
- **输出内容**: 更新后的 `FileListView.swift`, （可选）`BreadcrumbView.swift`。

### Task 2.5: 创建文件夹功能 (P2) ✅
- **目标**: 实现创建新文件夹的功能。
- **子步骤**:
    - [x] 在 `R2Service` 中实现 `createFolder(bucket: String, folderPath: String)` 方法。该方法将调用 `PutObject` API 创建一个以 `/` 结尾的空对象。
    - [x] 在 `FileListView` 中添加"创建文件夹"按钮。
    - [x] 点击按钮后，弹出一个 Alert 或 Sheet，让用户输入文件夹名称。
    - [x] 获取用户输入的名称，拼接成完整的文件夹路径，调用 `R2Service.createFolder()`。
    - [x] 成功后刷新文件列表。
    - [x] 处理命名冲突或无效名称的错误。
- **所需资源**: SwiftUI, `R2Service`.
- **输出内容**: `R2Service.swift` (更新), `FileListView.swift` (更新)。

### Task 2.6: 文件上传功能 (P1) ✅
- **目标**: 实现选择本地文件并上传到当前 R2 路径的功能。
- **子步骤**:
    - [x] 在 `R2Service` 中实现 `uploadFile(bucket: String, key: String, localFilePath: URL)` 方法，使用 `PutObject` API 上传文件内容。
    - [x] 在 `FileListView` 中添加"上传文件"按钮。
    - [x] 点击按钮后，使用 `NSOpenPanel` (通过 `.fileImporter` SwiftUI 修饰符) 允许用户选择本地文件。
    - [x] 获取选择的文件路径，构造目标 R2 key (基于当前路径和文件名)，调用 `R2Service.uploadFile()`。
    - [x] 提供基本的上传状态指示 (如，一个简单的文本提示或行内菊花图)。
    - [x] 上传成功或失败后刷新文件列表或给出提示。
    - [x] （可选）考虑大文件上传时 `S3Client` 的 `uploadFile` 帮助方法的流式上传能力，或者分块上传逻辑 (初期可简化)。
- **所需资源**: SwiftUI, AppKit (`NSOpenPanel`), `R2Service`.
- **输出内容**: `R2Service.swift` (更新), `FileListView.swift` (更新)。

## 阶段三：应用组装与完善 (Milestone: 核心功能稳定可用，有基本错误处理和用户反馈)

### Task 3.1: 主应用视图组装 (P2) ✅
- **目标**: 将账户配置、存储桶选择、文件列表等视图整合到主应用流程中。
- **子步骤**:
    - [x] 设计 `ContentView.swift` 作为主入口视图。
    - [x] 根据应用状态（是否已配置账户、是否已选择存储桶）条件性地展示不同视图。
    - [x] 例如：首次启动 -> 账户配置 -> 存储桶选择 -> 文件列表。
    - [x] 管理全局应用状态（如当前选中的账户、存储桶、路径）。
- **所需资源**: SwiftUI, 状态管理。
- **输出内容**: `ContentView.swift` 及相关状态管理逻辑。

### Task 3.2: 全局错误处理与用户反馈 (P2) ✅
- **目标**: 实现统一的错误处理机制，并向用户提供清晰的反馈。
- **子步骤**:
    - [x] 定义通用的错误类型或使用 `Error`协议。
    - [x] 在 `R2Service` 的 API 调用中统一捕获和抛出错误。
    - [x] 在 SwiftUI 视图中使用统一的消息系统向用户展示操作成功/失败的信息及错误详情。
    - [x] 对于长时间运行的操作（如列表加载、上传），提供加载指示器和状态反馈。
- **所需资源**: SwiftUI, Combine (用于处理异步错误)。
- **输出内容**: 完整的 MessageBanner 系统和全局错误处理机制。

### Task 3.3: UI 细节打磨与刷新逻辑 (P3) ✅
- **目标**: 优化 UI 细节，确保刷新逻辑在各种操作后能正确更新视图。
- **子步骤**:
    - [x] 在 `FileListView` 中添加手动"刷新"按钮。
    - [x] 确保上传文件、创建文件夹后，文件列表能自动或手动刷新。
    - [x] 检查并优化图标、字体、间距等 UI 细节。
    - [x] 测试不同屏幕尺寸和暗黑模式下的显示效果。
- **所需资源**: SwiftUI.
- **输出内容**: 更精美的 UI 和更可靠的视图更新。

### Task 3.4: 应用图标与基本元数据 (P3)
- **目标**: 为应用设置图标和基本的 Bundle 信息。
- **子步骤**:
    - [ ] 设计或选择一个应用图标 (`AppIcon.appiconset`)。
    - [ ] 在 Xcode 项目设置中配置应用版本号、Bundle Identifier 等。
- **所需资源**: 图形资源, Xcode。
- **输出内容**: 配置了图标和元数据的应用。

---
**优先级说明**: P1 (高), P2 (中), P3 (低) 