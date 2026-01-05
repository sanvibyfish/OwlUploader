//
//  R2AccountTests.swift
//  OwlUploaderTests
//
//  R2Account 模型单元测试
//

import XCTest
@testable import OwlUploader

final class R2AccountTests: XCTestCase {

    // MARK: - isValid() Tests

    func testAccountValidation_withValidData_returnsTrue() {
        // Given
        let account = R2Account(
            accountID: "abc123def456",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE",
            endpointURL: "https://abc123def456.r2.cloudflarestorage.com",
            displayName: "Test Account"
        )

        // When
        let isValid = account.isValid()

        // Then
        XCTAssertTrue(isValid, "账户配置应该有效")
    }

    func testAccountValidation_withEmptyAccountId_returnsFalse() {
        // Given
        let account = R2Account(
            accountID: "",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE",
            endpointURL: "https://test.r2.cloudflarestorage.com"
        )

        // When
        let isValid = account.isValid()

        // Then
        XCTAssertFalse(isValid, "空的 Account ID 应该无效")
    }

    func testAccountValidation_withEmptyAccessKeyId_returnsFalse() {
        // Given
        let account = R2Account(
            accountID: "abc123def456",
            accessKeyID: "",
            endpointURL: "https://test.r2.cloudflarestorage.com"
        )

        // When
        let isValid = account.isValid()

        // Then
        XCTAssertFalse(isValid, "空的 Access Key ID 应该无效")
    }

    func testAccountValidation_withWhitespaceOnlyAccountId_returnsFalse() {
        // Given
        let account = R2Account(
            accountID: "   ",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE",
            endpointURL: "https://test.r2.cloudflarestorage.com"
        )

        // When
        let isValid = account.isValid()

        // Then
        XCTAssertFalse(isValid, "只有空白字符的 Account ID 应该无效")
    }

    func testAccountValidation_withInvalidEndpoint_returnsFalse() {
        // Given
        let account = R2Account(
            accountID: "abc123def456",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE",
            endpointURL: "not-a-valid-url"
        )

        // When
        let isValid = account.isValid()

        // Then
        XCTAssertFalse(isValid, "无效的端点 URL 应该无效")
    }

    func testAccountValidation_withEmptyEndpoint_returnsFalse() {
        // Given
        let account = R2Account(
            accountID: "abc123def456",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE",
            endpointURL: ""
        )

        // When
        let isValid = account.isValid()

        // Then
        XCTAssertFalse(isValid, "空的端点 URL 应该无效")
    }

    // MARK: - defaultCloudflareR2EndpointURL() Tests

    func testDefaultEndpointURL_generatesCorrectFormat() {
        // Given
        let accountID = "abc123def456"

        // When
        let endpoint = R2Account.defaultCloudflareR2EndpointURL(for: accountID)

        // Then
        XCTAssertEqual(endpoint, "https://abc123def456.r2.cloudflarestorage.com")
    }

    func testDefaultEndpointURL_withEmptyAccountId() {
        // Given
        let accountID = ""

        // When
        let endpoint = R2Account.defaultCloudflareR2EndpointURL(for: accountID)

        // Then
        XCTAssertEqual(endpoint, "https://.r2.cloudflarestorage.com")
    }

    // MARK: - URL Validation Tests

    func testAccountValidation_withHttpsURL_isValid() {
        // Given
        let account = R2Account(
            accountID: "abc123def456",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE",
            endpointURL: "https://example.com"
        )

        // When
        let isValid = account.isValid()

        // Then
        XCTAssertTrue(isValid, "HTTPS URL 应该有效")
    }

    func testAccountValidation_withHttpURL_isValid() {
        // Given - HTTP 也是有效的（虽然不推荐）
        let account = R2Account(
            accountID: "abc123def456",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE",
            endpointURL: "http://localhost:9000"
        )

        // When
        let isValid = account.isValid()

        // Then
        XCTAssertTrue(isValid, "HTTP URL 应该有效（用于本地开发）")
    }

    func testAccountValidation_withFtpURL_returnsFalse() {
        // Given
        let account = R2Account(
            accountID: "abc123def456",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE",
            endpointURL: "ftp://example.com"
        )

        // When
        let isValid = account.isValid()

        // Then
        XCTAssertFalse(isValid, "FTP URL 应该无效")
    }

    // MARK: - Initialization Tests

    func testInit_withDefaultEndpoint() {
        // Given
        let accountID = "abc123def456"

        // When
        let account = R2Account(
            accountID: accountID,
            accessKeyID: "AKIAIOSFODNN7EXAMPLE"
        )

        // Then
        XCTAssertEqual(account.endpointURL, "https://abc123def456.r2.cloudflarestorage.com")
    }

    func testInit_withDefaultDisplayName() {
        // Given
        let accountID = "abc123def456789"

        // When
        let account = R2Account(
            accountID: accountID,
            accessKeyID: "AKIAIOSFODNN7EXAMPLE"
        )

        // Then
        XCTAssertEqual(account.displayName, "abc123de", "默认显示名称应为 Account ID 的前 8 位")
    }

    func testInit_withCustomDisplayName() {
        // Given & When
        let account = R2Account(
            accountID: "abc123def456",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE",
            displayName: "My Custom Account"
        )

        // Then
        XCTAssertEqual(account.displayName, "My Custom Account")
    }

    func testInit_setsCreatedAndUpdatedDates() {
        // Given
        let beforeCreation = Date()

        // When
        let account = R2Account(
            accountID: "abc123def456",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE"
        )

        let afterCreation = Date()

        // Then
        XCTAssertGreaterThanOrEqual(account.createdAt, beforeCreation)
        XCTAssertLessThanOrEqual(account.createdAt, afterCreation)
        XCTAssertEqual(account.createdAt, account.updatedAt)
    }

    // MARK: - updated() Tests

    func testUpdated_preservesId() {
        // Given
        let original = R2Account(
            accountID: "abc123def456",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE"
        )
        let originalId = original.id

        // When
        let updated = original.updated(displayName: "New Name")

        // Then
        XCTAssertEqual(updated.id, originalId, "更新后 ID 应该保持不变")
    }

    func testUpdated_changesSpecifiedFields() {
        // Given
        let original = R2Account(
            accountID: "abc123def456",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE",
            displayName: "Original Name"
        )

        // When
        let updated = original.updated(
            accountID: "newAccountId",
            accessKeyID: "newAccessKey",
            displayName: "New Name"
        )

        // Then
        XCTAssertEqual(updated.accountID, "newAccountId")
        XCTAssertEqual(updated.accessKeyID, "newAccessKey")
        XCTAssertEqual(updated.displayName, "New Name")
    }

    func testUpdated_preservesUnchangedFields() {
        // Given
        let original = R2Account(
            accountID: "abc123def456",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE",
            endpointURL: "https://test.example.com"
        )

        // When
        let updated = original.updated(displayName: "New Name")

        // Then
        XCTAssertEqual(updated.accountID, original.accountID)
        XCTAssertEqual(updated.accessKeyID, original.accessKeyID)
        XCTAssertEqual(updated.endpointURL, original.endpointURL)
    }

    func testUpdated_updatesUpdatedAt() {
        // Given
        let original = R2Account(
            accountID: "abc123def456",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE"
        )

        // Wait a tiny bit to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)

        // When
        let updated = original.updated(displayName: "New Name")

        // Then
        XCTAssertGreaterThan(updated.updatedAt, original.updatedAt)
    }

    // MARK: - Codable Tests

    func testCodable_encodesAndDecodesCorrectly() throws {
        // Given
        let original = R2Account(
            accountID: "abc123def456",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE",
            endpointURL: "https://test.r2.cloudflarestorage.com",
            displayName: "Test Account",
            bucketNames: ["my-bucket"],
            publicDomains: ["cdn.example.com"]
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(R2Account.self, from: data)

        // Then
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.accountID, original.accountID)
        XCTAssertEqual(decoded.accessKeyID, original.accessKeyID)
        XCTAssertEqual(decoded.endpointURL, original.endpointURL)
        XCTAssertEqual(decoded.displayName, original.displayName)
        XCTAssertEqual(decoded.bucketNames, original.bucketNames)
        XCTAssertEqual(decoded.publicDomains, original.publicDomains)
    }

    // MARK: - Equatable Tests

    func testEquatable_sameIdAreEqual() {
        // Given
        let account1 = R2Account(
            accountID: "abc123def456",
            accessKeyID: "key1"
        )

        // Create a copy with same ID but different fields
        var account2 = account1
        account2.displayName = "Different Name"

        // Then - They should be equal because ID is the same
        XCTAssertEqual(account1, account2)
    }

    func testEquatable_differentIdAreNotEqual() {
        // Given
        let account1 = R2Account(
            accountID: "abc123def456",
            accessKeyID: "key1"
        )

        let account2 = R2Account(
            accountID: "abc123def456",
            accessKeyID: "key1"
        )

        // Then - Different instances have different UUIDs
        XCTAssertNotEqual(account1, account2)
    }

    // MARK: - Hashable Tests

    func testHashable_canBeUsedInSet() {
        // Given
        let account1 = R2Account(
            accountID: "abc123def456",
            accessKeyID: "key1"
        )

        let account2 = R2Account(
            accountID: "xyz789",
            accessKeyID: "key2"
        )

        // When
        var set = Set<R2Account>()
        set.insert(account1)
        set.insert(account2)

        // Then
        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(account1))
        XCTAssertTrue(set.contains(account2))
    }

    // MARK: - Keychain Identifier Tests

    func testKeychainAccountIdentifier_format() {
        // Given
        let account = R2Account(
            accountID: "abc123",
            accessKeyID: "AKIATEST"
        )

        // When
        let identifier = account.keychainAccountIdentifier

        // Then
        XCTAssertEqual(identifier, "abc123_AKIATEST")
    }

    // MARK: - Bucket & Public Domain Tests

    func testDefaultPublicDomain_returnsValueWhenIndexValid() {
        // Given
        let account = R2Account(
            accountID: "abc123def456",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE",
            publicDomains: ["cdn.example.com", "static.example.com"],
            defaultPublicDomainIndex: 1
        )

        // Then
        XCTAssertEqual(account.defaultPublicDomain, "static.example.com")
    }

    func testDefaultPublicDomain_returnsNilWhenIndexOutOfRange() {
        // Given
        let account = R2Account(
            accountID: "abc123def456",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE",
            publicDomains: ["cdn.example.com"],
            defaultPublicDomainIndex: 3
        )

        // Then
        XCTAssertNil(account.defaultPublicDomain)
    }

    func testAddingAndRemovingBucket_updatesBucketList() {
        // Given
        let account = R2Account(
            accountID: "abc123def456",
            accessKeyID: "AKIAIOSFODNN7EXAMPLE"
        )

        // When
        let updated = account.addingBucket("my-bucket")
        let removed = updated.removingBucket("my-bucket")

        // Then
        XCTAssertTrue(updated.hasBucket("my-bucket"))
        XCTAssertFalse(removed.hasBucket("my-bucket"))
    }
}
