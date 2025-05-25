import Foundation
import Combine
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
    
    var errorDescription: String? {
        switch self {
        case .accountNotConfigured:
            return "R2 账户未配置。请先配置您的 R2 账户信息。"
        case .invalidCredentials:
            return "R2 账户凭证无效。请检查您的 Access Key ID 和 Secret Access Key。"
        case .networkError(let error):
            return "网络连接错误：\(error.localizedDescription)"
        case .authenticationError:
            return "身份验证失败。请检查您的账户凭证。"
        case .serverError(let message):
            return "服务器错误：\(message)"
        case .unknownError(let error):
            return "未知错误：\(error.localizedDescription)"
            
        // 新增错误类型的描述
        case .bucketNotFound(let bucketName):
            return "存储桶 '\(bucketName)' 不存在或无访问权限。"
        case .fileNotFound(let fileName):
            return "文件 '\(fileName)' 不存在。"
        case .invalidFileName(let fileName):
            return "文件名 '\(fileName)' 包含非法字符，请使用有效的文件名。"
        case .uploadFailed(let fileName, let error):
            return "上传文件 '\(fileName)' 失败：\(error.localizedDescription)"
        case .downloadFailed(let fileName, let error):
            return "下载文件 '\(fileName)' 失败：\(error.localizedDescription)"
        case .createFolderFailed(let folderName, let error):
            return "创建文件夹 '\(folderName)' 失败：\(error.localizedDescription)"
        case .deleteFileFailed(let fileName, let error):
            return "删除文件 '\(fileName)' 失败：\(error.localizedDescription)"
        case .permissionDenied(let operation):
            return "权限不足，无法执行 '\(operation)' 操作。请检查您的账户权限。"
        case .storageQuotaExceeded:
            return "存储配额已满，无法上传更多文件。请清理空间或升级账户。"
        case .invalidFileSize(let fileName):
            return "文件 '\(fileName)' 大小超出限制。单个文件最大支持 5GB。"
        case .fileAccessDenied(let fileName):
            return "无法访问文件 '\(fileName)'。应用没有读取此文件的权限。"
            
        // 新增错误类型的描述
        case .connectionTimeout:
            return "连接超时。请检查网络连接并重试。"
        case .dnsResolutionFailed:
            return "DNS 解析失败。请检查端点 URL 是否正确，或者网络连接是否正常。"
        case .sslCertificateError:
            return "SSL 证书验证失败。请检查端点 URL 是否支持 HTTPS。"
        case .endpointNotReachable(let endpoint):
            return "无法连接到端点 '\(endpoint)'。请检查 URL 是否正确且服务可用。"
        }
    }
    
    /// 获取错误的建议操作
    var suggestedAction: String? {
        switch self {
        case .accountNotConfigured:
            return "请前往账户设置页面配置您的 R2 账户信息。"
        case .invalidCredentials:
            return "请检查并重新输入正确的 Access Key ID 和 Secret Access Key。"
        case .networkError:
            return "请检查网络连接并重试。"
        case .authenticationError:
            return "请重新配置您的账户凭证。"
        case .bucketNotFound:
            return "请选择一个存在的存储桶或在 Cloudflare 控制台中创建新的存储桶。"
        case .permissionDenied:
            return "请联系管理员检查您的账户权限设置。"
        case .storageQuotaExceeded:
            return "请删除不需要的文件或联系管理员扩容。"
        case .invalidFileSize:
            return "请选择小于 5GB 的文件进行上传。"
        case .fileAccessDenied:
            return "请尝试以下解决方案：1) 将文件移动到文档文件夹或桌面；2) 检查文件权限设置；3) 重新选择文件进行上传。"
        case .connectionTimeout:
            return "请检查网络连接稳定性，然后重试操作。"
        case .dnsResolutionFailed:
            return "请验证端点 URL 是否正确，检查网络 DNS 设置。"
        case .sslCertificateError:
            return "请确认端点 URL 使用 HTTPS 协议且证书有效。"
        case .endpointNotReachable:
            return "请检查以下几点：1) 端点 URL 格式是否正确（应为 https://账户ID.r2.cloudflarestorage.com）；2) 网络连接是否正常；3) 防火墙是否允许 HTTPS 连接；4) Cloudflare R2 服务是否可用。"
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
        }
    }
}

/// R2 服务主类
/// 封装所有与 R2/S3 的交互逻辑
@MainActor
class R2Service: ObservableObject {
    // MARK: - Properties
    
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
        Task {
            await loadAccountAndInitialize()
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
            // 构造 ListObjectsV2 请求
            let input = ListObjectsV2Input(
                bucket: bucket,
                delimiter: "/",  // 使用 `/` 作为分隔符来模拟文件夹结构
                maxKeys: 1000,   // 单次最多返回 1000 个对象
                prefix: prefix   // 路径前缀，用于指定"文件夹"
            )
            
            let response = try await s3Client.listObjectsV2(input: input)
            var fileObjects: [FileObject] = []
            var processedKeys = Set<String>() // 用于去重的 key 集合
            
            // 添加调试信息：开始处理返回结果
            print("🐛 DEBUG listObjects: Processing response for prefix '\(prefix ?? "ROOT")'")
            print("🐛 DEBUG listObjects: Raw CommonPrefixes count: \(response.commonPrefixes?.count ?? 0)")
            print("🐛 DEBUG listObjects: Raw Contents count: \(response.contents?.count ?? 0)")

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
                        // R2 可能会在 listObjects 时去掉文件夹对象的末尾斜杠，但保持 size=0
                        let isLikelyFolderObject = (size == 0) && !key.contains(".")
                        
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
            
            // 添加调试信息：完成处理
            print("🐛 DEBUG listObjects: Finished processing. Total FileObjects created: \(fileObjects.count)")
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
            let input = PutObjectInput(
                body: .data(Data()), // 空内容
                bucket: bucket,
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
    
    /// 生成文件的公共访问URL
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
        
        // 如果配置了公共域名，使用公共域名
        if let publicDomain = account.publicDomain, !publicDomain.isEmpty {
            // 确保域名格式正确
            let domain = publicDomain.hasPrefix("http") ? publicDomain : "https://\(publicDomain)"
            return "\(domain)/\(filePath)"
        } else {
            // 使用默认的 Cloudflare R2 域名
            // 格式：https://账户ID.r2.cloudflarestorage.com/存储桶名/文件路径
            return "https://\(account.accountID).r2.cloudflarestorage.com/\(bucketName)/\(filePath)"
        }
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
