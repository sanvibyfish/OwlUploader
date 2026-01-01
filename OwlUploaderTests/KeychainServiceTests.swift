//
//  KeychainServiceTests.swift
//  OwlUploaderTests
//
//  KeychainService 单元测试
//  注意：这些测试使用真实的 Keychain，测试后会清理数据
//

import XCTest
@testable import OwlUploader

final class KeychainServiceTests: XCTestCase {

    // MARK: - Properties

    private let testService = "com.owluploader.tests.keychain"
    private let testAccount = "test-account-\(UUID().uuidString)"
    private var keychainService: KeychainService!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()
        keychainService = KeychainService.shared
        // 确保测试开始前清理
        try? keychainService.delete(service: testService, account: testAccount)
    }

    override func tearDownWithError() throws {
        // 清理测试数据
        try? keychainService.delete(service: testService, account: testAccount)
        keychainService = nil
        try super.tearDownWithError()
    }

    // MARK: - Store Tests

    func testStore_savesStringValue() throws {
        // Given
        let testValue = "my-secret-value"

        // When
        try keychainService.store(testValue, service: testService, account: testAccount)

        // Then
        let retrieved = try keychainService.retrieve(service: testService, account: testAccount)
        XCTAssertEqual(retrieved, testValue)
    }

    func testStore_savesDataValue() throws {
        // Given
        let testData = "binary-data".data(using: .utf8)!

        // When
        try keychainService.store(testData, service: testService, account: testAccount)

        // Then
        let retrieved = try keychainService.retrieveData(service: testService, account: testAccount)
        XCTAssertEqual(retrieved, testData)
    }

    func testStore_overwritesExistingValue() throws {
        // Given
        try keychainService.store("original-value", service: testService, account: testAccount)

        // When
        try keychainService.store("new-value", service: testService, account: testAccount)

        // Then
        let retrieved = try keychainService.retrieve(service: testService, account: testAccount)
        XCTAssertEqual(retrieved, "new-value")
    }

    // MARK: - Retrieve Tests

    func testRetrieve_returnsStoredValue() throws {
        // Given
        let testValue = "stored-secret"
        try keychainService.store(testValue, service: testService, account: testAccount)

        // When
        let retrieved = try keychainService.retrieve(service: testService, account: testAccount)

        // Then
        XCTAssertEqual(retrieved, testValue)
    }

    func testRetrieve_throwsItemNotFound_whenNotExists() {
        // Given
        let nonExistentAccount = "non-existent-\(UUID().uuidString)"

        // When & Then
        XCTAssertThrowsError(try keychainService.retrieve(service: testService, account: nonExistentAccount)) { error in
            guard let keychainError = error as? KeychainService.KeychainError else {
                XCTFail("Expected KeychainError")
                return
            }
            XCTAssertEqual(keychainError, .itemNotFound)
        }
    }

    // MARK: - Update Tests

    func testUpdate_modifiesExistingValue() throws {
        // Given
        try keychainService.store("original", service: testService, account: testAccount)

        // When
        try keychainService.update("updated", service: testService, account: testAccount)

        // Then
        let retrieved = try keychainService.retrieve(service: testService, account: testAccount)
        XCTAssertEqual(retrieved, "updated")
    }

    func testUpdate_throwsItemNotFound_whenNotExists() {
        // Given
        let nonExistentAccount = "non-existent-\(UUID().uuidString)"

        // When & Then
        XCTAssertThrowsError(try keychainService.update("value", service: testService, account: nonExistentAccount)) { error in
            guard let keychainError = error as? KeychainService.KeychainError else {
                XCTFail("Expected KeychainError")
                return
            }
            XCTAssertEqual(keychainError, .itemNotFound)
        }
    }

    // MARK: - Delete Tests

    func testDelete_removesItem() throws {
        // Given
        try keychainService.store("to-delete", service: testService, account: testAccount)
        XCTAssertTrue(keychainService.exists(service: testService, account: testAccount))

        // When
        try keychainService.delete(service: testService, account: testAccount)

        // Then
        XCTAssertFalse(keychainService.exists(service: testService, account: testAccount))
    }

    func testDelete_succeedsWhenItemNotExists() throws {
        // Given
        let nonExistentAccount = "non-existent-\(UUID().uuidString)"

        // When & Then - Should not throw
        XCTAssertNoThrow(try keychainService.delete(service: testService, account: nonExistentAccount))
    }

    // MARK: - Exists Tests

    func testExists_returnsTrueForExistingItem() throws {
        // Given
        try keychainService.store("exists-test", service: testService, account: testAccount)

        // When
        let exists = keychainService.exists(service: testService, account: testAccount)

        // Then
        XCTAssertTrue(exists)
    }

    func testExists_returnsFalseForNonExistingItem() {
        // Given
        let nonExistentAccount = "non-existent-\(UUID().uuidString)"

        // When
        let exists = keychainService.exists(service: testService, account: nonExistentAccount)

        // Then
        XCTAssertFalse(exists)
    }

    // MARK: - R2Account Extension Tests

    func testStoreSecretAccessKey_savesForAccount() throws {
        // Given
        let account = createTestR2Account()
        let secretKey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

        // When
        try keychainService.storeSecretAccessKey(secretKey, for: account)

        // Then
        let retrieved = try keychainService.retrieveSecretAccessKey(for: account)
        XCTAssertEqual(retrieved, secretKey)

        // Cleanup
        try? keychainService.deleteSecretAccessKey(for: account)
    }

    func testRetrieveSecretAccessKey_returnsStoredKey() throws {
        // Given
        let account = createTestR2Account()
        let secretKey = "test-secret-key-12345"
        try keychainService.storeSecretAccessKey(secretKey, for: account)

        // When
        let retrieved = try keychainService.retrieveSecretAccessKey(for: account)

        // Then
        XCTAssertEqual(retrieved, secretKey)

        // Cleanup
        try? keychainService.deleteSecretAccessKey(for: account)
    }

    func testRetrieveSecretAccessKey_throwsWhenNotExists() {
        // Given
        let account = createTestR2Account()

        // When & Then
        XCTAssertThrowsError(try keychainService.retrieveSecretAccessKey(for: account)) { error in
            guard let keychainError = error as? KeychainService.KeychainError else {
                XCTFail("Expected KeychainError")
                return
            }
            XCTAssertEqual(keychainError, .itemNotFound)
        }
    }

    func testUpdateSecretAccessKey_updatesExisting() throws {
        // Given
        let account = createTestR2Account()
        try keychainService.storeSecretAccessKey("original-key", for: account)

        // When
        try keychainService.updateSecretAccessKey("updated-key", for: account)

        // Then
        let retrieved = try keychainService.retrieveSecretAccessKey(for: account)
        XCTAssertEqual(retrieved, "updated-key")

        // Cleanup
        try? keychainService.deleteSecretAccessKey(for: account)
    }

    func testUpdateSecretAccessKey_createsWhenNotExists() throws {
        // Given
        let account = createTestR2Account()

        // When
        try keychainService.updateSecretAccessKey("new-key", for: account)

        // Then
        let retrieved = try keychainService.retrieveSecretAccessKey(for: account)
        XCTAssertEqual(retrieved, "new-key")

        // Cleanup
        try? keychainService.deleteSecretAccessKey(for: account)
    }

    func testDeleteSecretAccessKey_removesKey() throws {
        // Given
        let account = createTestR2Account()
        try keychainService.storeSecretAccessKey("to-delete", for: account)
        XCTAssertTrue(keychainService.hasSecretAccessKey(for: account))

        // When
        try keychainService.deleteSecretAccessKey(for: account)

        // Then
        XCTAssertFalse(keychainService.hasSecretAccessKey(for: account))
    }

    func testHasSecretAccessKey_returnsTrueWhenExists() throws {
        // Given
        let account = createTestR2Account()
        try keychainService.storeSecretAccessKey("exists", for: account)

        // When
        let has = keychainService.hasSecretAccessKey(for: account)

        // Then
        XCTAssertTrue(has)

        // Cleanup
        try? keychainService.deleteSecretAccessKey(for: account)
    }

    func testHasSecretAccessKey_returnsFalseWhenNotExists() {
        // Given
        let account = createTestR2Account()

        // When
        let has = keychainService.hasSecretAccessKey(for: account)

        // Then
        XCTAssertFalse(has)
    }

    // MARK: - Error Tests

    func testKeychainError_itemNotFound_hasCorrectDescription() {
        // Given
        let error = KeychainService.KeychainError.itemNotFound

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("未找到") == true ||
                     error.errorDescription?.contains("not found") == true)
    }

    func testKeychainError_invalidData_hasCorrectDescription() {
        // Given
        let error = KeychainService.KeychainError.invalidData

        // Then
        XCTAssertNotNil(error.errorDescription)
    }

    func testKeychainError_unexpectedError_includesStatusCode() {
        // Given
        let error = KeychainService.KeychainError.unexpectedError(status: -25300)

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("-25300") == true)
    }

    // MARK: - Equatable Tests for KeychainError

    func testKeychainError_equalityComparison() {
        // Given
        let error1 = KeychainService.KeychainError.itemNotFound
        let error2 = KeychainService.KeychainError.itemNotFound
        let error3 = KeychainService.KeychainError.invalidData

        // Then
        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    // MARK: - Helper Methods

    private func createTestR2Account() -> R2Account {
        return R2Account(
            accountID: "test-\(UUID().uuidString.prefix(8))",
            accessKeyID: "AKIATEST\(UUID().uuidString.prefix(8))"
        )
    }
}

// MARK: - KeychainError Equatable Extension for Tests

extension KeychainService.KeychainError: @retroactive Equatable {
    public static func == (lhs: KeychainService.KeychainError, rhs: KeychainService.KeychainError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidData, .invalidData):
            return true
        case (.itemNotFound, .itemNotFound):
            return true
        case (.duplicateItem, .duplicateItem):
            return true
        case (.unexpectedError(let status1), .unexpectedError(let status2)):
            return status1 == status2
        default:
            return false
        }
    }
}
