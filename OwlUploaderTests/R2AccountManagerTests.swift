//
//  R2AccountManagerTests.swift
//  OwlUploaderTests
//
//  R2AccountManager 单元测试
//  注意：部分测试使用真实的 UserDefaults 和 Keychain，测试后会清理数据
//

import XCTest
@testable import OwlUploader

@MainActor
final class R2AccountManagerTests: XCTestCase {

    // MARK: - Properties

    private var accountManager: R2AccountManager!
    private var keychainService: KeychainService!
    private var testAccounts: [R2Account] = []

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        accountManager = R2AccountManager.shared
        keychainService = KeychainService.shared
        testAccounts = []
    }

    override func tearDown() async throws {
        // 清理测试创建的账户
        for account in testAccounts {
            try? accountManager.deleteAccount(account)
        }
        testAccounts = []
        try await super.tearDown()
    }

    // MARK: - AccountManagerError Tests

    func testAccountManagerError_invalidAccount_hasDescription() {
        // Given
        let error = R2AccountManager.AccountManagerError.invalidAccount

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("无效") == true)
    }

    func testAccountManagerError_invalidSecretKey_hasDescription() {
        // Given
        let error = R2AccountManager.AccountManagerError.invalidSecretKey

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Secret Access Key") == true)
    }

    func testAccountManagerError_accountNotFound_hasDescription() {
        // Given
        let error = R2AccountManager.AccountManagerError.accountNotFound

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("未找到") == true)
    }

    func testAccountManagerError_saveFailure_hasDescription() {
        // Given
        let error = R2AccountManager.AccountManagerError.saveFailure

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("失败") == true)
    }

    // MARK: - CompleteR2Credentials Tests

    func testCompleteR2Credentials_isValid_withValidData() {
        // Given
        let account = createTestAccount()
        let secretKey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

        // When
        let credentials = CompleteR2Credentials(account: account, secretAccessKey: secretKey)

        // Then
        XCTAssertTrue(credentials.isValid)
    }

    func testCompleteR2Credentials_isInvalid_withEmptySecretKey() {
        // Given
        let account = createTestAccount()

        // When
        let credentials = CompleteR2Credentials(account: account, secretAccessKey: "")

        // Then
        XCTAssertFalse(credentials.isValid)
    }

    func testCompleteR2Credentials_isInvalid_withWhitespaceOnlySecretKey() {
        // Given
        let account = createTestAccount()

        // When
        let credentials = CompleteR2Credentials(account: account, secretAccessKey: "   \n\t  ")

        // Then
        XCTAssertFalse(credentials.isValid)
    }

    func testCompleteR2Credentials_isInvalid_withInvalidAccount() {
        // Given - 无效账户（空的 accountID）
        let invalidAccount = R2Account(
            accountID: "",
            accessKeyID: "AKIATEST"
        )

        // When
        let credentials = CompleteR2Credentials(account: invalidAccount, secretAccessKey: "valid-secret")

        // Then
        XCTAssertFalse(credentials.isValid)
    }

    // MARK: - Shared Instance Tests

    func testSharedInstance_isSingleton() {
        // Given
        let instance1 = R2AccountManager.shared
        let instance2 = R2AccountManager.shared

        // Then
        XCTAssertTrue(instance1 === instance2, "应该返回同一个实例")
    }

    func testSharedInstance_initialState_isNotLoading() {
        // Given
        let manager = R2AccountManager.shared

        // Then
        XCTAssertFalse(manager.isLoading)
    }

    func testSharedInstance_initialState_hasNoError() {
        // Given
        let manager = R2AccountManager.shared

        // Then
        XCTAssertNil(manager.errorMessage)
    }

    // MARK: - saveAccount Tests

    func testSaveAccount_withValidData_addsToAccounts() throws {
        // Given
        let account = createTestAccount()
        let secretKey = "test-secret-key-12345"
        let initialCount = accountManager.accounts.count

        // When
        try accountManager.saveAccount(account, secretAccessKey: secretKey)
        testAccounts.append(account) // 标记需要清理

        // Then
        XCTAssertEqual(accountManager.accounts.count, initialCount + 1)
        XCTAssertTrue(accountManager.accounts.contains(where: { $0.accountID == account.accountID }))
    }

    func testSaveAccount_withInvalidAccount_throwsError() {
        // Given
        let invalidAccount = R2Account(
            accountID: "",
            accessKeyID: "AKIATEST"
        )

        // When & Then
        XCTAssertThrowsError(try accountManager.saveAccount(invalidAccount, secretAccessKey: "secret")) { error in
            guard let managerError = error as? R2AccountManager.AccountManagerError else {
                XCTFail("Expected AccountManagerError")
                return
            }
            XCTAssertEqual(managerError, .invalidAccount)
        }
    }

    func testSaveAccount_withEmptySecretKey_throwsError() {
        // Given
        let account = createTestAccount()

        // When & Then
        XCTAssertThrowsError(try accountManager.saveAccount(account, secretAccessKey: "")) { error in
            guard let managerError = error as? R2AccountManager.AccountManagerError else {
                XCTFail("Expected AccountManagerError")
                return
            }
            XCTAssertEqual(managerError, .invalidSecretKey)
        }
    }

    func testSaveAccount_withWhitespaceOnlySecretKey_throwsError() {
        // Given
        let account = createTestAccount()

        // When & Then
        XCTAssertThrowsError(try accountManager.saveAccount(account, secretAccessKey: "   ")) { error in
            guard let managerError = error as? R2AccountManager.AccountManagerError else {
                XCTFail("Expected AccountManagerError")
                return
            }
            XCTAssertEqual(managerError, .invalidSecretKey)
        }
    }

    func testSaveAccount_asFirstAccount_setsAsCurrentAccount() throws {
        // Given - 确保没有当前账户
        accountManager.setCurrentAccount(nil)
        let account = createTestAccount()

        // When
        try accountManager.saveAccount(account, secretAccessKey: "test-secret")
        testAccounts.append(account)

        // Then
        XCTAssertNotNil(accountManager.currentAccount)
    }

    // MARK: - deleteAccount Tests

    func testDeleteAccount_removesFromAccounts() throws {
        // Given
        let account = createTestAccount()
        try accountManager.saveAccount(account, secretAccessKey: "test-secret")
        XCTAssertTrue(accountManager.accounts.contains(where: { $0.accountID == account.accountID }))

        // When
        try accountManager.deleteAccount(account)

        // Then
        XCTAssertFalse(accountManager.accounts.contains(where: { $0.accountID == account.accountID }))
    }

    func testDeleteAccount_removesSecretFromKeychain() throws {
        // Given
        let account = createTestAccount()
        try accountManager.saveAccount(account, secretAccessKey: "test-secret")
        XCTAssertTrue(keychainService.hasSecretAccessKey(for: account))

        // When
        try accountManager.deleteAccount(account)

        // Then
        XCTAssertFalse(keychainService.hasSecretAccessKey(for: account))
    }

    func testDeleteAccount_clearsCurrentAccountIfDeleted() throws {
        // Given
        let account = createTestAccount()
        try accountManager.saveAccount(account, secretAccessKey: "test-secret")
        accountManager.setCurrentAccount(account)
        testAccounts.append(account)

        // When
        try accountManager.deleteAccount(account)
        testAccounts.removeAll { $0.id == account.id }

        // Then
        // 当前账户应该被清空或者切换到其他账户
        if accountManager.accounts.isEmpty {
            XCTAssertNil(accountManager.currentAccount)
        }
    }

    // MARK: - getCompleteCredentials Tests

    func testGetCompleteCredentials_returnsCredentialsWithSecretKey() throws {
        // Given
        let account = createTestAccount()
        let secretKey = "my-secret-access-key"
        try accountManager.saveAccount(account, secretAccessKey: secretKey)
        testAccounts.append(account)

        // When
        let credentials = try accountManager.getCompleteCredentials(for: account)

        // Then
        XCTAssertEqual(credentials.account.accountID, account.accountID)
        XCTAssertEqual(credentials.secretAccessKey, secretKey)
        XCTAssertTrue(credentials.isValid)
    }

    func testGetCompleteCredentials_throwsForNonExistentAccount() {
        // Given
        let nonExistentAccount = createTestAccount()

        // When & Then
        XCTAssertThrowsError(try accountManager.getCompleteCredentials(for: nonExistentAccount))
    }

    // MARK: - setCurrentAccount Tests

    func testSetCurrentAccount_updatesCurrentAccount() throws {
        // Given
        let account = createTestAccount()
        try accountManager.saveAccount(account, secretAccessKey: "test-secret")
        testAccounts.append(account)

        // When
        accountManager.setCurrentAccount(account)

        // Then
        XCTAssertEqual(accountManager.currentAccount?.id, account.id)
    }

    func testSetCurrentAccount_withNil_clearsCurrentAccount() throws {
        // Given
        let account = createTestAccount()
        try accountManager.saveAccount(account, secretAccessKey: "test-secret")
        testAccounts.append(account)
        accountManager.setCurrentAccount(account)
        XCTAssertNotNil(accountManager.currentAccount)

        // When
        accountManager.setCurrentAccount(nil)

        // Then
        XCTAssertNil(accountManager.currentAccount)
    }

    // MARK: - validateAccount Tests

    func testValidateAccount_withValidAccountAndKeychain_returnsTrue() throws {
        // Given
        let account = createTestAccount()
        try accountManager.saveAccount(account, secretAccessKey: "test-secret")
        testAccounts.append(account)

        // When
        let isValid = accountManager.validateAccount(account)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidateAccount_withInvalidAccount_returnsFalse() {
        // Given
        let invalidAccount = R2Account(
            accountID: "",
            accessKeyID: "AKIATEST"
        )

        // When
        let isValid = accountManager.validateAccount(invalidAccount)

        // Then
        XCTAssertFalse(isValid)
    }

    func testValidateAccount_withoutKeychainEntry_returnsFalse() {
        // Given - 有效账户但没有保存到 Keychain
        let account = createTestAccount()

        // When
        let isValid = accountManager.validateAccount(account)

        // Then
        XCTAssertFalse(isValid)
    }

    // MARK: - loadAccounts Tests

    func testLoadAccounts_setsIsLoadingDuringLoad() {
        // Given
        let manager = R2AccountManager.shared

        // When
        manager.loadAccounts()

        // Then - 加载完成后 isLoading 应该为 false
        XCTAssertFalse(manager.isLoading)
    }

    func testLoadAccounts_clearsErrorMessage() {
        // Given
        let manager = R2AccountManager.shared

        // When
        manager.loadAccounts()

        // Then
        XCTAssertNil(manager.errorMessage)
    }

    // MARK: - Update Existing Account Tests

    func testSaveAccount_withExistingAccount_updatesInsteadOfAdding() throws {
        // Given
        let account = createTestAccount()
        try accountManager.saveAccount(account, secretAccessKey: "original-secret")
        testAccounts.append(account)
        let countAfterFirstSave = accountManager.accounts.count

        // When - 使用相同的 accountID 和 accessKeyID 保存
        let updatedAccount = R2Account(
            accountID: account.accountID,
            accessKeyID: account.accessKeyID,
            displayName: "Updated Name"
        )
        try accountManager.saveAccount(updatedAccount, secretAccessKey: "new-secret")

        // Then - 数量不应该增加
        XCTAssertEqual(accountManager.accounts.count, countAfterFirstSave)
    }

    // MARK: - Bucket Management Tests

    func testAddBucket_addsTrimmedBucketToAccount() throws {
        // Given
        let account = createTestAccount()
        try accountManager.saveAccount(account, secretAccessKey: "test-secret")
        testAccounts.append(account)
        accountManager.setCurrentAccount(account)

        // When
        try accountManager.addBucket(to: account, bucketName: "  my-bucket  ")

        // Then
        let updated = accountManager.accounts.first { $0.id == account.id }
        XCTAssertEqual(updated?.bucketNames, ["my-bucket"])
        XCTAssertEqual(accountManager.currentAccount?.bucketNames, ["my-bucket"])
    }

    func testRemoveBucket_removesBucketFromAccount() throws {
        // Given
        let account = createTestAccount()
        try accountManager.saveAccount(account, secretAccessKey: "test-secret")
        testAccounts.append(account)
        try accountManager.addBucket(to: account, bucketName: "bucket-to-remove")

        // When
        try accountManager.removeBucket(from: account, bucketName: "bucket-to-remove")

        // Then
        let updated = accountManager.accounts.first { $0.id == account.id }
        XCTAssertTrue(updated?.bucketNames.isEmpty ?? false)
    }

    // MARK: - Helper Methods

    private func createTestAccount() -> R2Account {
        return R2Account(
            accountID: "test-\(UUID().uuidString.prefix(8))",
            accessKeyID: "AKIATEST\(UUID().uuidString.prefix(8))",
            displayName: "Test Account"
        )
    }
}
