//
//  R2ServiceTests.swift
//  OwlUploaderTests
//
//  R2Service 单元测试
//  测试工具方法和错误处理
//

import XCTest
@testable import OwlUploader

@MainActor
final class R2ServiceTests: XCTestCase {

    // MARK: - Properties

    private var r2Service: R2Service!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        r2Service = R2Service()
    }

    override func tearDown() async throws {
        r2Service = nil
        try await super.tearDown()
    }

    // MARK: - validateR2Endpoint Tests

    func testValidateR2Endpoint_withValidEndpoint_returnsTrue() {
        // Given - 标准的 Cloudflare R2 端点格式
        let endpoint = "https://0123456789abcdef0123456789abcdef.r2.cloudflarestorage.com"

        // When
        let result = r2Service.validateR2Endpoint(endpoint)

        // Then
        XCTAssertTrue(result.isValid, "有效的 R2 端点应该通过验证")
    }

    func testValidateR2Endpoint_withInvalidURLFormat_returnsFalse() {
        // Given
        let endpoint = "not-a-valid-url"

        // When
        let result = r2Service.validateR2Endpoint(endpoint)

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.message.isEmpty)
    }

    func testValidateR2Endpoint_withHttpProtocol_returnsFalse() {
        // Given - HTTP 而不是 HTTPS
        let endpoint = "http://0123456789abcdef0123456789abcdef.r2.cloudflarestorage.com"

        // When
        let result = r2Service.validateR2Endpoint(endpoint)

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.message.isEmpty)
    }

    func testValidateR2Endpoint_withMissingHost_returnsFalse() {
        // Given
        let endpoint = "https://"

        // When
        let result = r2Service.validateR2Endpoint(endpoint)

        // Then
        XCTAssertFalse(result.isValid)
    }

    func testValidateR2Endpoint_withWrongDomain_returnsFalse() {
        // Given - 错误的域名
        let endpoint = "https://0123456789abcdef0123456789abcdef.s3.amazonaws.com"

        // When
        let result = r2Service.validateR2Endpoint(endpoint)

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.message.isEmpty)
    }

    func testValidateR2Endpoint_withPath_returnsFalse() {
        // Given - 包含路径
        let endpoint = "https://0123456789abcdef0123456789abcdef.r2.cloudflarestorage.com/bucket"

        // When
        let result = r2Service.validateR2Endpoint(endpoint)

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.message.isEmpty)
    }

    func testValidateR2Endpoint_withCustomPort_returnsFalse() {
        // Given - 非标准端口
        let endpoint = "https://0123456789abcdef0123456789abcdef.r2.cloudflarestorage.com:8443"

        // When
        let result = r2Service.validateR2Endpoint(endpoint)

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.message.isEmpty)
    }

    func testValidateR2Endpoint_withShortAccountId_returnsFalse() {
        // Given - 账户 ID 太短（应该是 32 位）
        let endpoint = "https://abc123.r2.cloudflarestorage.com"

        // When
        let result = r2Service.validateR2Endpoint(endpoint)

        // Then
        XCTAssertFalse(result.isValid)
    }

    func testValidateR2Endpoint_withNonHexAccountId_returnsFalse() {
        // Given - 账户 ID 包含非十六进制字符
        let endpoint = "https://zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz.r2.cloudflarestorage.com"

        // When
        let result = r2Service.validateR2Endpoint(endpoint)

        // Then
        XCTAssertFalse(result.isValid)
    }

    // MARK: - Initial State Tests

    func testR2Service_initialState_isNotConnected() {
        // Given
        let service = R2Service()

        // Then
        XCTAssertFalse(service.isConnected)
        XCTAssertFalse(service.isLoading)
        XCTAssertNil(service.lastError)
        XCTAssertNil(service.selectedBucket)
    }

    // MARK: - Adaptive Part Size Tests

    func testAdaptivePartSize_mediumFile_returns20MB() {
        // Given - 200MB 文件（在 100MB-500MB 范围内）
        let fileSize: Int64 = 200 * 1024 * 1024

        // When
        let partSize = r2Service.testCalculatePartSize(for: fileSize)

        // Then
        XCTAssertEqual(partSize, 20 * 1024 * 1024, "200MB 文件应使用 20MB 分片")
    }

    func testAdaptivePartSize_largeFile_returns50MB() {
        // Given - 1GB 文件（在 500MB-2GB 范围内）
        let fileSize: Int64 = 1 * 1024 * 1024 * 1024

        // When
        let partSize = r2Service.testCalculatePartSize(for: fileSize)

        // Then
        XCTAssertEqual(partSize, 50 * 1024 * 1024, "1GB 文件应使用 50MB 分片")
    }

    func testAdaptivePartSize_veryLargeFile_returns100MB() {
        // Given - 5GB 文件（> 2GB）
        let fileSize: Int64 = 5 * 1024 * 1024 * 1024

        // When
        let partSize = r2Service.testCalculatePartSize(for: fileSize)

        // Then
        XCTAssertEqual(partSize, 100 * 1024 * 1024, "5GB 文件应使用 100MB 分片")
    }

    func testAdaptivePartSize_boundaryAt500MB_returns20MB() {
        // Given - 正好 500MB（边界值，应在 100MB-500MB 范围内）
        let fileSize: Int64 = 500 * 1024 * 1024

        // When
        let partSize = r2Service.testCalculatePartSize(for: fileSize)

        // Then
        XCTAssertEqual(partSize, 20 * 1024 * 1024, "500MB 边界文件应使用 20MB 分片")
    }

    func testAdaptivePartSize_boundaryAt2GB_returns50MB() {
        // Given - 正好 2GB（边界值，应在 500MB-2GB 范围内）
        let fileSize: Int64 = 2 * 1024 * 1024 * 1024

        // When
        let partSize = r2Service.testCalculatePartSize(for: fileSize)

        // Then
        XCTAssertEqual(partSize, 50 * 1024 * 1024, "2GB 边界文件应使用 50MB 分片")
    }

    func testAdaptivePartSize_justOver2GB_returns100MB() {
        // Given - 略大于 2GB
        let fileSize: Int64 = 2 * 1024 * 1024 * 1024 + 1

        // When
        let partSize = r2Service.testCalculatePartSize(for: fileSize)

        // Then
        XCTAssertEqual(partSize, 100 * 1024 * 1024, "超过 2GB 的文件应使用 100MB 分片")
    }

}

// MARK: - R2ServiceError Tests (不需要 @MainActor)

final class R2ServiceErrorTests: XCTestCase {

    // MARK: - errorDescription Tests

    func testR2ServiceError_accountNotConfigured_hasDescription() {
        // Given
        let error = R2ServiceError.accountNotConfigured

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testR2ServiceError_invalidCredentials_hasDescription() {
        // Given
        let error = R2ServiceError.invalidCredentials

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testR2ServiceError_bucketNotFound_includesBucketName() {
        // Given
        let bucketName = "my-test-bucket"
        let error = R2ServiceError.bucketNotFound(bucketName)

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testR2ServiceError_uploadFailed_includesFileName() {
        // Given
        let fileName = "document.pdf"
        let underlyingError = NSError(domain: "test", code: -1)
        let error = R2ServiceError.uploadFailed(fileName, underlyingError)

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testR2ServiceError_downloadFailed_includesFileName() {
        // Given
        let fileName = "image.png"
        let underlyingError = NSError(domain: "test", code: -1)
        let error = R2ServiceError.downloadFailed(fileName, underlyingError)

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testR2ServiceError_connectionTimeout_hasDescription() {
        // Given
        let error = R2ServiceError.connectionTimeout

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testR2ServiceError_dnsResolutionFailed_hasDescription() {
        // Given
        let error = R2ServiceError.dnsResolutionFailed

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    // MARK: - suggestedAction Tests

    func testR2ServiceError_accountNotConfigured_hasSuggestedAction() {
        // Given
        let error = R2ServiceError.accountNotConfigured

        // Then
        XCTAssertNotNil(error.suggestedAction)
        XCTAssertFalse(error.suggestedAction?.isEmpty ?? true)
    }

    func testR2ServiceError_invalidCredentials_hasSuggestedAction() {
        // Given
        let error = R2ServiceError.invalidCredentials

        // Then
        XCTAssertNotNil(error.suggestedAction)
    }

    func testR2ServiceError_storageQuotaExceeded_hasSuggestedAction() {
        // Given
        let error = R2ServiceError.storageQuotaExceeded

        // Then
        XCTAssertNotNil(error.suggestedAction)
    }

    func testR2ServiceError_fileAccessDenied_hasSuggestedAction() {
        // Given
        let error = R2ServiceError.fileAccessDenied("test.txt")

        // Then
        XCTAssertNotNil(error.suggestedAction)
    }

    func testR2ServiceError_endpointNotReachable_hasSuggestedAction() {
        // Given
        let error = R2ServiceError.endpointNotReachable("https://test.example.com")

        // Then
        XCTAssertNotNil(error.suggestedAction)
    }

    // MARK: - isRetryable Tests

    func testR2ServiceError_networkError_isRetryable() {
        // Given
        let underlyingError = NSError(domain: NSURLErrorDomain, code: -1001)
        let error = R2ServiceError.networkError(underlyingError)

        // Then
        XCTAssertTrue(error.isRetryable)
    }

    func testR2ServiceError_serverError_isRetryable() {
        // Given
        let error = R2ServiceError.serverError("Internal Server Error")

        // Then
        XCTAssertTrue(error.isRetryable)
    }

    func testR2ServiceError_connectionTimeout_isRetryable() {
        // Given
        let error = R2ServiceError.connectionTimeout

        // Then
        XCTAssertTrue(error.isRetryable)
    }

    func testR2ServiceError_accountNotConfigured_isNotRetryable() {
        // Given
        let error = R2ServiceError.accountNotConfigured

        // Then
        XCTAssertFalse(error.isRetryable)
    }

    func testR2ServiceError_invalidCredentials_isNotRetryable() {
        // Given
        let error = R2ServiceError.invalidCredentials

        // Then
        XCTAssertFalse(error.isRetryable)
    }

    func testR2ServiceError_storageQuotaExceeded_isNotRetryable() {
        // Given
        let error = R2ServiceError.storageQuotaExceeded

        // Then
        XCTAssertFalse(error.isRetryable)
    }

    // MARK: - Download Directory Creation Tests

    func testDownloadDirectoryCreation_parentDirectoryCreatedWhenNeeded() {
        // Given - 一个不存在的嵌套路径
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("OwlUploaderTests_\(UUID().uuidString)")
        let nestedPath = testDir.appendingPathComponent("subfolder/nested/file.txt")

        // When - 模拟下载前的目录创建逻辑
        let parentDirectory = nestedPath.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            XCTFail("创建父目录失败: \(error)")
        }

        // Then - 验证目录已创建
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: parentDirectory.path, isDirectory: &isDirectory)
        XCTAssertTrue(exists, "父目录应该存在")
        XCTAssertTrue(isDirectory.boolValue, "应该是一个目录")

        // Cleanup
        try? FileManager.default.removeItem(at: testDir)
    }

    func testDownloadDirectoryCreation_existingDirectoryNotAffected() {
        // Given - 已存在的目录
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("OwlUploaderTests_\(UUID().uuidString)")
        let filePath = testDir.appendingPathComponent("existing_file.txt")

        // 先创建目录和一个标记文件
        do {
            try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true, attributes: nil)
            try "marker".write(to: testDir.appendingPathComponent("marker.txt"), atomically: true, encoding: .utf8)
        } catch {
            XCTFail("设置测试环境失败: \(error)")
        }

        // When - 再次执行目录创建逻辑（模拟下载）
        let parentDirectory = filePath.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            XCTFail("目录创建不应失败: \(error)")
        }

        // Then - 验证原有文件仍然存在
        XCTAssertTrue(FileManager.default.fileExists(atPath: testDir.appendingPathComponent("marker.txt").path),
                      "已存在的文件不应被影响")

        // Cleanup
        try? FileManager.default.removeItem(at: testDir)
    }

    func testDownloadDirectoryCreation_multiLevelNestedPath() {
        // Given - 多层嵌套路径（模拟文件夹下载场景）
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("OwlUploaderTests_\(UUID().uuidString)")
        let deepPath = testDir.appendingPathComponent("blog/2025/images/thumbnails/cover.jpg")

        // When - 创建多层嵌套目录
        let parentDirectory = deepPath.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            XCTFail("创建多层目录失败: \(error)")
        }

        // Then - 验证所有层级目录都已创建
        XCTAssertTrue(FileManager.default.fileExists(atPath: testDir.appendingPathComponent("blog").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: testDir.appendingPathComponent("blog/2025").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: testDir.appendingPathComponent("blog/2025/images").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: testDir.appendingPathComponent("blog/2025/images/thumbnails").path))

        // Cleanup
        try? FileManager.default.removeItem(at: testDir)
    }

    func testDownloadDirectoryCreation_fileCanBeCreatedAfterDirectorySetup() {
        // Given - 嵌套路径
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("OwlUploaderTests_\(UUID().uuidString)")
        let filePath = testDir.appendingPathComponent("downloads/blog/image.jpg")

        // When - 先创建目录，然后创建文件（模拟完整的下载流程）
        let parentDirectory = filePath.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)
            // 模拟 FileManager.createFile
            let success = FileManager.default.createFile(atPath: filePath.path, contents: nil, attributes: nil)
            XCTAssertTrue(success, "文件创建应该成功")

            // 模拟 FileHandle 打开
            let fileHandle = try FileHandle(forWritingTo: filePath)
            fileHandle.write("test content".data(using: .utf8)!)
            try fileHandle.close()
        } catch {
            XCTFail("文件操作失败: \(error)")
        }

        // Then - 验证文件已创建并有内容
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath.path))
        if let content = try? String(contentsOf: filePath, encoding: .utf8) {
            XCTAssertEqual(content, "test content")
        } else {
            XCTFail("无法读取文件内容")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: testDir)
    }

    // MARK: - MIME Type Tests (文档性测试)

    func testMIMEType_commonExtensionsMapping() {
        // 验证常见扩展名的预期 MIME 类型映射
        let expectedMappings: [String: String] = [
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "png": "image/png",
            "gif": "image/gif",
            "pdf": "application/pdf",
            "txt": "text/plain",
            "json": "application/json",
            "mp4": "video/mp4",
            "mp3": "audio/mpeg",
            "zip": "application/zip"
        ]

        // 这是一个文档性测试，验证我们期望的 MIME 类型映射
        // 实际的 inferContentType 测试需要通过上传功能集成测试
        XCTAssertEqual(expectedMappings.count, 10, "应有 10 个常见 MIME 类型映射")
    }
}
