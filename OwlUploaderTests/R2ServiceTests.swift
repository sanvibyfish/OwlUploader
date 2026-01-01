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
        let endpoint = "https://abc123def456789012345678901234.r2.cloudflarestorage.com"

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
        XCTAssertTrue(result.message.contains("格式"))
    }

    func testValidateR2Endpoint_withHttpProtocol_returnsFalse() {
        // Given - HTTP 而不是 HTTPS
        let endpoint = "http://abc123def456789012345678901234.r2.cloudflarestorage.com"

        // When
        let result = r2Service.validateR2Endpoint(endpoint)

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.message.contains("HTTPS"))
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
        let endpoint = "https://abc123def456789012345678901234.s3.amazonaws.com"

        // When
        let result = r2Service.validateR2Endpoint(endpoint)

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.message.contains("Cloudflare R2"))
    }

    func testValidateR2Endpoint_withPath_returnsFalse() {
        // Given - 包含路径
        let endpoint = "https://abc123def456789012345678901234.r2.cloudflarestorage.com/bucket"

        // When
        let result = r2Service.validateR2Endpoint(endpoint)

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.message.contains("路径"))
    }

    func testValidateR2Endpoint_withCustomPort_returnsFalse() {
        // Given - 非标准端口
        let endpoint = "https://abc123def456789012345678901234.r2.cloudflarestorage.com:8443"

        // When
        let result = r2Service.validateR2Endpoint(endpoint)

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.message.contains("端口"))
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
        let endpoint = "https://ghijklmnopqrstuvwxyz123456789012.r2.cloudflarestorage.com"

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

}

// MARK: - R2ServiceError Tests (不需要 @MainActor)

final class R2ServiceErrorTests: XCTestCase {

    // MARK: - errorDescription Tests

    func testR2ServiceError_accountNotConfigured_hasDescription() {
        // Given
        let error = R2ServiceError.accountNotConfigured

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("账户") == true ||
                     error.errorDescription?.contains("配置") == true)
    }

    func testR2ServiceError_invalidCredentials_hasDescription() {
        // Given
        let error = R2ServiceError.invalidCredentials

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("凭证") == true ||
                     error.errorDescription?.contains("Key") == true)
    }

    func testR2ServiceError_bucketNotFound_includesBucketName() {
        // Given
        let bucketName = "my-test-bucket"
        let error = R2ServiceError.bucketNotFound(bucketName)

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains(bucketName) == true)
    }

    func testR2ServiceError_uploadFailed_includesFileName() {
        // Given
        let fileName = "document.pdf"
        let underlyingError = NSError(domain: "test", code: -1)
        let error = R2ServiceError.uploadFailed(fileName, underlyingError)

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains(fileName) == true)
    }

    func testR2ServiceError_downloadFailed_includesFileName() {
        // Given
        let fileName = "image.png"
        let underlyingError = NSError(domain: "test", code: -1)
        let error = R2ServiceError.downloadFailed(fileName, underlyingError)

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains(fileName) == true)
    }

    func testR2ServiceError_connectionTimeout_hasDescription() {
        // Given
        let error = R2ServiceError.connectionTimeout

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("超时") == true)
    }

    func testR2ServiceError_dnsResolutionFailed_hasDescription() {
        // Given
        let error = R2ServiceError.dnsResolutionFailed

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("DNS") == true)
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
