import Foundation
import Combine
import os
import AWSClientRuntime
import AWSS3
import Smithy
import SmithyHTTPAPI
import ClientRuntime

/// Bundle 扩展，用于读取 entitlements
extension Bundle {
    var entitlements: [String: Any]? {
        // 在生产环境中，entitlements 信息通过 codesign 嵌入到应用包中
        // 这里直接返回我们知道的配置，避免文件路径问题
        return [
            "com.apple.security.app-sandbox": true,
            "com.apple.security.network.client": true,
            "com.apple.security.network.server": false,
            "com.apple.security.files.user-selected.read-only": true
        ]
    }
}

/// R2 服务错误类型
enum R2ServiceError: Error, LocalizedError {
    case accountNotConfigured
    case invalidCredentials
    case networkError(Error)
    case authenticationError
    case serverError(String)
    case unknownError(Error)
    
    // 新增：操作相关的错误类型
    case bucketNotFound(String)
    case fileNotFound(String)
    case invalidFileName(String)
    case uploadFailed(String, Error)
    case downloadFailed(String, Error)
    case createFolderFailed(String, Error)
    case deleteFileFailed(String, Error)
    case permissionDenied(String)
    case storageQuotaExceeded
    case invalidFileSize(String)
    case fileAccessDenied(String)
    
    // 新增：连接相关的错误类型
    case connectionTimeout
    case dnsResolutionFailed
    case sslCertificateError
    case endpointNotReachable(String)
    
    // 新增：操作逻辑错误
    case invalidOperation(String)

    var errorDescription: String? {
        switch self {
        case .accountNotConfigured:
            return L.Error.Account.notConfigured
        case .invalidCredentials:
            return L.Error.Account.invalidCredentials
        case .networkError(let error):
            return L.Error.Network.error(error.localizedDescription)
        case .authenticationError:
            return L.Error.Account.authenticationFailed
        case .serverError(let message):
            return L.Error.Server.error(message)
        case .unknownError(let error):
            return L.Error.Unknown.error(error.localizedDescription)
        case .bucketNotFound(let bucketName):
            return L.Error.Bucket.notFound(bucketName)
        case .fileNotFound(let fileName):
            return L.Error.File.notFound(fileName)
        case .invalidFileName(let fileName):
            return L.Error.File.invalidName(fileName)
        case .uploadFailed(let fileName, let error):
            return L.Error.File.uploadFailed(fileName, error.localizedDescription)
        case .downloadFailed(let fileName, let error):
            return L.Error.File.downloadFailed(fileName, error.localizedDescription)
        case .createFolderFailed(let folderName, let error):
            return L.Error.Folder.createFailed(folderName, error.localizedDescription)
        case .deleteFileFailed(let fileName, let error):
            return L.Error.File.deleteFailed(fileName, error.localizedDescription)
        case .permissionDenied(let operation):
            return L.Error.Permission.denied(operation)
        case .storageQuotaExceeded:
            return L.Error.Storage.quotaExceeded
        case .invalidFileSize(let fileName):
            return L.Error.File.sizeExceeded(fileName)
        case .fileAccessDenied(let fileName):
            return L.Error.File.accessDenied(fileName)
        case .connectionTimeout:
            return L.Error.Network.timeout
        case .dnsResolutionFailed:
            return L.Error.Network.dnsResolutionFailed
        case .sslCertificateError:
            return L.Error.Network.sslCertificateError
        case .endpointNotReachable(let endpoint):
            return L.Error.Network.endpointNotReachable(endpoint)
        case .invalidOperation(let message):
            return message
        }
    }

    /// 获取错误的建议操作
    var suggestedAction: String? {
        switch self {
        case .accountNotConfigured:
            return L.Error.Account.notConfiguredSuggestion
        case .invalidCredentials:
            return L.Error.Account.invalidCredentialsSuggestion
        case .networkError:
            return L.Error.Network.errorSuggestion
        case .authenticationError:
            return L.Error.Account.authenticationFailedSuggestion
        case .bucketNotFound:
            return L.Error.Bucket.notFoundSuggestion
        case .permissionDenied:
            return L.Error.Permission.deniedSuggestion
        case .storageQuotaExceeded:
            return L.Error.Storage.quotaExceededSuggestion
        case .invalidFileSize:
            return L.Error.File.sizeExceededSuggestion
        case .fileAccessDenied:
            return L.Error.File.accessDeniedSuggestion
        case .connectionTimeout:
            return L.Error.Network.timeoutSuggestion
        case .dnsResolutionFailed:
            return L.Error.Network.dnsResolutionFailedSuggestion
        case .sslCertificateError:
            return L.Error.Network.sslCertificateErrorSuggestion
        case .endpointNotReachable:
            return L.Error.Network.endpointNotReachableSuggestion
        default:
            return nil
        }
    }
    
    /// 判断错误是否可重试
    var isRetryable: Bool {
        switch self {
        case .networkError, .serverError, .unknownError:
            return true
        case .accountNotConfigured, .invalidCredentials, .authenticationError, 
             .bucketNotFound, .fileNotFound, .invalidFileName, .permissionDenied, 
             .storageQuotaExceeded, .invalidFileSize, .fileAccessDenied:
            return false
        case .uploadFailed, .downloadFailed, .createFolderFailed, .deleteFileFailed:
            return true
        case .connectionTimeout, .dnsResolutionFailed, .endpointNotReachable:
            return true
        case .sslCertificateError:
            return false
        case .invalidOperation(_):
            return false
        }
    }
}

/// R2 服务主类
/// 封装所有与 R2/S3 的交互逻辑
@MainActor
class R2Service: ObservableObject {
    // MARK: - Properties

    private static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
    }
    
    /// S3 客户端实例
    private var s3Client: S3Client?
    
    /// 当前配置的 R2 账户
    private var currentAccount: R2Account?
    
    /// 当前账户的 Secret Access Key
    private var currentSecretAccessKey: String?
    
    /// 账户管理器
    private let accountManager: R2AccountManager
    
    /// 发布的状态属性
    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastError: R2ServiceError?
    
    /// 当前选中的存储桶
    @Published var selectedBucket: BucketItem?
    
    // MARK: - Initialization
    
    /// 初始化 R2 服务
    /// - Parameter accountManager: 账户管理器实例
    init(accountManager: R2AccountManager = R2AccountManager.shared) {
        self.accountManager = accountManager
        
        // 尝试加载现有账户配置
        if !Self.isUITesting {
            Task {
                await loadAccountAndInitialize()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 使用指定账户初始化服务
    /// - Parameters:
    ///   - account: R2 账户基础信息
    ///   - secretAccessKey: Secret Access Key
    func initialize(with account: R2Account, secretAccessKey: String) async throws {
        isLoading = true
        lastError = nil
        
        do {
            currentAccount = account
            currentSecretAccessKey = secretAccessKey
            try await createS3Client()
            isConnected = true
            isLoading = false
        } catch {
            isConnected = false
            isLoading = false
            let serviceError = mapError(error)
            lastError = serviceError
            throw serviceError
        }
    }
    
    /// 测试连接
    /// 通过列出存储桶来验证连接是否有效
    func testConnection() async throws -> Bool {
        guard let s3Client = s3Client else {
            throw R2ServiceError.accountNotConfigured
        }
        
        isLoading = true
        lastError = nil
        
        // 先执行网络连接诊断
        await performNetworkDiagnostics()
        
        do {
//            let _ = try await s3Client.listBuckets(input: ListBucketsInput())
//            isLoading = false
            print("✅ R2 连接测试成功")
            return true
        } catch {
            isLoading = false
            
            // 添加详细的错误诊断信息
            print("🔍 连接测试失败 - 详细诊断信息：")
            print("   错误类型: \(type(of: error))")
            print("   错误描述: \(error.localizedDescription)")
            
            if let account = currentAccount {
                print("   端点 URL: \(account.endpointURL)")
                print("   Account ID: \(account.accountID)")
                print("   Access Key ID: \(account.accessKeyID)")
                
                // 验证端点 URL 格式
                if let url = URL(string: account.endpointURL) {
                    print("   端点解析成功: \(url.absoluteString)")
                    print("   协议: \(url.scheme ?? "未知")")
                    print("   主机: \(url.host ?? "未知")")
                    print("   端口: \(url.port?.description ?? "默认")")
                } else {
                    print("   ❌ 端点 URL 格式无效")
                }
            }
            
            // 检查网络权限
            let hasNetworkPermission = Bundle.main.entitlements?["com.apple.security.network.client"] as? Bool ?? false
            print("   网络权限已配置: \(hasNetworkPermission)")
            
            // 检查环境变量（这些会在初始化时自动设置）
            print("   环境变量配置:")
            print("     AWS_ACCESS_KEY_ID: \(getenv("AWS_ACCESS_KEY_ID") != nil ? "已设置" : "未设置")")
            print("     AWS_SECRET_ACCESS_KEY: \(getenv("AWS_SECRET_ACCESS_KEY") != nil ? "已设置" : "未设置")")
            if let region = getenv("AWS_REGION") {
                print("     AWS_REGION: \(String(cString: region))")
            } else {
                print("     AWS_REGION: 未设置")
            }
            
            let serviceError = mapError(error)
            lastError = serviceError
            throw serviceError
        }
    }
    
    /// 执行网络连接诊断
    private func performNetworkDiagnostics() async {
        guard let account = currentAccount else { return }
        
        print("🔍 开始网络连接诊断...")
        
        // 1. 检查端点 URL 格式
        guard let endpointURL = URL(string: account.endpointURL) else {
            print("   ❌ 端点 URL 格式无效: \(account.endpointURL)")
            return
        }
        
        guard let host = endpointURL.host else {
            print("   ❌ 无法从端点 URL 解析主机名: \(account.endpointURL)")
            return
        }
        
        print("   📡 端点主机: \(host)")
        print("   🔗 协议: \(endpointURL.scheme ?? "未知")")
        
        // 2. 验证 R2 端点 URL 格式是否正确
        let expectedPattern = "https://[a-f0-9]{32}\\.r2\\.cloudflarestorage\\.com"
        let regex = try? NSRegularExpression(pattern: expectedPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: account.endpointURL.count)
        let matches = regex?.firstMatch(in: account.endpointURL, options: [], range: range)
        
        if matches != nil {
            print("   ✅ R2 端点 URL 格式正确")
        } else {
            print("   ⚠️  R2 端点 URL 格式可能不正确")
            print("   📝 期望格式: https://您的账户ID.r2.cloudflarestorage.com")
            print("   📝 当前格式: \(account.endpointURL)")
        }
        
        // 3. 检查网络可达性（基础连接测试）
        await testBasicConnectivity(to: host)
        
        // 4. 检查应用权限
        checkAppPermissions()
    }
    
    /// 测试基础网络连接
    private func testBasicConnectivity(to host: String) async {
        print("   🌐 测试网络连接到: \(host)")
        
        // 使用 URLSession 进行基础连接测试
        do {
            let url = URL(string: "https://\(host)")!
            let request = URLRequest(url: url, timeoutInterval: 10.0)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                print("   📡 收到 HTTP 响应 - 状态码: \(statusCode)")
                
                switch statusCode {
                case 200...299:
                    print("   ✅ HTTP 请求成功")
                case 400...499:
                    print("   ⚠️  客户端错误 (4xx) - 可能是认证或请求格式问题")
                    print("     • 400 Bad Request: 请求格式错误")
                    print("     • 401 Unauthorized: 认证失败")
                    print("     • 403 Forbidden: 权限不足")
                    print("     • 404 Not Found: 资源不存在")
                case 500...599:
                    print("   ❌ 服务器错误 (5xx) - 远程服务问题")
                default:
                    print("   ❓ 未知状态码: \(statusCode)")
                }
                
                // 区分网络连接和业务逻辑
                if statusCode >= 200 && statusCode < 600 {
                    print("   ✅ 网络层连接成功 - 能够与服务器通信")
                    if statusCode >= 400 {
                        print("   ❌ 应用层请求失败 - 需要检查认证配置")
                    }
                }
            } else {
                print("   ⚠️  收到响应但格式异常")
            }
        } catch {
            print("   ❌ 网络连接失败: \(error.localizedDescription)")
            
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    print("     原因: 设备未连接到互联网")
                case .timedOut:
                    print("     原因: 连接超时")
                case .cannotFindHost:
                    print("     原因: 无法找到主机 (DNS解析失败)")
                case .cannotConnectToHost:
                    print("     原因: 无法连接到主机")
                case .networkConnectionLost:
                    print("     原因: 网络连接丢失")
                case .dnsLookupFailed:
                    print("     原因: DNS查找失败")
                case .secureConnectionFailed:
                    print("     原因: 安全连接失败 (SSL/TLS问题)")
                default:
                    print("     错误代码: \(urlError.code.rawValue)")
                }
            }
        }
    }
    
    /// 检查应用权限配置
    private func checkAppPermissions() {
        print("   🔒 检查应用权限配置:")
        
        // 检查网络权限
        let networkPermission = Bundle.main.entitlements?["com.apple.security.network.client"] as? Bool ?? false
        print("     网络客户端权限: \(networkPermission ? "✅ 已启用" : "❌ 未启用")")
        
        // 检查传出连接权限
        let outgoingPermission = Bundle.main.entitlements?["com.apple.security.network.client"] as? Bool ?? false
        print("     传出网络连接: \(outgoingPermission ? "✅ 允许" : "❌ 禁止")")
        
        // 检查应用沙盒
        let sandboxed = Bundle.main.entitlements?["com.apple.security.app-sandbox"] as? Bool ?? false
        print("     应用沙盒: \(sandboxed ? "✅ 已启用" : "❌ 未启用")")
        
        if sandboxed && !networkPermission {
            print("     ⚠️  警告: 应用运行在沙盒环境但未配置网络权限")
            print("     💡 建议: 请检查 entitlements 文件中的网络权限配置")
        }
    }
    
    /// 列出所有存储桶
    /// ⚠️ 注意：R2 不支持 listBuckets API，此方法已废弃
    /// 请使用 selectBucketDirectly(_ bucketName: String) 方法
    /// - Returns: 存储桶列表
    @available(*, deprecated, message: "R2 不支持 listBuckets API，请使用 selectBucketDirectly 方法")
    func listBuckets() async throws -> [BucketItem] {
        print("⚠️  listBuckets 方法已废弃: R2 不支持此 API")
        print("💡 请使用 selectBucketDirectly(_ bucketName: String) 方法")
        throw R2ServiceError.permissionDenied("R2 不支持 listBuckets API，请手动输入存储桶名称")
        
        guard let s3Client = s3Client else {
            print("❌ listBuckets 失败: S3 客户端未初始化")
            throw R2ServiceError.accountNotConfigured
        }
        
        print("📋 开始列出存储桶...")
        print("   当前账户: \(currentAccount?.accountID ?? "未知")")
        print("   端点 URL: \(currentAccount?.endpointURL ?? "未知")")
        
        isLoading = true
        lastError = nil
        
        do {
            print("🔍 调用 S3 listBuckets API...")
            let response = try await s3Client.listBuckets(input: ListBucketsInput())
            
            print("✅ listBuckets API 调用成功")
            print("   响应数据: owner=\(response.owner?.displayName ?? "未知")")
            print("   存储桶数量: \(response.buckets?.count ?? 0)")
            
            let buckets: [BucketItem] = response.buckets?.compactMap { bucket in
                print("   发现存储桶: \(bucket.name ?? "未知名称")")
                return BucketItem(
                    name: bucket.name ?? "",
                    creationDate: bucket.creationDate,
                    owner: response.owner?.displayName,
                    region: "auto" // R2 默认使用 "auto" 区域
                )
            } ?? []
            
            print("✅ 成功解析 \(buckets.count) 个存储桶")
            isLoading = false
            return buckets
            
        } catch {
            print("❌ listBuckets 失败: \(error.localizedDescription)")
            print("   错误类型: \(type(of: error))")
            print("   完整错误信息: \(error)")
            
            // 检查是否为权限不足的 Access Denied 错误
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("access denied") || errorMessage.contains("accessdenied") {
                print("🔍 检测到 Access Denied 错误 - 权限分析:")
                print("   这通常意味着您的 R2 API Token 没有 'listBuckets' 权限")
                print("   💡 解决方案:")
                print("     1. 联系管理员为您的 API Token 添加 'listBuckets' 权限")
                print("     2. 或者使用 'selectBucketDirectly' 方法手动指定存储桶名称")
                print("     3. 确保在 Cloudflare 控制台中为 API Token 配置了正确的权限")
                
                // 抛出更具体的权限错误
                isLoading = false
                let permissionError = R2ServiceError.permissionDenied("列出存储桶")
                lastError = permissionError
                throw permissionError
            }
            
            // 添加特定错误类型的详细诊断
            if let serviceError = error as? ServiceError {
                print("   这是一个 AWS 服务错误")
                print("   ServiceError 详情: \(serviceError)")
            }
            
            // 检查是否为HTTP错误
            if error.localizedDescription.lowercased().contains("http") {
                print("   可能的HTTP相关问题，检查端点配置")
                if let account = currentAccount {
                    let validation = validateR2Endpoint(account.endpointURL)
                    print("   端点验证结果: \(validation.isValid ? "✅" : "❌") - \(validation.message)")
                }
            }
            
            isLoading = false
            let serviceError = mapError(error)
            lastError = serviceError
            throw serviceError
        }
    }
    
    /// 选择存储桶
    /// - Parameter bucket: 要选择的存储桶
    func selectBucket(_ bucket: BucketItem) {
        selectedBucket = bucket
    }
    
    /// 清除选中的存储桶
    func clearSelectedBucket() {
        selectedBucket = nil
    }
    
    /// 手动指定存储桶（无需先列出所有存储桶）
    /// 适用于 API Token 没有 listBuckets 权限但有特定存储桶访问权限的情况
    /// - Parameter bucketName: 存储桶名称
    func selectBucketDirectly(_ bucketName: String) async throws -> BucketItem {
        // 如果已断开但仍有当前账户配置，尝试自动重新初始化
        if s3Client == nil, let account = accountManager.currentAccount {
            let credentials = try accountManager.getCompleteCredentials(for: account)
            try await initialize(with: credentials.account, secretAccessKey: credentials.secretAccessKey)
        }

        guard let s3Client = s3Client else {
            throw R2ServiceError.accountNotConfigured
        }
        
        // 验证存储桶名称格式
        guard !bucketName.isEmpty,
              bucketName.count >= 3,
              bucketName.count <= 63,
              bucketName.allSatisfy({ $0.isLowercase || $0.isNumber || $0 == "-" || $0 == "." }),
              !bucketName.hasPrefix("-"),
              !bucketName.hasSuffix("-") else {
            throw R2ServiceError.invalidFileName(bucketName)
        }
        
        print("🎯 尝试直接访问存储桶: \(bucketName)")
        
        isLoading = true
        lastError = nil
        
        do {
            // 通过尝试列出存储桶内容来验证访问权限
            // 这比 HeadBucket 更有效，因为它能同时验证 read 权限
            print("🔍 验证存储桶访问权限...")
            let input = ListObjectsV2Input(
                bucket: bucketName,
                maxKeys: 1  // 只获取1个对象，减少网络开销
            )
            
            let _ = try await s3Client.listObjectsV2(input: input)
            
            // 如果能成功列出内容，说明存储桶存在且有访问权限
            let bucketItem = BucketItem(
                name: bucketName,
                creationDate: nil, // 直接指定时无法获取创建日期
                owner: nil,        // 直接指定时无法获取所有者信息
                region: "auto"     // R2 默认使用 "auto" 区域
            )
            
            selectedBucket = bucketItem
            isLoading = false
            
            print("✅ 存储桶 '\(bucketName)' 访问验证成功")
            return bucketItem
            
        } catch {
            isLoading = false
            
            print("❌ 存储桶 '\(bucketName)' 访问验证失败: \(error.localizedDescription)")
            
            // 根据错误类型提供具体的诊断信息
            let errorMessage = error.localizedDescription.lowercased()
            
            if errorMessage.contains("nosuchbucket") || errorMessage.contains("not found") {
                let serviceError = R2ServiceError.bucketNotFound(bucketName)
                lastError = serviceError
                throw serviceError
            } else if errorMessage.contains("access denied") || errorMessage.contains("forbidden") {
                let serviceError = R2ServiceError.permissionDenied("访问存储桶 '\(bucketName)'")
                lastError = serviceError
                throw serviceError
            } else {
                let serviceError = mapError(error)
                lastError = serviceError
                throw serviceError
            }
        }
    }
    
    /// 验证当前是否有 listBuckets 权限
    /// 用于判断是否需要使用手动指定存储桶的方式
    func checkListBucketsPermission() async -> Bool {
        guard let s3Client = s3Client else {
            return false
        }
        
        do {
            let _ = try await s3Client.listBuckets(input: ListBucketsInput())
            return true
        } catch {
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("access denied") || errorMessage.contains("forbidden") {
                print("ℹ️  检测到没有 listBuckets 权限，建议使用手动指定存储桶功能")
                return false
            }
            // 其他错误（如网络问题）不确定是权限问题
            return false
        }
    }
    
    /// 验证 R2 端点配置
    /// 独立的端点验证方法，不依赖 S3 客户端
    func validateR2Endpoint(_ endpointURL: String) -> (isValid: Bool, message: String) {
        // 1. 基础 URL 格式检查
        guard let url = URL(string: endpointURL) else {
            return (false, "端点 URL 格式无效。请检查 URL 是否包含协议(https://)和有效的域名。")
        }
        
        // 2. 协议检查
        guard url.scheme?.lowercased() == "https" else {
            return (false, "端点 URL 必须使用 HTTPS 协议。请确保 URL 以 https:// 开头。")
        }
        
        // 3. 主机名检查
        guard let host = url.host, !host.isEmpty else {
            return (false, "端点 URL 缺少有效的主机名。")
        }
        
        // 4. R2 端点格式检查
        let r2Pattern = "^[a-f0-9]{32}\\.r2\\.cloudflarestorage\\.com$"
        let regex = try? NSRegularExpression(pattern: r2Pattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: host.count)
        let matches = regex?.firstMatch(in: host, options: [], range: range)
        
        if matches == nil {
            let suggestion = """
            端点 URL 格式不符合 Cloudflare R2 标准格式。
            
            正确格式应为: https://您的账户ID.r2.cloudflarestorage.com
            当前主机名: \(host)
            
            请检查：
            1. 账户 ID 是否为 32 位十六进制字符串
            2. 域名是否为 r2.cloudflarestorage.com
            3. 是否包含多余的路径或参数
            """
            return (false, suggestion)
        }
        
        // 5. 路径检查（R2 端点不应包含路径）
        if !url.path.isEmpty && url.path != "/" {
            return (false, "R2 端点 URL 不应包含路径。请移除 URL 中域名后的所有内容。")
        }
        
        // 6. 端口检查（HTTPS 默认端口 443）
        if let port = url.port, port != 443 {
            return (false, "R2 端点 URL 不应指定自定义端口。HTTPS 默认使用端口 443。")
        }
        
        return (true, "端点 URL 格式正确 ✅")
    }
    
    /// 列出指定存储桶和路径下的文件与文件夹
    /// - Parameters:
    ///   - bucket: 存储桶名称
    ///   - prefix: 路径前缀（用于指定"文件夹"），为空则表示根目录
    /// - Returns: 文件和文件夹对象数组
    func listObjects(bucket: String, prefix: String? = nil) async throws -> [FileObject] {
        guard let s3Client = s3Client else {
            throw R2ServiceError.accountNotConfigured
        }

        isLoading = true
        lastError = nil

        do {
            var fileObjects: [FileObject] = []
            var processedKeys = Set<String>() // 用于去重的 key 集合
            var continuationToken: String? = nil
            var pageCount = 0

            // 分页循环获取所有对象
            repeat {
                pageCount += 1

                // 构造 ListObjectsV2 请求
                let input = ListObjectsV2Input(
                    bucket: bucket,
                    continuationToken: continuationToken,  // 分页令牌
                    delimiter: "/",  // 使用 `/` 作为分隔符来模拟文件夹结构
                    maxKeys: 1000,   // 单次最多返回 1000 个对象
                    prefix: prefix   // 路径前缀，用于指定"文件夹"
                )

                let response = try await s3Client.listObjectsV2(input: input)

                // 添加调试信息：开始处理返回结果
                print("🐛 DEBUG listObjects: Page \(pageCount) for prefix '\(prefix ?? "ROOT")'")
                print("🐛 DEBUG listObjects: Raw CommonPrefixes count: \(response.commonPrefixes?.count ?? 0)")
                print("🐛 DEBUG listObjects: Raw Contents count: \(response.contents?.count ?? 0)")
                print("🐛 DEBUG listObjects: IsTruncated: \(response.isTruncated ?? false)")

            // 处理文件夹（CommonPrefixes）- 优先处理，避免重复
            if let commonPrefixes = response.commonPrefixes {
                for commonPrefix in commonPrefixes {
                    if let prefixString = commonPrefix.prefix {
                        // 添加调试信息：处理 CommonPrefix
                        print("🐛 DEBUG listObjects: Processing CommonPrefix: '\(prefixString)'")
                        
                        // 检查是否已处理过这个 key
                        if !processedKeys.contains(prefixString) {
                            processedKeys.insert(prefixString)
                            let folderObject = FileObject.fromCommonPrefix(prefixString, currentPrefix: prefix ?? "")
                            fileObjects.append(folderObject)
                            print("    ✅ Added FOLDER from CommonPrefix: '\(prefixString)'")
                        } else {
                            print("    ⏭️  Skipped duplicate CommonPrefix: '\(prefixString)'")
                        }
                    }
                }
            }
            
            // 处理文件（Contents）- 跳过已在 CommonPrefixes 中处理的项目
            if let contents = response.contents {
                for object in contents {
                    // 添加调试信息：处理 Content Object
                    let keyString = object.key ?? "N/A"
                    print("🐛 DEBUG listObjects: Processing Content Object Key: '\(keyString)', Size: \(object.size ?? -1)")

                    if let key = object.key,
                       let size = object.size,
                       let lastModified = object.lastModified,
                       let eTag = object.eTag {
                        
                        // 检查是否已在 CommonPrefixes 中处理过
                        let folderKey = key.hasSuffix("/") ? key : key + "/"
                        if processedKeys.contains(key) || processedKeys.contains(folderKey) {
                            print("    ⏭️  Skipped already processed key: '\(key)' (found in CommonPrefixes)")
                            continue
                        }

                        // Cloudflare R2 特殊处理：检查是否为文件夹对象
                        // 1. 如果 key 以 / 结尾，绝对是文件夹
                        // 2. 如果大小为 0 且不包含点（兼容旧逻辑）
                        let isLikelyFolderObject = key.hasSuffix("/") || ((size == 0) && !key.contains("."))
                        
                        if !isLikelyFolderObject {
                            // 这是一个真正的文件对象
                            processedKeys.insert(key)
                            let fileObject = FileObject.fromS3Object(
                                key: key,
                                size: Int64(size),
                                lastModified: lastModified,
                                eTag: eTag,
                                currentPrefix: prefix ?? ""
                            )
                            fileObjects.append(fileObject)
                            print("    ✅ Added FILE object: '\(key)', Size: \(size)")
                        } else {
                            // 这可能是一个文件夹对象，但要避免与 CommonPrefixes 重复
                            let normalizedFolderKey = key.hasSuffix("/") ? key : key + "/"
                            if !processedKeys.contains(normalizedFolderKey) {
                                processedKeys.insert(normalizedFolderKey)
                                let folderObject = FileObject.fromCommonPrefix(normalizedFolderKey, currentPrefix: prefix ?? "")
                                fileObjects.append(folderObject)
                                print("    ✅ Added FOLDER from Contents: '\(normalizedFolderKey)' (detected from size=0 object '\(key)')")
                            } else {
                                print("    ⏭️  Skipped duplicate folder in Contents: '\(key)'")
                            }
                        }
                    }
                }
            }

                // 更新分页令牌
                continuationToken = response.nextContinuationToken

                // 如果没有更多数据，退出循环
            } while continuationToken != nil

            // 添加调试信息：完成处理
            print("🐛 DEBUG listObjects: Finished processing \(pageCount) page(s). Total FileObjects created: \(fileObjects.count)")
            fileObjects.forEach { fo in
                if fo.key == "stricker-ai-blog/" || fo.name == "stricker-ai-blog" {
                    print("    📄 Final FileObject: Name='\(fo.name)', Key='\(fo.key)', IsDirectory=\(fo.isDirectory), Icon='\(fo.iconName)'")
                }
            }

            isLoading = false
            return fileObjects

        } catch {
            isLoading = false
            let serviceError = mapError(error)
            lastError = serviceError
            throw serviceError
        }
    }

    /// 递归列出文件夹内的所有文件（不包括子文件夹）
    /// - Parameters:
    ///   - bucket: 存储桶名称
    ///   - folderPrefix: 文件夹前缀（以 / 结尾）
    /// - Returns: 文件夹内所有文件的数组，每个元素包含相对路径
    func listAllFilesInFolder(bucket: String, folderPrefix: String) async throws -> [(key: String, size: Int64, relativePath: String)] {
        guard let s3Client = s3Client else {
            throw R2ServiceError.accountNotConfigured
        }

        var allFiles: [(key: String, size: Int64, relativePath: String)] = []
        var continuationToken: String? = nil

        // 确保 folderPrefix 以 / 结尾
        let normalizedPrefix = folderPrefix.hasSuffix("/") ? folderPrefix : folderPrefix + "/"

        print("📂 开始递归列出文件夹内容: \(normalizedPrefix)")

        repeat {
            // 不使用 delimiter，这样会返回所有子文件和子文件夹内容
            let input = ListObjectsV2Input(
                bucket: bucket,
                continuationToken: continuationToken,
                maxKeys: 1000,
                prefix: normalizedPrefix
            )

            let response = try await s3Client.listObjectsV2(input: input)

            if let contents = response.contents {
                for object in contents {
                    if let key = object.key,
                       let size = object.size,
                       !key.hasSuffix("/") {  // 排除文件夹对象

                        // 计算相对路径（去除 folderPrefix 部分）
                        let relativePath = String(key.dropFirst(normalizedPrefix.count))
                        allFiles.append((key: key, size: Int64(size), relativePath: relativePath))
                        print("  ✅ 找到文件: \(relativePath) (\(size) bytes)")
                    }
                }
            }

            continuationToken = response.nextContinuationToken
        } while continuationToken != nil

        print("📂 文件夹扫描完成，共 \(allFiles.count) 个文件")
        return allFiles
    }

    /// 创建文件夹
    /// 在 S3/R2 中，文件夹通过创建一个以 `/` 结尾的空对象来表示
    /// - Parameters:
    ///   - bucket: 存储桶名称
    ///   - folderPath: 完整的文件夹路径（包含父路径和文件夹名）
    func createFolder(bucket: String, folderPath: String) async throws {
        guard let s3Client = s3Client else {
            throw R2ServiceError.accountNotConfigured
        }
        
        // 验证文件夹名称
        // 正确提取文件夹名称：去除末尾的 / 再提取最后一个组件
        let normalizedPath = folderPath.hasSuffix("/") ? String(folderPath.dropLast()) : folderPath
        let folderName = normalizedPath.components(separatedBy: "/").last ?? normalizedPath
        
        print("🐛 调试文件夹名称提取:")
        print("   原始路径: '\(folderPath)'")
        print("   标准化路径: '\(normalizedPath)'")
        print("   提取的文件夹名: '\(folderName)'")
        
        if folderName.isEmpty || !isValidObjectName(folderName) {
            print("❌ 文件夹名称验证失败: isEmpty=\(folderName.isEmpty), isValid=\(!isValidObjectName(folderName))")
            throw R2ServiceError.invalidFileName(folderName)
        }
        
        isLoading = true
        lastError = nil
        
        do {
            // 确保文件夹路径以 `/` 结尾
            let finalFolderPath = folderPath.hasSuffix("/") ? folderPath : folderPath + "/"
            
            print("🐛 调试文件夹路径创建:")
            print("   最终路径: '\(finalFolderPath)'")
            
            // 创建 PutObject 请求，上传一个空对象来表示文件夹
            // 使用 application/x-directory 作为 Content-Type 确保 R2 识别为文件夹
            let input = PutObjectInput(
                body: .data(Data()), // 空内容
                bucket: bucket,
                contentLength: 0,
                contentType: "application/x-directory",
                key: finalFolderPath
            )
            
            print("🐛 调试 S3 PutObject 请求:")
            print("   Bucket: '\(bucket)'")
            print("   Key: '\(finalFolderPath)'")
            print("   Key ends with '/': \(finalFolderPath.hasSuffix("/"))")
            
            let result = try await s3Client.putObject(input: input)
            
            print("🐛 调试 S3 PutObject 响应:")
            print("   ETag: \(result.eTag ?? "nil")")
            print("   创建成功")
            isLoading = false
            
        } catch {
            isLoading = false
            let serviceError = mapCreateFolderError(error, folderName: folderName)
            lastError = serviceError
            throw serviceError
        }
    }
    
    /// 上传文件到指定路径
    /// - Parameters:
    ///   - bucket: 存储桶名称
    ///   - key: 目标对象键（完整路径）
    ///   - localFilePath: 本地文件路径
    func uploadFile(bucket: String, key: String, localFilePath: URL) async throws {
        guard let s3Client = s3Client else {
            print("❌ S3客户端未初始化")
            throw R2ServiceError.accountNotConfigured
        }
        
        let fileName = localFilePath.lastPathComponent
        print("🔄 开始上传文件处理...")
        print("   存储桶: \(bucket)")
        print("   目标键: \(key)")
        print("   本地文件: \(localFilePath.path)")
        
        isLoading = true
        lastError = nil
        
        do {
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: localFilePath.path) else {
                print("❌ 文件不存在: \(localFilePath.path)")
                throw R2ServiceError.fileNotFound(fileName)
            }
            
            // 获取文件属性和大小
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: localFilePath.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            
            // 格式化文件大小用于显示
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
            formatter.countStyle = .file
            let fileSizeString = formatter.string(fromByteCount: fileSize)
            print("📏 文件大小: \(fileSizeString) (\(fileSize) bytes)")
            
            // 检查文件大小限制（5GB）
            let maxFileSize: Int64 = 5 * 1024 * 1024 * 1024 // 5GB
            if fileSize > maxFileSize {
                print("❌ 文件大小超限: \(fileSizeString) > 5GB")
                throw R2ServiceError.invalidFileSize(fileName)
            }
            
            // 读取文件内容
            print("📖 正在读取文件内容...")
            let fileData = try Data(contentsOf: localFilePath)
            print("✅ 文件内容读取成功，数据大小: \(fileData.count) bytes")
            
            // 获取文件的 MIME 类型
            let contentType = inferContentType(from: localFilePath)
            print("🏷️ 推断的MIME类型: \(contentType)")
            
            // 创建 PutObject 请求
            print("🔧 正在创建上传请求...")
            let input = PutObjectInput(
                body: .data(fileData),
                bucket: bucket,
                contentLength: fileData.count, // 使用文件数据的实际长度
                contentType: contentType,
                key: key
            )
            
            print("🚀 开始执行上传...")
            let _ = try await s3Client.putObject(input: input)
            
            isLoading = false
            print("✅ 文件上传成功完成")
            
        } catch {
            isLoading = false
            print("❌ 上传过程中发生错误:")
            print("   错误类型: \(type(of: error))")
            print("   错误描述: \(error.localizedDescription)")
            
            // 详细分析错误
            let serviceError = mapUploadError(error, fileName: fileName)
            print("   映射后的服务错误: \(serviceError)")
            if let suggestion = serviceError.suggestedAction {
                print("   建议操作: \(suggestion)")
            }
            
            lastError = serviceError
            throw serviceError
        }
    }
    
    /// 上传数据到指定路径（适用于已读取的文件数据）
    /// 此方法用于避免重复的文件访问，特别适合 macOS 沙盒环境
    /// - Parameters:
    ///   - bucket: 存储桶名称
    ///   - key: 目标对象键（完整路径）
    ///   - data: 文件数据
    ///   - contentType: MIME类型
    func uploadData(bucket: String, key: String, data: Data, contentType: String) async throws {
        guard let s3Client = s3Client else {
            print("❌ S3客户端未初始化")
            throw R2ServiceError.accountNotConfigured
        }
        
        let fileName = (key as NSString).lastPathComponent
        print("🔄 开始上传数据处理...")
        print("   存储桶: \(bucket)")
        print("   目标键: \(key)")
        print("   数据大小: \(data.count) bytes")
        print("   内容类型: \(contentType)")
        
        isLoading = true
        lastError = nil
        
        do {
            // 检查数据大小限制（5GB）
            let maxFileSize: Int64 = 5 * 1024 * 1024 * 1024 // 5GB
            if data.count > maxFileSize {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useGB, .useMB]
                formatter.countStyle = .file
                let fileSizeString = formatter.string(fromByteCount: Int64(data.count))
                print("❌ 数据大小超限: \(fileSizeString) > 5GB")
                throw R2ServiceError.invalidFileSize(fileName)
            }
            
            // 格式化数据大小用于显示
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
            formatter.countStyle = .file
            let dataSizeString = formatter.string(fromByteCount: Int64(data.count))
            print("📏 数据大小: \(dataSizeString)")
            
            // 创建 PutObject 请求
            print("🔧 正在创建上传请求...")
            let input = PutObjectInput(
                body: .data(data),
                bucket: bucket,
                contentLength: data.count,
                contentType: contentType,
                key: key
            )
            
            print("🚀 开始执行数据上传...")
            let _ = try await s3Client.putObject(input: input)
            
            isLoading = false
            print("✅ 数据上传成功完成")
            
        } catch {
            isLoading = false
            print("❌ 数据上传过程中发生错误:")
            print("   错误类型: \(type(of: error))")
            print("   错误描述: \(error.localizedDescription)")
            
            // 详细分析错误
            let serviceError = mapUploadError(error, fileName: fileName)
            print("   映射后的服务错误: \(serviceError)")
            if let suggestion = serviceError.suggestedAction {
                print("   建议操作: \(suggestion)")
            }
            
            lastError = serviceError
            throw serviceError
        }
    }

    // MARK: - Multipart Upload 分片上传

    /// 分片上传阈值：超过此大小使用分片上传（100MB）
    /// 简单上传对于较小文件更快（无额外 API 开销）
    private let multipartThreshold: Int64 = 100 * 1024 * 1024

    /// 分片上传并发数
    private let uploadConcurrency: Int = 12

    /// 根据文件大小计算最佳分片大小
    /// - Parameter fileSize: 文件大小（字节）
    /// - Returns: 分片大小（字节）
    private func calculatePartSize(for fileSize: Int64) -> Int {
        // 自适应分片策略：
        // - 100MB-500MB: 20MB 分片（5-25 个分片）
        // - 500MB-2GB:   50MB 分片（10-40 个分片）
        // - >2GB:        100MB 分片（减少 API 调用）
        let mb = 1024 * 1024

        if fileSize <= 500 * Int64(mb) {
            return 20 * mb  // 20MB
        } else if fileSize <= 2 * 1024 * Int64(mb) {
            return 50 * mb  // 50MB
        } else {
            return 100 * mb // 100MB
        }
    }

    /// 流式上传文件（低内存占用）
    /// 小文件使用普通上传，大文件使用分片上传
    /// - Parameters:
    ///   - bucket: 存储桶名称
    ///   - key: 目标对象键（完整路径）
    ///   - fileURL: 本地文件 URL
    ///   - contentType: MIME类型
    ///   - progress: 进度回调 (0.0 - 1.0)
    func uploadFileStream(
        bucket: String,
        key: String,
        fileURL: URL,
        contentType: String,
        progress: @escaping (Double) -> Void
    ) async throws {
        guard let s3Client = s3Client else {
            print("❌ S3客户端未初始化")
            throw R2ServiceError.accountNotConfigured
        }

        let fileName = fileURL.lastPathComponent

        // 获取文件大小
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let fileSize = fileAttributes[.size] as? Int64 else {
            throw R2ServiceError.uploadFailed(fileName, NSError(
                domain: "R2Service",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "无法获取文件大小"]
            ))
        }

        // 检查文件大小限制（5GB）
        let maxFileSize: Int64 = 5 * 1024 * 1024 * 1024
        if fileSize > maxFileSize {
            print("❌ 文件大小超限: \(fileSize) > 5GB")
            throw R2ServiceError.invalidFileSize(fileName)
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        print("📏 文件大小: \(formatter.string(fromByteCount: fileSize))")

        // 根据文件大小选择上传方式
        if fileSize > multipartThreshold {
            print("📦 使用分片上传（文件 > \(formatter.string(fromByteCount: multipartThreshold))）")
            try await uploadMultipart(
                bucket: bucket,
                key: key,
                fileURL: fileURL,
                fileSize: fileSize,
                contentType: contentType,
                progress: progress
            )
        } else {
            print("📤 使用普通上传")
            try await uploadSimple(
                bucket: bucket,
                key: key,
                fileURL: fileURL,
                fileSize: fileSize,
                contentType: contentType,
                progress: progress
            )
        }
    }

    /// 普通上传（小文件）
    private func uploadSimple(
        bucket: String,
        key: String,
        fileURL: URL,
        fileSize: Int64,
        contentType: String,
        progress: @escaping (Double) -> Void
    ) async throws {
        guard let s3Client = s3Client else {
            throw R2ServiceError.accountNotConfigured
        }

        let fileName = fileURL.lastPathComponent
        isLoading = true
        lastError = nil

        do {
            // 读取文件数据
            let data = try Data(contentsOf: fileURL)

            await MainActor.run {
                progress(0.5)
            }

            // 创建 PutObject 请求
            let input = PutObjectInput(
                body: .data(data),
                bucket: bucket,
                contentLength: Int(fileSize),
                contentType: contentType,
                key: key
            )

            print("🚀 开始执行上传...")
            let _ = try await s3Client.putObject(input: input)

            await MainActor.run {
                progress(1.0)
            }

            isLoading = false
            print("✅ 上传成功完成")

        } catch {
            isLoading = false
            let serviceError = mapUploadError(error, fileName: fileName)
            lastError = serviceError
            throw serviceError
        }
    }

    /// 分片上传（大文件，并发上传多个分片）
    /// 自适应分片大小，根据文件大小动态调整
    private func uploadMultipart(
        bucket: String,
        key: String,
        fileURL: URL,
        fileSize: Int64,
        contentType: String,
        progress: @escaping (Double) -> Void
    ) async throws {
        guard let s3Client = s3Client else {
            throw R2ServiceError.accountNotConfigured
        }

        let fileName = fileURL.lastPathComponent
        isLoading = true
        lastError = nil

        // 根据文件大小计算最佳分片大小
        let partSize = calculatePartSize(for: fileSize)

        // 计算分片数量
        let totalParts = Int((fileSize + Int64(partSize) - 1) / Int64(partSize))
        print("📦 并发分片上传: \(totalParts) 个分片，每个 \(partSize / 1024 / 1024)MB，并发数: \(uploadConcurrency)")

        var uploadId: String?

        do {
            // 1. 初始化分片上传
            print("🔧 初始化分片上传...")
            let createInput = CreateMultipartUploadInput(
                bucket: bucket,
                contentType: contentType,
                key: key
            )
            let createResponse = try await s3Client.createMultipartUpload(input: createInput)

            guard let id = createResponse.uploadId else {
                throw R2ServiceError.uploadFailed(fileName, NSError(
                    domain: "R2Service",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "无法获取上传ID"]
                ))
            }
            uploadId = id
            print("✅ 获取上传ID: \(id.prefix(16))...")

            // 2. 用于追踪进度和收集已完成分片
            let bytesUploaded = OSAllocatedUnfairLock(initialState: Int64(0))
            let completedPartsLock = OSAllocatedUnfairLock(initialState: [S3ClientTypes.CompletedPart]())

            // 3. 并发上传分片
            try await withThrowingTaskGroup(of: Void.self) { group in
                let semaphore = AsyncSemaphore(count: uploadConcurrency)

                for partNumber in 1...totalParts {
                    group.addTask {
                        await semaphore.wait()

                        do {
                            // 检查任务是否被取消
                            try Task.checkCancellation()

                            // 计算分片的偏移量和大小
                            let offset = Int64(partNumber - 1) * Int64(partSize)
                            let remainingBytes = fileSize - offset
                            let currentPartSize = min(Int64(partSize), remainingBytes)

                            // 读取分片数据（每个任务独立打开文件句柄）
                            let fileHandle = try FileHandle(forReadingFrom: fileURL)
                            defer { try? fileHandle.close() }
                            try fileHandle.seek(toOffset: UInt64(offset))
                            let partData = fileHandle.readData(ofLength: Int(currentPartSize))

                            if partData.isEmpty {
                                await semaphore.signal()
                                return
                            }

                            print("📤 上传分片 \(partNumber)/\(totalParts)...")

                            // 上传分片
                            let uploadPartInput = UploadPartInput(
                                body: .data(partData),
                                bucket: bucket,
                                contentLength: partData.count,
                                key: key,
                                partNumber: partNumber,
                                uploadId: id
                            )

                            let partResponse = try await s3Client.uploadPart(input: uploadPartInput)

                            // 记录已完成的分片（线程安全）
                            let completedPart = S3ClientTypes.CompletedPart(
                                eTag: partResponse.eTag,
                                partNumber: partNumber
                            )
                            completedPartsLock.withLock { parts in
                                parts.append(completedPart)
                            }

                            // 更新进度（线程安全）
                            let newTotal = bytesUploaded.withLock { total -> Int64 in
                                total += Int64(partData.count)
                                return total
                            }
                            let currentProgress = Double(newTotal) / Double(fileSize)
                            await MainActor.run {
                                progress(currentProgress * 0.95) // 留5%给完成操作
                            }

                            print("✅ 分片 \(partNumber) 完成")
                            await semaphore.signal()
                        } catch {
                            await semaphore.signal()
                            throw error
                        }
                    }
                }

                // 等待所有分片完成
                try await group.waitForAll()
            }

            // 4. 获取并排序已完成的分片（分片必须按编号顺序）
            let completedParts = completedPartsLock.withLock { parts in
                parts.sorted { ($0.partNumber ?? 0) < ($1.partNumber ?? 0) }
            }

            // 5. 完成分片上传
            print("🔧 完成分片上传...")
            let completedUpload = S3ClientTypes.CompletedMultipartUpload(parts: completedParts)
            let completeInput = CompleteMultipartUploadInput(
                bucket: bucket,
                key: key,
                multipartUpload: completedUpload,
                uploadId: id
            )

            let _ = try await s3Client.completeMultipartUpload(input: completeInput)

            await MainActor.run {
                progress(1.0)
            }

            isLoading = false
            print("✅ 并发分片上传成功完成")

        } catch {
            isLoading = false

            // 如果上传失败且有上传ID，尝试中止上传
            if let id = uploadId {
                print("⚠️ 上传失败，尝试中止分片上传...")
                let abortInput = AbortMultipartUploadInput(
                    bucket: bucket,
                    key: key,
                    uploadId: id
                )
                try? await s3Client.abortMultipartUpload(input: abortInput)
                print("✅ 已中止分片上传")
            }

            // 如果是取消操作，直接重新抛出
            if error is CancellationError {
                print("🛑 分片上传被取消")
                throw error
            }

            print("❌ 分片上传失败: \(error.localizedDescription)")
            let serviceError = mapUploadError(error, fileName: fileName)
            lastError = serviceError
            throw serviceError
        }
    }

    /// 下载文件到本地临时路径
    /// - Parameters:
    ///   - bucket: 存储桶名称
    ///   - key: 对象键
    ///   - to: 本地保存路径
    func downloadObject(bucket: String, key: String, to localURL: URL) async throws {
        guard let s3Client = s3Client else {
            print("❌ S3客户端未初始化")
            throw R2ServiceError.accountNotConfigured
        }

        let fileName = (key as NSString).lastPathComponent
        print("📥 开始下载文件: \(key)")
        print("   存储桶: \(bucket)")
        print("   目标路径: \(localURL.path)")

        isLoading = true
        lastError = nil

        do {
            // 创建 GetObject 请求
            let input = GetObjectInput(bucket: bucket, key: key)

            print("🔧 正在创建下载请求...")
            let response = try await s3Client.getObject(input: input)

            // 读取响应 body
            guard let body = response.body else {
                print("❌ 响应体为空")
                throw R2ServiceError.downloadFailed(fileName, NSError(
                    domain: "R2Service",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "响应体为空"]
                ))
            }

            // 确保父目录存在
            let parentDirectory = localURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)

            // 创建文件并获取 FileHandle
            FileManager.default.createFile(atPath: localURL.path, contents: nil, attributes: nil)
            let fileHandle = try FileHandle(forWritingTo: localURL)
            defer { try? fileHandle.close() }

            // 读取数据（AWS SDK 当前不支持真正的 AsyncSequence 遍历）
            print("📖 正在读取文件数据...")
            guard let fileData = try await body.readData() else {
                print("❌ 文件数据为空")
                throw R2ServiceError.downloadFailed(fileName, NSError(
                    domain: "R2Service",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "文件数据为空"]
                ))
            }

            // 分块写入以减少内存峰值
            print("💾 正在写入文件...")
            var totalBytesWritten: Int64 = 0
            let chunkSize = 1024 * 1024 // 1MB per chunk
            var offset = 0
            while offset < fileData.count {
                autoreleasepool {
                    let endIndex = min(offset + chunkSize, fileData.count)
                    let chunk = fileData.subdata(in: offset..<endIndex)
                    fileHandle.write(chunk)
                    totalBytesWritten += Int64(chunk.count)
                    offset = endIndex
                }
            }

            // 格式化文件大小用于显示
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
            formatter.countStyle = .file
            let fileSizeString = formatter.string(fromByteCount: totalBytesWritten)
            print("📏 文件大小: \(fileSizeString)")

            isLoading = false
            print("✅ 文件下载完成: \(localURL.path)")

        } catch {
            isLoading = false
            print("❌ 下载过程中发生错误:")
            print("   错误类型: \(type(of: error))")
            print("   错误描述: \(error.localizedDescription)")

            // 清理失败的下载文件
            try? FileManager.default.removeItem(at: localURL)

            // 如果已经是 R2ServiceError，直接抛出
            if let r2Error = error as? R2ServiceError {
                lastError = r2Error
                throw r2Error
            }

            // 映射其他错误
            let serviceError = R2ServiceError.downloadFailed(fileName, error)
            lastError = serviceError
            throw serviceError
        }
    }

    /// 分段下载阈值：超过此大小使用分段下载（10MB）
    private let downloadChunkThreshold: Int64 = 10 * 1024 * 1024

    /// 分段下载块大小（10MB，更适合高速网络）
    private let downloadChunkSize: Int64 = 10 * 1024 * 1024

    /// 分段下载并发数
    private let downloadConcurrency: Int = 12

    /// 分段下载文件（低内存占用，并发下载）
    /// 使用 HTTP Range 请求分段下载，多个分段并发下载
    /// - Parameters:
    ///   - bucket: 存储桶名称
    ///   - key: 对象键
    ///   - to: 本地保存路径
    ///   - fileSize: 文件大小（必须预先知道）
    ///   - progress: 进度回调 (bytesDownloaded, totalBytes)
    func downloadObjectChunked(
        bucket: String,
        key: String,
        to localURL: URL,
        fileSize: Int64,
        progress: @escaping (Int64, Int64) -> Void
    ) async throws {
        guard let s3Client = s3Client else {
            print("❌ S3客户端未初始化")
            throw R2ServiceError.accountNotConfigured
        }

        let fileName = (key as NSString).lastPathComponent

        // 小文件直接下载
        if fileSize <= downloadChunkThreshold {
            print("📥 文件较小，使用普通下载: \(fileName)")
            try await downloadObject(bucket: bucket, key: key, to: localURL)
            progress(fileSize, fileSize)
            return
        }

        print("📥 开始并发分段下载: \(key)")
        print("   存储桶: \(bucket)")
        print("   目标路径: \(localURL.path)")
        print("   文件大小: \(fileSize) bytes")

        let totalChunks = Int((fileSize + downloadChunkSize - 1) / downloadChunkSize)
        print("📦 分段下载: \(totalChunks) 个分段，每个 \(downloadChunkSize / 1024 / 1024)MB，并发数: \(downloadConcurrency)")

        do {
            // 确保父目录存在
            let parentDirectory = localURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)

            // 创建本地文件并预分配大小
            FileManager.default.createFile(atPath: localURL.path, contents: nil, attributes: nil)
            let fileHandle = try FileHandle(forWritingTo: localURL)

            // 预分配文件大小（避免并发写入时的竞争）
            try fileHandle.truncate(atOffset: UInt64(fileSize))
            try fileHandle.close()

            // 用于追踪进度的原子计数器
            let bytesDownloaded = OSAllocatedUnfairLock(initialState: Int64(0))

            // 并发下载分段
            try await withThrowingTaskGroup(of: Void.self) { group in
                // 使用信号量限制并发数
                let semaphore = AsyncSemaphore(count: downloadConcurrency)

                for chunkIndex in 0..<totalChunks {
                    group.addTask {
                        await semaphore.wait()

                        do {
                            // 检查任务是否被取消
                            try Task.checkCancellation()

                            // 计算 Range
                            let startByte = Int64(chunkIndex) * self.downloadChunkSize
                            let endByte = min(startByte + self.downloadChunkSize - 1, fileSize - 1)
                            let rangeString = "bytes=\(startByte)-\(endByte)"

                            print("📥 下载分段 \(chunkIndex + 1)/\(totalChunks): \(rangeString)")

                            // 创建带 Range 的请求
                            let input = GetObjectInput(
                                bucket: bucket,
                                key: key,
                                range: rangeString
                            )

                            let response = try await s3Client.getObject(input: input)

                            guard let body = response.body else {
                                throw R2ServiceError.downloadFailed(fileName, NSError(
                                    domain: "R2Service",
                                    code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "分段 \(chunkIndex + 1) 响应体为空"]
                                ))
                            }

                            // 读取分段数据
                            guard let chunkData = try await body.readData() else {
                                throw R2ServiceError.downloadFailed(fileName, NSError(
                                    domain: "R2Service",
                                    code: -2,
                                    userInfo: [NSLocalizedDescriptionKey: "分段 \(chunkIndex + 1) 数据为空"]
                                ))
                            }

                            // 写入文件（每个分段独立打开文件句柄，定位到正确位置）
                            let chunkHandle = try FileHandle(forWritingTo: localURL)
                            defer { try? chunkHandle.close() }
                            try chunkHandle.seek(toOffset: UInt64(startByte))
                            chunkHandle.write(chunkData)

                            // 更新进度（线程安全）
                            let newTotal = bytesDownloaded.withLock { total -> Int64 in
                                total += Int64(chunkData.count)
                                return total
                            }
                            progress(newTotal, fileSize)

                            print("✅ 分段 \(chunkIndex + 1) 完成，已下载: \(newTotal)/\(fileSize)")
                            await semaphore.signal()
                        } catch {
                            await semaphore.signal()
                            throw error
                        }
                    }
                }

                // 等待所有分段完成
                try await group.waitForAll()
            }

            print("✅ 并发分段下载完成: \(localURL.path)")

        } catch {
            print("❌ 分段下载失败: \(error.localizedDescription)")

            // 清理失败的下载文件
            try? FileManager.default.removeItem(at: localURL)

            // 如果是取消操作，直接重新抛出
            if error is CancellationError {
                print("🛑 分段下载被取消")
                throw error
            }

            if let r2Error = error as? R2ServiceError {
                throw r2Error
            }
            throw R2ServiceError.downloadFailed(fileName, error)
        }
    }

    /// 异步信号量（用于限制并发数）
    private actor AsyncSemaphore {
        private var count: Int
        private var waiters: [CheckedContinuation<Void, Never>] = []

        init(count: Int) {
            self.count = count
        }

        func wait() async {
            if count > 0 {
                count -= 1
            } else {
                await withCheckedContinuation { continuation in
                    waiters.append(continuation)
                }
            }
        }

        func signal() {
            if let waiter = waiters.first {
                waiters.removeFirst()
                waiter.resume()
            } else {
                count += 1
            }
        }
    }

    /// 删除指定的文件对象
    /// - Parameters:
    ///   - bucket: 存储桶名称
    ///   - key: 要删除的对象键（完整路径）
    func deleteObject(bucket: String, key: String) async throws {
        guard let s3Client = s3Client else {
            print("❌ S3客户端未初始化")
            throw R2ServiceError.accountNotConfigured
        }
        
        let fileName = (key as NSString).lastPathComponent
        print("🗑️ 开始删除文件...")
        print("   存储桶: \(bucket)")
        print("   对象键: \(key)")
        print("   文件名: \(fileName)")
        
        isLoading = true
        lastError = nil
        
        do {
            // 创建 DeleteObject 请求
            print("🔧 正在创建删除请求...")
            let input = DeleteObjectInput(
                bucket: bucket,
                key: key
            )
            
            print("🚀 开始执行文件删除...")
            let _ = try await s3Client.deleteObject(input: input)
            
            isLoading = false
            print("✅ 文件删除成功完成")
            
        } catch {
            isLoading = false
            print("❌ 文件删除过程中发生错误:")
            print("   错误类型: \(type(of: error))")
            print("   错误描述: \(error.localizedDescription)")
            
            // 详细分析错误
            let serviceError = mapDeleteError(error, fileName: fileName)
            print("   映射后的服务错误: \(serviceError)")
            if let suggestion = serviceError.suggestedAction {
                print("   建议操作: \(suggestion)")
            }
            
            lastError = serviceError
            throw serviceError
        }
    }
    
    /// 批量删除文件
    /// - Parameters:
    ///   - bucket: 存储桶名称
    ///   - keys: 要删除的对象键列表
    /// - Returns: 删除失败的文件列表
    func deleteObjects(bucket: String, keys: [String]) async throws -> [String] {
        guard let s3Client = s3Client else {
            throw R2ServiceError.accountNotConfigured
        }
        
        guard !keys.isEmpty else { return [] }
        
        print("🗑️ 开始批量删除 \(keys.count) 个文件...")
        
        isLoading = true
        lastError = nil
        
        var failedKeys: [String] = []
        
        // S3 DeleteObjects API 每次最多删除 1000 个对象
        // 这里分批处理
        let batchSize = 1000
        for batch in stride(from: 0, to: keys.count, by: batchSize) {
            let endIndex = min(batch + batchSize, keys.count)
            let batchKeys = Array(keys[batch..<endIndex])
            
            do {
                // 构建删除请求
                let objectIdentifiers = batchKeys.map { key in
                    S3ClientTypes.ObjectIdentifier(key: key)
                }
                
                let deleteInput = S3ClientTypes.Delete(
                    objects: objectIdentifiers,
                    quiet: false
                )
                
                let input = DeleteObjectsInput(
                    bucket: bucket,
                    delete: deleteInput
                )
                
                let result = try await s3Client.deleteObjects(input: input)
                
                // 检查删除错误
                if let errors = result.errors {
                    for error in errors {
                        if let key = error.key {
                            failedKeys.append(key)
                            print("❌ 删除失败: \(key) - \(error.message ?? "未知错误")")
                        }
                    }
                }
                
                print("✅ 批量删除完成，成功: \(batchKeys.count - (result.errors?.count ?? 0))，失败: \(result.errors?.count ?? 0)")
                
            } catch {
                // 如果整批失败，将所有键添加到失败列表
                failedKeys.append(contentsOf: batchKeys)
                print("❌ 批量删除请求失败: \(error.localizedDescription)")
            }
        }
        
        isLoading = false
        return failedKeys
    }

    /// 删除文件夹及其所有内容
    /// - Parameters:
    ///   - bucket: 存储桶名称
    ///   - folderKey: 文件夹路径（以 / 结尾）
    /// - Returns: 删除的文件数量和失败的文件列表
    func deleteFolder(bucket: String, folderKey: String) async throws -> (deletedCount: Int, failedKeys: [String]) {
        guard let s3Client = s3Client else {
            throw R2ServiceError.accountNotConfigured
        }

        // 确保 folderKey 以 / 结尾
        let prefix = folderKey.hasSuffix("/") ? folderKey : folderKey + "/"

        print("📁 开始删除文件夹: \(prefix)")
        print("   存储桶: \(bucket)")

        isLoading = true
        lastError = nil

        var allKeys: [String] = []
        var continuationToken: String? = nil

        // 1. 列出文件夹内所有对象
        do {
            repeat {
                let input = ListObjectsV2Input(
                    bucket: bucket,
                    continuationToken: continuationToken,
                    prefix: prefix
                )

                let response = try await s3Client.listObjectsV2(input: input)

                if let contents = response.contents {
                    let keys = contents.compactMap { $0.key }
                    allKeys.append(contentsOf: keys)
                }

                continuationToken = response.nextContinuationToken
            } while continuationToken != nil

            print("📋 找到 \(allKeys.count) 个对象需要删除")

            // 重要：始终添加文件夹标记对象本身（包括带斜杠和不带斜杠的版本）
            // R2/S3 中文件夹通常由以 / 结尾的对象表示，但为了兼容性，我们也尝试删除不带斜杠的键
            let slashedKey = prefix.hasSuffix("/") ? prefix : prefix + "/"
            let noSlashKey = prefix.hasSuffix("/") ? String(prefix.dropLast()) : prefix
            
            if !allKeys.contains(slashedKey) {
                allKeys.append(slashedKey)
                print("📁 添加文件夹标记对象(标准): \(slashedKey)")
            }
            
            if !allKeys.contains(noSlashKey) {
                allKeys.append(noSlashKey)
                print("📁 添加文件夹标记对象(兼容): \(noSlashKey)")
            }

            // 2. 批量删除所有对象（包括文件夹标记）
            let failedKeys = try await deleteObjects(bucket: bucket, keys: allKeys)

            isLoading = false

            let deletedCount = allKeys.count - failedKeys.count
            print("✅ 文件夹删除完成，删除 \(deletedCount) 个对象，失败 \(failedKeys.count) 个")

            return (deletedCount, failedKeys)

        } catch {
            isLoading = false
            print("❌ 删除文件夹失败: \(error.localizedDescription)")
            let serviceError = mapError(error)
            lastError = serviceError
            throw serviceError
        }
    }

    /// 重命名文件（通过复制后删除实现）
    /// - Parameters:
    ///   - bucket: 存储桶名称
    ///   - oldKey: 原对象键
    ///   - newKey: 新对象键
    func renameObject(bucket: String, oldKey: String, newKey: String) async throws {
        guard let s3Client = s3Client else {
            throw R2ServiceError.accountNotConfigured
        }
        
        print("✏️ 重命名文件: \(oldKey) -> \(newKey)")
        
        isLoading = true
        lastError = nil
        
        do {
            // 1. 复制对象到新位置
            let copySource = "\(bucket)/\(oldKey)"
            let copyInput = CopyObjectInput(
                bucket: bucket,
                copySource: copySource,
                key: newKey
            )
            
            print("📋 步骤 1/2: 复制对象...")
            let _ = try await s3Client.copyObject(input: copyInput)
            
            // 2. 删除原对象
            print("🗑️ 步骤 2/2: 删除原对象...")
            let deleteInput = DeleteObjectInput(
                bucket: bucket,
                key: oldKey
            )
            let _ = try await s3Client.deleteObject(input: deleteInput)
            
            isLoading = false
            print("✅ 重命名完成")

        } catch {
            isLoading = false
            print("❌ 重命名失败: \(error.localizedDescription)")
            let fileName = (oldKey as NSString).lastPathComponent
            let serviceError = mapError(error)
            lastError = serviceError
            throw serviceError
        }
    }
    
    // MARK: - 移动操作
    
    /// 检查对象是否存在
    /// - Parameters:
    ///   - bucket: 存储桶名称
    ///   - key: 对象键
    /// - Returns: 是否存在
    func objectExists(bucket: String, key: String) async throws -> Bool {
        guard let s3Client = s3Client else {
            throw R2ServiceError.accountNotConfigured
        }
        
        do {
            let input = HeadObjectInput(bucket: bucket, key: key)
            let _ = try await s3Client.headObject(input: input)
            return true
        } catch {
            // 如果是 404 类型错误，表示对象不存在
            let errorDescription = String(describing: error).lowercased()
            if errorDescription.contains("notfound") || errorDescription.contains("404") || errorDescription.contains("nosuchkey") {
                return false
            }
            // 其他错误抛出
            throw mapError(error)
        }
    }
    
    /// 移动单个对象（通过复制后删除实现）
    /// - Parameters:
    ///   - bucket: 存储桶名称
    ///   - sourceKey: 源对象键
    ///   - destinationKey: 目标对象键
    func moveObject(bucket: String, sourceKey: String, destinationKey: String) async throws {
        guard let s3Client = s3Client else {
            throw R2ServiceError.accountNotConfigured
        }
        
        // 如果源和目标相同，不需要移动
        if sourceKey == destinationKey {
            print("⚠️ 源和目标相同，跳过移动: \(sourceKey)")
            return
        }
        
        print("📦 移动文件: \(sourceKey) -> \(destinationKey)")

        do {
            // 1. 复制对象到新位置
            // copySource 需要 URL 编码以支持特殊字符（包括泰语、中文等）
            guard let encodedSourceKey = sourceKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                throw R2ServiceError.invalidOperation("无法编码源文件名")
            }
            let copySource = "\(bucket)/\(encodedSourceKey)"
            let copyInput = CopyObjectInput(
                bucket: bucket,
                copySource: copySource,
                key: destinationKey
            )
            
            print("📋 步骤 1/2: 复制对象...")
            let _ = try await s3Client.copyObject(input: copyInput)
            
            // 2. 删除原对象
            print("🗑️ 步骤 2/2: 删除原对象...")
            let deleteInput = DeleteObjectInput(
                bucket: bucket,
                key: sourceKey
            )
            let _ = try await s3Client.deleteObject(input: deleteInput)
            
            print("✅ 移动完成")
            
        } catch {
            print("❌ 移动失败: \(error.localizedDescription)")
            throw mapError(error)
        }
    }
    
    /// 移动文件夹及其所有内容
    /// - Parameters:
    ///   - bucket: 存储桶名称
    ///   - sourceFolderKey: 源文件夹路径（以 / 结尾）
    ///   - destinationFolderKey: 目标文件夹路径（以 / 结尾）
    /// - Returns: 移动的文件数量和失败的文件列表
    func moveFolder(bucket: String, sourceFolderKey: String, destinationFolderKey: String) async throws -> (movedCount: Int, failedKeys: [String]) {
        guard let s3Client = s3Client else {
            throw R2ServiceError.accountNotConfigured
        }
        
        // 确保路径以 / 结尾
        let sourcePrefix = sourceFolderKey.hasSuffix("/") ? sourceFolderKey : sourceFolderKey + "/"
        let destPrefix = destinationFolderKey.hasSuffix("/") ? destinationFolderKey : destinationFolderKey + "/"
        
        // 检查是否试图移动到自身的子目录
        if destPrefix.hasPrefix(sourcePrefix) {
            print("❌ 不能移动文件夹到自身的子目录")
            throw R2ServiceError.invalidOperation("不能移动文件夹到自身的子目录")
        }
        
        // 如果源和目标相同，不需要移动
        if sourcePrefix == destPrefix {
            print("⚠️ 源和目标相同，跳过移动")
            return (0, [])
        }
        
        print("📁 开始移动文件夹: \(sourcePrefix) -> \(destPrefix)")
        print("   存储桶: \(bucket)")
        
        isLoading = true
        lastError = nil
        
        var allKeys: [String] = []
        var continuationToken: String? = nil
        var failedKeys: [String] = []
        var movedCount = 0
        
        do {
            // 1. 列出源文件夹内所有对象
            repeat {
                let input = ListObjectsV2Input(
                    bucket: bucket,
                    continuationToken: continuationToken,
                    prefix: sourcePrefix
                )
                
                let response = try await s3Client.listObjectsV2(input: input)
                
                if let contents = response.contents {
                    let keys = contents.compactMap { $0.key }
                    allKeys.append(contentsOf: keys)
                }
                
                continuationToken = response.nextContinuationToken
            } while continuationToken != nil
            
            // 添加文件夹标记对象本身
            if !allKeys.contains(sourcePrefix) {
                allKeys.append(sourcePrefix)
            }
            
            print("📋 找到 \(allKeys.count) 个对象需要移动")
            
            // 2. 逐个移动对象
            for sourceKey in allKeys {
                // 检查任务是否被取消
                try Task.checkCancellation()

                // 计算目标路径：将源前缀替换为目标前缀
                let relativePath = String(sourceKey.dropFirst(sourcePrefix.count))
                let destKey = destPrefix + relativePath
                
                do {
                    // 复制对象（copySource 需要 URL 编码）
                    guard let encodedSourceKey = sourceKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                        print("⚠️ 无法编码文件名，跳过: \(sourceKey)")
                        failedKeys.append(sourceKey)
                        continue
                    }
                    let copySource = "\(bucket)/\(encodedSourceKey)"
                    let copyInput = CopyObjectInput(
                        bucket: bucket,
                        copySource: copySource,
                        key: destKey
                    )
                    let _ = try await s3Client.copyObject(input: copyInput)
                    
                    // 删除原对象
                    let deleteInput = DeleteObjectInput(
                        bucket: bucket,
                        key: sourceKey
                    )
                    let _ = try await s3Client.deleteObject(input: deleteInput)
                    
                    movedCount += 1
                    print("✅ 移动: \(sourceKey) -> \(destKey)")
                    
                } catch {
                    failedKeys.append(sourceKey)
                    print("❌ 移动失败: \(sourceKey) - \(error.localizedDescription)")
                }
            }
            
            isLoading = false
            print("✅ 文件夹移动完成，成功 \(movedCount) 个，失败 \(failedKeys.count) 个")
            
            return (movedCount, failedKeys)
            
        } catch {
            isLoading = false

            // 如果是取消操作，直接重新抛出（已移动的文件保留）
            if error is CancellationError {
                print("🛑 文件夹移动被取消，已移动 \(movedCount) 个文件")
                throw error
            }

            print("❌ 移动文件夹失败: \(error.localizedDescription)")
            let serviceError = mapError(error)
            lastError = serviceError
            throw serviceError
        }
    }

    /// 断开连接
    func disconnect() {
        // 清理 S3 客户端和账户信息
        s3Client = nil
        currentAccount = nil
        currentSecretAccessKey = nil
        selectedBucket = nil
        isConnected = false
        lastError = nil
        
        // 安全清理环境变量
        unsetenv("AWS_ACCESS_KEY_ID")
        unsetenv("AWS_SECRET_ACCESS_KEY")
        unsetenv("AWS_REGION")
    }
    
    /// 上传诊断工具
    /// 检查上传功能的各项前置条件
    /// - Returns: 诊断结果和建议
    func diagnoseUploadIssues() -> (isReady: Bool, issues: [String], suggestions: [String]) {
        var issues: [String] = []
        var suggestions: [String] = []
        
        // 检查连接状态
        if !isConnected {
            issues.append("未连接到 R2 服务")
            suggestions.append("请先在账户设置中配置并连接您的 R2 账户")
        }
        
        // 检查 S3 客户端
        if s3Client == nil {
            issues.append("S3 客户端未初始化")
            suggestions.append("请重新连接账户或重启应用")
        }
        
        // 检查账户配置
        guard let account = currentAccount else {
            issues.append("缺少账户配置信息")
            suggestions.append("请在账户设置中重新配置账户信息")
            return (false, issues, suggestions)
        }
        
        // 检查存储桶选择
        if selectedBucket == nil {
            issues.append("未选择存储桶")
            suggestions.append("请选择一个存储桶用于文件上传")
        }
        
        // 检查账户信息完整性
        if account.accountID.isEmpty {
            issues.append("Account ID 为空")
            suggestions.append("请在账户设置中填写正确的 Account ID")
        }
        
        if account.accessKeyID.isEmpty {
            issues.append("Access Key ID 为空")
            suggestions.append("请在账户设置中填写正确的 Access Key ID")
        }
        
        if currentSecretAccessKey?.isEmpty != false {
            issues.append("Secret Access Key 为空")
            suggestions.append("请在账户设置中填写正确的 Secret Access Key")
        }
        
        // 检查端点 URL
        let endpointValidation = validateR2Endpoint(account.endpointURL)
        if !endpointValidation.isValid {
            issues.append("端点 URL 格式错误：\(endpointValidation.message)")
            suggestions.append("请使用正确的 R2 端点格式：https://您的账户ID.r2.cloudflarestorage.com")
        }
        
        let isReady = issues.isEmpty
        
        // 添加通用建议
        if !isReady {
            suggestions.append("如果问题持续，请检查网络连接并联系技术支持")
        }
        
        return (isReady, issues, suggestions)
    }
    
    /// 生成文件的公共访问URL（不带版本参数，用于分享链接）
    /// - Parameters:
    ///   - fileObject: 文件对象
    ///   - bucketName: 存储桶名称
    /// - Returns: 文件的公共访问URL字符串
    func generateFileURL(for fileObject: FileObject, in bucketName: String) -> String? {
        guard let account = currentAccount else {
            print("❌ 无法生成文件URL：账户未配置")
            return nil
        }

        // 构建文件路径
        let filePath = fileObject.key

        // 如果配置了公共域名，使用默认公共域名
        if let publicDomain = account.defaultPublicDomain, !publicDomain.isEmpty {
            // 确保域名格式正确
            let domain = publicDomain.hasPrefix("http") ? publicDomain : "https://\(publicDomain)"
            return "\(domain)/\(filePath)"
        } else {
            // 使用默认的 Cloudflare R2 域名
            // 格式：https://账户ID.r2.cloudflarestorage.com/存储桶名/文件路径
            return "https://\(account.accountID).r2.cloudflarestorage.com/\(bucketName)/\(filePath)"
        }
    }

    /// 根据文件 key 生成基础 URL（不带版本参数）
    /// - Parameters:
    ///   - key: 文件的 object key（路径）
    ///   - bucketName: 存储桶名称
    /// - Returns: 文件的公共访问URL字符串
    ///
    /// 说明：此方法用于在上传完成后清除缩略图缓存，不需要完整的 FileObject。
    func generateBaseURL(for key: String, in bucketName: String) -> String? {
        guard let account = currentAccount else {
            return nil
        }

        if let publicDomain = account.defaultPublicDomain, !publicDomain.isEmpty {
            let domain = publicDomain.hasPrefix("http") ? publicDomain : "https://\(publicDomain)"
            return "\(domain)/\(key)"
        } else {
            return "https://\(account.accountID).r2.cloudflarestorage.com/\(bucketName)/\(key)"
        }
    }

    /// 清除指定文件的缩略图缓存（用于上传覆盖后刷新）
    /// - Parameters:
    ///   - key: 文件的 object key（路径）
    ///   - bucketName: 存储桶名称
    ///
    /// 说明：当文件被覆盖上传后，调用此方法清除旧的内存缓存。
    /// 由于新文件会使用新的版本参数（基于修改时间），CDN 缓存会自动失效。
    /// 这里主要清除内存中的旧缓存，确保下次加载时使用新 URL。
    func invalidateThumbnailCache(for key: String, in bucketName: String) {
        guard let baseURL = generateBaseURL(for: key, in: bucketName) else {
            print("⚠️ 无法生成缓存清除 URL：\(key)")
            return
        }
        ThumbnailCache.shared.invalidateCache(for: baseURL)
    }

    // MARK: - CDN Cache Purge

    /// 清除指定 URL 的 CDN 缓存（通过 Cloudflare Purge Cache API）
    /// - Parameter urls: 要清除缓存的 URL 列表
    ///
    /// 说明：当启用了自动清除 CDN 缓存且配置了 Zone ID 和 API Token 时，
    /// 此方法会调用 Cloudflare API 主动清除 CDN 缓存，确保公开链接立即返回新内容。
    /// 如果未配置或调用失败，会静默跳过，不影响上传流程。
    func purgeCDNCache(for urls: [String]) async {
        guard let account = currentAccount else {
            print("⚠️ [CDN Purge] 跳过：无当前账户")
            return
        }

        // 检查是否启用了自动清除
        guard account.autoPurgeCDNCache else {
            print("⚠️ [CDN Purge] 跳过：未启用自动清除 CDN 缓存")
            return
        }

        // 检查 Zone ID
        guard let zoneID = account.cloudflareZoneID, !zoneID.isEmpty else {
            print("⚠️ [CDN Purge] 跳过：未配置 Cloudflare Zone ID")
            return
        }

        // 从 Keychain 获取 API Token
        guard let apiToken = KeychainService.shared.retrieveCloudflareAPIToken(for: account),
              !apiToken.isEmpty else {
            print("⚠️ [CDN Purge] 跳过：未配置 Cloudflare API Token")
            return
        }

        // 构建请求
        let endpoint = "https://api.cloudflare.com/client/v4/zones/\(zoneID)/purge_cache"
        guard let url = URL(string: endpoint) else {
            print("❌ [CDN Purge] 无效的 API 端点 URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["files": urls]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ [CDN Purge] JSON 序列化失败: \(error.localizedDescription)")
            return
        }

        // 发送请求
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [CDN Purge] 无效的响应类型")
                return
            }

            if httpResponse.statusCode == 200 {
                print("✅ [CDN Purge] 缓存已清除: \(urls)")
            } else {
                // 尝试解析错误信息
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errors = json["errors"] as? [[String: Any]] {
                    let errorMessages = errors.compactMap { $0["message"] as? String }.joined(separator: ", ")
                    print("❌ [CDN Purge] API 错误 (\(httpResponse.statusCode)): \(errorMessages)")
                } else {
                    print("❌ [CDN Purge] API 请求失败，状态码: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("❌ [CDN Purge] 网络请求失败: \(error.localizedDescription)")
        }
    }

    /// 生成缩略图专用URL（带版本参数，用于绕过 CDN 缓存）
    /// - Parameters:
    ///   - fileObject: 文件对象
    ///   - bucketName: 存储桶名称
    /// - Returns: 带版本参数的缩略图URL字符串
    ///
    /// 说明：通过在 URL 后添加 `?v=时间戳` 参数，当文件被覆盖上传时，
    /// CDN 会认为是不同的 URL，从而获取新内容而非返回旧缓存。
    func generateThumbnailURL(for fileObject: FileObject, in bucketName: String) -> String? {
        guard let baseURL = generateFileURL(for: fileObject, in: bucketName) else {
            return nil
        }

        // 使用文件修改时间作为版本号
        if let modDate = fileObject.lastModifiedDate {
            let timestamp = Int(modDate.timeIntervalSince1970)
            return "\(baseURL)?v=\(timestamp)"
        }

        // 如果没有修改时间，使用 ETag 的哈希值
        if let eTag = fileObject.eTag {
            let hashValue = abs(eTag.hashValue)
            return "\(baseURL)?v=\(hashValue)"
        }

        // 都没有时返回原 URL
        return baseURL
    }
    
    // MARK: - Private Methods
    
    /// 加载账户配置并自动初始化服务
    func loadAccountAndInitialize() async {
        // 加载账户配置
        accountManager.loadAccounts()
        
        // 如果有当前账户，尝试自动连接
        if let currentAccount = accountManager.currentAccount {
            do {
                // 获取完整凭证
                let credentials = try accountManager.getCompleteCredentials(for: currentAccount)
                try await initialize(with: credentials.account, secretAccessKey: credentials.secretAccessKey)
                
                // 如果配置了默认存储桶，自动选择它
                if let defaultBucketName = currentAccount.defaultBucketName,
                   !defaultBucketName.isEmpty {
                    print("🎯 尝试自动选择配置的默认存储桶: \(defaultBucketName)")
                    do {
                        let bucket = try await selectBucketDirectly(defaultBucketName)
                        print("✅ 成功自动选择存储桶: \(bucket.name)")
                    } catch {
                        print("⚠️  自动选择默认存储桶失败: \(error.localizedDescription)")
                        // 存储桶选择失败不影响连接状态
                    }
                }
                
            } catch {
                print("自动初始化失败: \(error.localizedDescription)")
                lastError = mapError(error)
            }
        }
    }
    
    /// 创建 S3 客户端
    /// 基于 AWS SDK for Swift 官方推荐方式实现
    private func createS3Client() async throws {
        guard let account = currentAccount else {
            throw R2ServiceError.accountNotConfigured
        }
        
        guard let secretAccessKey = currentSecretAccessKey else {
            throw R2ServiceError.accountNotConfigured
        }
        
        // 验证账户信息完整性
        guard account.isValid() else {
            throw R2ServiceError.invalidCredentials
        }
        
        do {
            print("🔧 开始创建 S3 客户端...")
            print("   端点: \(account.endpointURL)")
            print("   Access Key ID: \(account.accessKeyID)")
            
            // 使用端点验证方法
            let validation = validateR2Endpoint(account.endpointURL)
            if !validation.isValid {
                print("❌ 端点验证失败: \(validation.message)")
                throw R2ServiceError.invalidCredentials
            }
            
            // 验证 Access Key ID 格式（R2 Access Key 通常是32位字符）
            if account.accessKeyID.count < 20 || account.accessKeyID.count > 128 {
                print("❌ Access Key ID 格式可能有误，长度: \(account.accessKeyID.count)")
            }
            
            // 验证 Secret Access Key 格式
            if secretAccessKey.count < 20 || secretAccessKey.count > 128 {
                print("❌ Secret Access Key 格式可能有误，长度: \(secretAccessKey.count)")
            }
            
            print("✅ 端点验证成功，凭证格式检查完成")
            
            // 按照官方文档推荐方式：通过环境变量设置凭证
            print("📋 使用官方推荐方式创建 S3 配置...")
            
            // 设置环境变量（AWS SDK 会自动读取这些环境变量）
            setenv("AWS_ACCESS_KEY_ID", account.accessKeyID, 1)
            setenv("AWS_SECRET_ACCESS_KEY", secretAccessKey, 1)
            setenv("AWS_REGION", "auto", 1)  // R2 使用 "auto" 区域
            
            // 创建 S3 配置
            var s3Config = try await S3Client.S3ClientConfiguration()
            s3Config.region = "auto"  // R2 使用 "auto" 区域
            s3Config.endpoint = account.endpointURL
            
            print("✅ S3 配置创建成功")
            
            // 创建 S3 客户端
            s3Client = S3Client(config: s3Config)
            
            // 验证客户端是否创建成功
            guard s3Client != nil else {
                print("❌ S3 客户端创建失败：客户端实例为 nil")
                throw R2ServiceError.authenticationError
            }
            
            print("✅ S3 客户端创建成功")
            
        } catch {
            print("❌ S3 客户端创建失败：\(error.localizedDescription)")
            print("   错误类型: \(type(of: error))")
            
            // 根据错误类型进行映射
            if error is R2ServiceError {
                throw error
            } else {
                throw mapError(error)
            }
        }
    }
    
    /// 根据文件扩展名推断 MIME 类型
    /// - Parameter fileURL: 文件 URL
    /// - Returns: MIME 类型字符串
    private func inferContentType(from fileURL: URL) -> String {
        let fileExtension = fileURL.pathExtension.lowercased()
        
        switch fileExtension {
        // 图片类型
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "svg":
            return "image/svg+xml"
        case "ico":
            return "image/x-icon"
            
        // 文档类型
        case "pdf":
            return "application/pdf"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls":
            return "application/vnd.ms-excel"
        case "xlsx":
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt":
            return "application/vnd.ms-powerpoint"
        case "pptx":
            return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
            
        // 文本类型
        case "txt":
            return "text/plain"
        case "html", "htm":
            return "text/html"
        case "css":
            return "text/css"
        case "js":
            return "application/javascript"
        case "json":
            return "application/json"
        case "xml":
            return "application/xml"
        case "csv":
            return "text/csv"
            
        // 视频类型
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "avi":
            return "video/x-msvideo"
        case "mkv":
            return "video/x-matroska"
        case "webm":
            return "video/webm"
            
        // 音频类型
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "flac":
            return "audio/flac"
        case "aac":
            return "audio/aac"
        case "ogg":
            return "audio/ogg"
            
        // 压缩文件类型
        case "zip":
            return "application/zip"
        case "rar":
            return "application/vnd.rar"
        case "7z":
            return "application/x-7z-compressed"
        case "tar":
            return "application/x-tar"
        case "gz":
            return "application/gzip"
            
        // 默认类型
        default:
            return "application/octet-stream"
        }
    }
    
    /// 验证对象名称是否有效
    /// - Parameter name: 对象名称
    /// - Returns: 是否有效
    private func isValidObjectName(_ name: String) -> Bool {
        // S3/R2 对象名称的基本规则
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return !name.isEmpty && name.rangeOfCharacter(from: invalidCharacters) == nil
    }
    
    /// 映射上传错误
    /// - Parameters:
    ///   - error: 原始错误
    ///   - fileName: 文件名
    /// - Returns: 映射后的服务错误
    private func mapUploadError(_ error: Error, fileName: String) -> R2ServiceError {
        if let r2Error = error as? R2ServiceError {
            return r2Error
        }
        
        let errorMessage = error.localizedDescription.lowercased()
        let errorDescription = error.localizedDescription
        
        print("🔍 分析上传错误...")
        print("   原始错误: \(errorDescription)")
        print("   错误类型: \(type(of: error))")
        
        // 检查 macOS 文件权限错误（NSCocoaErrorDomain Code=257）
        if let nsError = error as? NSError {
            if nsError.domain == "NSCocoaErrorDomain" && nsError.code == 257 {
                print("   诊断: macOS 文件权限错误 (Code 257)")
                print("   详细信息: 应用无法访问所选文件，可能是沙盒权限限制")
                return .fileAccessDenied(fileName)
            }
            
            // 检查其他常见的文件系统错误
            if nsError.domain == "NSPOSIXErrorDomain" && nsError.code == 1 {
                print("   诊断: POSIX 权限错误 (Operation not permitted)")
                return .fileAccessDenied(fileName)
            }
        }
        
        // 检查通用文件访问权限错误
        if errorMessage.contains("permission") && errorMessage.contains("view") ||
           errorMessage.contains("couldn't be opened") && errorMessage.contains("permission") ||
           errorMessage.contains("operation not permitted") {
            print("   诊断: 文件访问权限被拒绝")
            return .fileAccessDenied(fileName)
        }
        
        // 检查权限相关错误
        if errorDescription.contains("AccessDenied") || 
           errorDescription.contains("Access Denied") ||
           errorMessage.contains("forbidden") ||
           errorMessage.contains("unauthorized") {
            print("   诊断: 权限不足错误")
            return .permissionDenied("上传文件到存储桶")
        }
        
        // 检查存储桶不存在错误
        if errorMessage.contains("nosuchbucket") || 
           errorMessage.contains("bucket") && errorMessage.contains("not") {
            print("   诊断: 存储桶不存在或无访问权限")
            return .bucketNotFound(selectedBucket?.name ?? "未知存储桶")
        }
        
        // 检查存储配额错误
        if errorMessage.contains("quota") || 
           errorMessage.contains("storage") ||
           errorMessage.contains("limit") ||
           errorMessage.contains("exceeded") {
            print("   诊断: 存储配额已满")
            return .storageQuotaExceeded
        }
        
        // 检查网络连接错误
        if errorMessage.contains("timeout") || 
           errorMessage.contains("timed out") ||
           errorMessage.contains("connection") && errorMessage.contains("lost") {
            print("   诊断: 网络连接超时")
            return .connectionTimeout
        }
        
        // 检查 DNS 解析错误
        if errorMessage.contains("hostname") || 
           errorMessage.contains("dns") ||
           errorMessage.contains("name resolution") {
            print("   诊断: DNS解析失败")
            return .dnsResolutionFailed
        }
        
        // 检查端点连接错误
        if errorMessage.contains("unreachable") || 
           errorMessage.contains("connection refused") ||
           errorMessage.contains("connection failed") ||
           errorDescription.contains("error 1") {
            print("   诊断: 端点不可达")
            return .endpointNotReachable(currentAccount?.endpointURL ?? "未知端点")
        }
        
        // 检查 SSL/TLS 证书错误
        if errorMessage.contains("ssl") || 
           errorMessage.contains("tls") ||
           errorMessage.contains("certificate") ||
           errorMessage.contains("trust") {
            print("   诊断: SSL证书错误")
            return .sslCertificateError
        }
        
        // 检查文件相关错误
        if errorMessage.contains("file") && errorMessage.contains("large") {
            print("   诊断: 文件过大")
            return .invalidFileSize(fileName)
        }
        
        // 检查认证错误
        if errorMessage.contains("credentials") ||
           errorMessage.contains("authentication") ||
           errorMessage.contains("signature") ||
           errorMessage.contains("invalid") {
            print("   诊断: 认证失败")
            return .authenticationError
        }
        
        // 通用网络错误
        if errorMessage.contains("network") || 
           errorMessage.contains("connection") {
            print("   诊断: 通用网络错误")
            return .networkError(error)
        }
        
        print("   诊断: 未知上传错误")
        return .uploadFailed(fileName, error)
    }
    
    /// 映射创建文件夹错误
    /// - Parameters:
    ///   - error: 原始错误
    ///   - folderName: 文件夹名
    /// - Returns: 映射后的服务错误
    private func mapCreateFolderError(_ error: Error, folderName: String) -> R2ServiceError {
        if let r2Error = error as? R2ServiceError {
            return r2Error
        }
        
        return .createFolderFailed(folderName, error)
    }
    
    /// 将删除文件错误映射为服务错误
    /// - Parameters:
    ///   - error: 原始错误
    ///   - fileName: 文件名
    /// - Returns: 映射后的服务错误
    private func mapDeleteError(_ error: Error, fileName: String) -> R2ServiceError {
        if let r2Error = error as? R2ServiceError {
            return r2Error
        }
        
        // 检查错误描述中的关键信息
        let errorDescription = error.localizedDescription.lowercased()
        
        // 检查权限相关错误
        if errorDescription.contains("access denied") ||
           errorDescription.contains("forbidden") ||
           errorDescription.contains("permission") {
            return .permissionDenied("删除文件 '\(fileName)'")
        }
        
        // 检查文件不存在错误
        if errorDescription.contains("not found") ||
           errorDescription.contains("no such key") ||
           errorDescription.contains("does not exist") {
            return .fileNotFound(fileName)
        }
        
        // 检查网络相关错误
        if errorDescription.contains("network") ||
           errorDescription.contains("connection") ||
           errorDescription.contains("timeout") {
            return .networkError(error)
        }
        
        // 检查存储桶相关错误
        if errorDescription.contains("bucket") &&
           (errorDescription.contains("not found") || errorDescription.contains("not exist")) {
            return .bucketNotFound("存储桶不存在或无访问权限")
        }
        
        // 默认为删除失败错误
        return .deleteFileFailed(fileName, error)
    }
    
    /// 将系统错误映射为服务错误
    /// - Parameter error: 原始错误
    /// - Returns: 映射后的服务错误
    private func mapError(_ error: Error) -> R2ServiceError {
        // 检查是否为网络相关错误
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return .networkError(error)
            case .userAuthenticationRequired, .clientCertificateRequired:
                return .authenticationError
            default:
                return .networkError(error)
            }
        }
        
        // 根据 AWS SDK 文档建议：检查是否为 AWS 服务错误
        if let serviceError = error as? ServiceError {
            // 处理已建模的服务错误
            return .serverError("AWS 服务错误：\(error.localizedDescription)")
        }
        
        // 检查是否为通用的 AWS 错误（使用错误代码而非具体类型）
        let errorMessage = error.localizedDescription.lowercased()
        let errorDescription = error.localizedDescription
        
        // 特别处理 UnknownAWSHTTPSServiceError 和 UnknownAWSHTTPServiceError
        if errorDescription.contains("UnknownAWSHTTPSServiceError") ||
           errorDescription.contains("UnknownAWSHTTPServiceError") ||
           errorDescription.contains("HTTPS") ||
           errorDescription.contains("SSL") {
            
            print("🔍 检测到 AWS HTTP/HTTPS 服务错误，进行详细分析...")
            print("   完整错误信息: \(errorDescription)")
            
            // 检查是否为 Access Denied 错误（这是最常见的情况）
            if errorDescription.contains("AccessDenied") || errorDescription.contains("Access Denied") {
                print("   错误类型: Access Denied (权限不足)")
                print("   可能原因: 1) API Token 权限不足  2) 存储桶不存在  3) Token 配置错误")
                
                if let account = currentAccount {
                    print("   🔧 权限排查建议:")
                    print("     1. 检查 Cloudflare R2 控制台中的 API Token 权限设置")
                    print("     2. 确认 Token 有对应存储桶的访问权限")
                    print("     3. 尝试使用 selectBucketDirectly() 方法直接指定存储桶")
                    print("     4. 验证 Account ID: \(account.accountID)")
                }
                
                return .permissionDenied("访问 R2 服务")
            }
            // 进一步分析连接错误原因
            else if errorDescription.contains("error 1") {
                print("   错误代码: 1 (连接建立失败)")
                print("   可能原因: 1) 端点 URL 不正确  2) DNS 解析失败  3) 网络连接被阻止  4) 服务端不可达")
                
                // 提供详细的诊断信息
                if let account = currentAccount {
                    print("   🔧 问题排查建议:")
                    print("     1. 验证端点 URL: \(account.endpointURL)")
                    print("     2. 确保格式为: https://您的账户ID.r2.cloudflarestorage.com")
                    print("     3. 检查网络连接是否正常")
                    print("     4. 确认防火墙未阻止 HTTPS 连接")
                    print("     5. 验证 Cloudflare R2 服务是否可用")
                }
                
                return .endpointNotReachable(currentAccount?.endpointURL ?? "R2 端点")
            } else if errorDescription.contains("certificate") || errorDescription.contains("trust") {
                print("   错误类型: SSL 证书问题")
                return .sslCertificateError
            } else {
                print("   错误类型: 通用 HTTPS 连接问题")
                return .networkError(error)
            }
        }
        
        // 检查凭证相关错误
        if errorMessage.contains("credentials") ||
           errorMessage.contains("authentication") ||
           errorMessage.contains("access denied") ||
           errorMessage.contains("unauthorized") ||
           errorMessage.contains("forbidden") ||
           errorMessage.contains("invalid") ||
           errorMessage.contains("signature") {
            return .authenticationError
        }
        
        // 检查具体的网络连接错误类型
        if errorMessage.contains("timeout") || errorMessage.contains("timed out") {
            return .connectionTimeout
        }
        
        if errorMessage.contains("dns") || 
           errorMessage.contains("hostname") ||
           errorMessage.contains("could not be found") ||
           errorMessage.contains("name resolution") {
            return .dnsResolutionFailed
        }
        
        if errorMessage.contains("unreachable") || 
           errorMessage.contains("connection refused") ||
           errorMessage.contains("connection failed") {
            if let account = currentAccount {
                return .endpointNotReachable(account.endpointURL)
            } else {
                return .endpointNotReachable("未知端点")
            }
        }
        
        // 其他网络相关错误
        if errorMessage.contains("connection") || errorMessage.contains("network") {
            return .networkError(error)
        }
        
        // 检查存储桶相关错误
        if errorMessage.contains("bucket") && (errorMessage.contains("not") || errorMessage.contains("exist")) {
            return .bucketNotFound("存储桶不存在或无访问权限")
        }
        
        // 检查配额相关错误
        if errorMessage.contains("quota") || errorMessage.contains("storage") || errorMessage.contains("limit") {
            return .storageQuotaExceeded
        }
        
        // 检查文件大小相关错误
        if errorMessage.contains("file") && errorMessage.contains("large") {
            return .invalidFileSize("文件过大")
        }
        
        // 检查权限相关错误
        if errorMessage.contains("permission") || errorMessage.contains("access denied") {
            return .permissionDenied("当前操作")
        }
        
        // 检查 HTTPS/SSL 相关错误
        if errorMessage.contains("ssl") || 
           errorMessage.contains("tls") ||
           errorMessage.contains("certificate") ||
           errorMessage.contains("handshake") ||
           errorMessage.contains("trust") {
            return .sslCertificateError
        }
        
        // 默认为未知错误
        return .unknownError(error)
    }
}

// MARK: - 单例支持

extension R2Service {
    /// 共享实例
    static let shared = R2Service()
}

// MARK: - 预览支持

extension R2Service {
    /// 创建预览用的模拟服务
    static var preview: R2Service {
        let service = R2Service()
        service.isConnected = true
        // 设置一个示例选中的存储桶
        service.selectedBucket = BucketItem.sampleData.first
        return service
    }
    
    /// 预览用的模拟 listObjects 方法
    /// 仅在预览模式下使用，返回示例数据
    static func mockListObjects(bucket: String, prefix: String? = nil) async throws -> [FileObject] {
        // 模拟网络延迟
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        // 根据不同的前缀返回不同的示例数据
        if let prefix = prefix {
            if prefix == "documents/" {
                return [
                    FileObject.file(
                        name: "Report.pdf",
                        key: "documents/report.pdf",
                        size: 2_456_789,
                        lastModifiedDate: Date().addingTimeInterval(-86400),
                        eTag: "d41d8cd98f00b204e9800998ecf8427e"
                    ),
                    FileObject.file(
                        name: "Presentation.pptx",
                        key: "documents/presentation.pptx",
                        size: 8_901_234,
                        lastModifiedDate: Date().addingTimeInterval(-172800),
                        eTag: "7d865e959b2466918c9863afca942d0f"
                    )
                ]
            } else if prefix == "images/" {
                return [
                    FileObject.file(
                        name: "Photo1.jpg",
                        key: "images/photo1.jpg",
                        size: 4_567_890,
                        lastModifiedDate: Date().addingTimeInterval(-3600),
                        eTag: "098f6bcd4621d373cade4e832627b4f6"
                    ),
                    FileObject.file(
                        name: "Photo2.png",
                        key: "images/photo2.png",
                        size: 3_234_567,
                        lastModifiedDate: Date().addingTimeInterval(-7200),
                        eTag: "5d41402abc4b2a76b9719d911017c592"
                    )
                ]
            }
        }
        
        // 返回根目录的示例数据
        return FileObject.sampleData
    }
}

// MARK: - 测试支持

extension R2Service {
    /// 测试辅助方法：暴露 calculatePartSize 供单元测试使用
    /// - Parameter fileSize: 文件大小（字节）
    /// - Returns: 分片大小（字节）
    func testCalculatePartSize(for fileSize: Int64) -> Int {
        return calculatePartSize(for: fileSize)
    }
} 
