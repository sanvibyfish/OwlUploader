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

    override func setUp() async throws {
        try await super.setUp()
        keychainService = KeychainService.shared
        // 确保测试开始前清理
        try? await deleteOnBackground(service: testService, account: testAccount)
    }

    override func tearDown() async throws {
        // 清理测试数据
        try? await deleteOnBackground(service: testService, account: testAccount)
        keychainService = nil
        try await super.tearDown()
    }

    // MARK: - Store Tests

    func testStore_savesStringValue() async throws {
        // Given
        let testValue = "my-secret-value"

        // When
        try await storeOnBackground(testValue, service: testService, account: testAccount)

        // Then
        let retrieved = try await retrieveOnBackground(service: testService, account: testAccount)
        XCTAssertEqual(retrieved, testValue)
    }

    func testStore_savesDataValue() async throws {
        // Given
        let testData = "binary-data".data(using: .utf8)!

        // When
        try await storeOnBackground(testData, service: testService, account: testAccount)

        // Then
        let retrieved = try await retrieveDataOnBackground(service: testService, account: testAccount)
        XCTAssertEqual(retrieved, testData)
    }

    func testStore_overwritesExistingValue() async throws {
        // Given
        try await storeOnBackground("original-value", service: testService, account: testAccount)

        // When
        try await storeOnBackground("new-value", service: testService, account: testAccount)

        // Then
        let retrieved = try await retrieveOnBackground(service: testService, account: testAccount)
        XCTAssertEqual(retrieved, "new-value")
    }

    // MARK: - Retrieve Tests

    func testRetrieve_returnsStoredValue() async throws {
        // Given
        let testValue = "stored-secret"
        try await storeOnBackground(testValue, service: testService, account: testAccount)

        // When
        let retrieved = try await retrieveOnBackground(service: testService, account: testAccount)

        // Then
        XCTAssertEqual(retrieved, testValue)
    }

    func testRetrieve_throwsItemNotFound_whenNotExists() async {
        // Given
        let nonExistentAccount = "non-existent-\(UUID().uuidString)"

        // When & Then
        do {
            _ = try await retrieveOnBackground(service: testService, account: nonExistentAccount)
            XCTFail("Expected KeychainError")
        } catch {
            guard let keychainError = error as? KeychainService.KeychainError else {
                XCTFail("Expected KeychainError")
                return
            }
            XCTAssertEqual(keychainError, .itemNotFound)
        }
    }

    // MARK: - Update Tests

    func testUpdate_modifiesExistingValue() async throws {
        // Given
        try await storeOnBackground("original", service: testService, account: testAccount)

        // When
        try await updateOnBackground("updated", service: testService, account: testAccount)

        // Then
        let retrieved = try await retrieveOnBackground(service: testService, account: testAccount)
        XCTAssertEqual(retrieved, "updated")
    }

    func testUpdate_throwsItemNotFound_whenNotExists() async {
        // Given
        let nonExistentAccount = "non-existent-\(UUID().uuidString)"

        // When & Then
        do {
            try await updateOnBackground("value", service: testService, account: nonExistentAccount)
            XCTFail("Expected KeychainError")
        } catch {
            guard let keychainError = error as? KeychainService.KeychainError else {
                XCTFail("Expected KeychainError")
                return
            }
            XCTAssertEqual(keychainError, .itemNotFound)
        }
    }

    // MARK: - Delete Tests

    func testDelete_removesItem() async throws {
        // Given
        try await storeOnBackground("to-delete", service: testService, account: testAccount)
        let existsBefore = await existsOnBackground(service: testService, account: testAccount)
        XCTAssertTrue(existsBefore)

        // When
        try await deleteOnBackground(service: testService, account: testAccount)

        // Then
        let existsAfter = await existsOnBackground(service: testService, account: testAccount)
        XCTAssertFalse(existsAfter)
    }

    func testDelete_succeedsWhenItemNotExists() async throws {
        // Given
        let nonExistentAccount = "non-existent-\(UUID().uuidString)"

        // When & Then - Should not throw
        try await deleteOnBackground(service: testService, account: nonExistentAccount)
    }

    // MARK: - Exists Tests

    func testExists_returnsTrueForExistingItem() async throws {
        // Given
        try await storeOnBackground("exists-test", service: testService, account: testAccount)

        // When
        let exists = await existsOnBackground(service: testService, account: testAccount)

        // Then
        XCTAssertTrue(exists)
    }

    func testExists_returnsFalseForNonExistingItem() async {
        // Given
        let nonExistentAccount = "non-existent-\(UUID().uuidString)"

        // When
        let exists = await existsOnBackground(service: testService, account: nonExistentAccount)

        // Then
        XCTAssertFalse(exists)
    }

    // MARK: - R2Account Extension Tests

    func testStoreSecretAccessKey_savesForAccount() async throws {
        // Given
        let account = createTestR2Account()
        let secretKey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

        // When
        try await storeSecretAccessKeyOnBackground(secretKey, for: account)

        // Then
        let retrieved = try await retrieveSecretAccessKeyOnBackground(for: account)
        XCTAssertEqual(retrieved, secretKey)

        // Cleanup
        try? await deleteSecretAccessKeyOnBackground(for: account)
    }

    func testRetrieveSecretAccessKey_returnsStoredKey() async throws {
        // Given
        let account = createTestR2Account()
        let secretKey = "test-secret-key-12345"
        try await storeSecretAccessKeyOnBackground(secretKey, for: account)

        // When
        let retrieved = try await retrieveSecretAccessKeyOnBackground(for: account)

        // Then
        XCTAssertEqual(retrieved, secretKey)

        // Cleanup
        try? await deleteSecretAccessKeyOnBackground(for: account)
    }

    func testRetrieveSecretAccessKey_throwsWhenNotExists() async {
        // Given
        let account = createTestR2Account()

        // When & Then
        do {
            _ = try await retrieveSecretAccessKeyOnBackground(for: account)
            XCTFail("Expected KeychainError")
        } catch {
            guard let keychainError = error as? KeychainService.KeychainError else {
                XCTFail("Expected KeychainError")
                return
            }
            XCTAssertEqual(keychainError, .itemNotFound)
        }
    }

    func testUpdateSecretAccessKey_updatesExisting() async throws {
        // Given
        let account = createTestR2Account()
        try await storeSecretAccessKeyOnBackground("original-key", for: account)

        // When
        try await updateSecretAccessKeyOnBackground("updated-key", for: account)

        // Then
        let retrieved = try await retrieveSecretAccessKeyOnBackground(for: account)
        XCTAssertEqual(retrieved, "updated-key")

        // Cleanup
        try? await deleteSecretAccessKeyOnBackground(for: account)
    }

    func testUpdateSecretAccessKey_createsWhenNotExists() async throws {
        // Given
        let account = createTestR2Account()

        // When
        try await updateSecretAccessKeyOnBackground("new-key", for: account)

        // Then
        let retrieved = try await retrieveSecretAccessKeyOnBackground(for: account)
        XCTAssertEqual(retrieved, "new-key")

        // Cleanup
        try? await deleteSecretAccessKeyOnBackground(for: account)
    }

    func testDeleteSecretAccessKey_removesKey() async throws {
        // Given
        let account = createTestR2Account()
        try await storeSecretAccessKeyOnBackground("to-delete", for: account)
        let hasBefore = await hasSecretAccessKeyOnBackground(for: account)
        XCTAssertTrue(hasBefore)

        // When
        try await deleteSecretAccessKeyOnBackground(for: account)

        // Then
        let hasAfter = await hasSecretAccessKeyOnBackground(for: account)
        XCTAssertFalse(hasAfter)
    }

    func testHasSecretAccessKey_returnsTrueWhenExists() async throws {
        // Given
        let account = createTestR2Account()
        try await storeSecretAccessKeyOnBackground("exists", for: account)

        // When
        let has = await hasSecretAccessKeyOnBackground(for: account)

        // Then
        XCTAssertTrue(has)

        // Cleanup
        try? await deleteSecretAccessKeyOnBackground(for: account)
    }

    func testHasSecretAccessKey_returnsFalseWhenNotExists() async {
        // Given
        let account = createTestR2Account()

        // When
        let has = await hasSecretAccessKeyOnBackground(for: account)

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

    // MARK: - Background Helpers

    private func storeOnBackground(_ value: String, service: String, account: String) async throws {
        try await Task.detached(priority: .background) {
            try self.keychainService.store(value, service: service, account: account)
        }.value
    }

    private func storeOnBackground(_ value: Data, service: String, account: String) async throws {
        try await Task.detached(priority: .background) {
            try self.keychainService.store(value, service: service, account: account)
        }.value
    }

    private func retrieveOnBackground(service: String, account: String) async throws -> String {
        try await Task.detached(priority: .background) {
            try self.keychainService.retrieve(service: service, account: account)
        }.value
    }

    private func retrieveDataOnBackground(service: String, account: String) async throws -> Data {
        try await Task.detached(priority: .background) {
            try self.keychainService.retrieveData(service: service, account: account)
        }.value
    }

    private func updateOnBackground(_ value: String, service: String, account: String) async throws {
        try await Task.detached(priority: .background) {
            try self.keychainService.update(value, service: service, account: account)
        }.value
    }

    private func deleteOnBackground(service: String, account: String) async throws {
        try await Task.detached(priority: .background) {
            try self.keychainService.delete(service: service, account: account)
        }.value
    }

    private func existsOnBackground(service: String, account: String) async -> Bool {
        await Task.detached(priority: .background) {
            self.keychainService.exists(service: service, account: account)
        }.value
    }

    private func storeSecretAccessKeyOnBackground(_ secret: String, for account: R2Account) async throws {
        try await Task.detached(priority: .background) {
            try self.keychainService.storeSecretAccessKey(secret, for: account)
        }.value
    }

    private func retrieveSecretAccessKeyOnBackground(for account: R2Account) async throws -> String {
        try await Task.detached(priority: .background) {
            try self.keychainService.retrieveSecretAccessKey(for: account)
        }.value
    }

    private func updateSecretAccessKeyOnBackground(_ secret: String, for account: R2Account) async throws {
        try await Task.detached(priority: .background) {
            try self.keychainService.updateSecretAccessKey(secret, for: account)
        }.value
    }

    private func deleteSecretAccessKeyOnBackground(for account: R2Account) async throws {
        try await Task.detached(priority: .background) {
            try self.keychainService.deleteSecretAccessKey(for: account)
        }.value
    }

    private func hasSecretAccessKeyOnBackground(for account: R2Account) async -> Bool {
        await Task.detached(priority: .background) {
            self.keychainService.hasSecretAccessKey(for: account)
        }.value
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
