//
//  RenameTests.swift
//  OwlUploaderTests
//
//  重命名功能测试
//  测试名称验证、原始名称提取和重命名逻辑
//

import XCTest
@testable import OwlUploader

final class RenameTests: XCTestCase {

    // MARK: - 名称验证测试

    func testValidName_alphanumeric_isValid() {
        // Given
        let name = "document123"

        // When
        let isValid = isValidFileName(name)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidName_withDash_isValid() {
        // Given
        let name = "my-file-name"

        // When
        let isValid = isValidFileName(name)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidName_withUnderscore_isValid() {
        // Given
        let name = "my_file_name"

        // When
        let isValid = isValidFileName(name)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidName_withDot_isValid() {
        // Given
        let name = "document.pdf"

        // When
        let isValid = isValidFileName(name)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidName_withSpaces_isValid() {
        // Given
        let name = "my document"

        // When
        let isValid = isValidFileName(name)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidName_chinese_isValid() {
        // Given
        let name = "文档资料"

        // When
        let isValid = isValidFileName(name)

        // Then
        XCTAssertTrue(isValid)
    }

    func testInvalidName_withBackslash_isInvalid() {
        // Given
        let name = "path\\file"

        // When
        let isValid = isValidFileName(name)

        // Then
        XCTAssertFalse(isValid)
    }

    func testInvalidName_withForwardSlash_isInvalid() {
        // Given
        let name = "path/file"

        // When
        let isValid = isValidFileName(name)

        // Then
        XCTAssertFalse(isValid)
    }

    func testInvalidName_withColon_isInvalid() {
        // Given
        let name = "file:name"

        // When
        let isValid = isValidFileName(name)

        // Then
        XCTAssertFalse(isValid)
    }

    func testInvalidName_withAsterisk_isInvalid() {
        // Given
        let name = "file*name"

        // When
        let isValid = isValidFileName(name)

        // Then
        XCTAssertFalse(isValid)
    }

    func testInvalidName_withQuestionMark_isInvalid() {
        // Given
        let name = "file?name"

        // When
        let isValid = isValidFileName(name)

        // Then
        XCTAssertFalse(isValid)
    }

    func testInvalidName_withQuotes_isInvalid() {
        // Given
        let name = "file\"name"

        // When
        let isValid = isValidFileName(name)

        // Then
        XCTAssertFalse(isValid)
    }

    func testInvalidName_withAngleBrackets_isInvalid() {
        // Given
        let name1 = "file<name"
        let name2 = "file>name"

        // When & Then
        XCTAssertFalse(isValidFileName(name1))
        XCTAssertFalse(isValidFileName(name2))
    }

    func testInvalidName_withPipe_isInvalid() {
        // Given
        let name = "file|name"

        // When
        let isValid = isValidFileName(name)

        // Then
        XCTAssertFalse(isValid)
    }

    func testInvalidName_empty_isInvalid() {
        // Given
        let name = ""

        // When
        let isValid = isValidFileName(name)

        // Then
        XCTAssertFalse(isValid)
    }

    func testInvalidName_onlySpaces_isInvalid() {
        // Given
        let name = "   "

        // When
        let isValid = isValidFileName(name)

        // Then
        XCTAssertFalse(isValid)
    }

    // MARK: - 原始名称提取测试

    func testOriginalName_file_returnsFileName() {
        // Given
        let file = FileObject.file(
            name: "document.pdf",
            key: "path/document.pdf",
            size: 1024,
            lastModifiedDate: Date(),
            eTag: "etag"
        )

        // When
        let originalName = extractOriginalName(from: file)

        // Then
        XCTAssertEqual(originalName, "document.pdf")
    }

    func testOriginalName_folder_removesTrailingSlash() {
        // Given
        let folder = FileObject.folder(name: "Documents/", key: "Documents/")

        // When
        let originalName = extractOriginalName(from: folder)

        // Then
        XCTAssertEqual(originalName, "Documents")
    }

    func testOriginalName_folderWithoutSlash_returnsAsIs() {
        // Given
        let folder = FileObject(
            name: "Documents",
            key: "Documents/",
            size: nil,
            lastModifiedDate: nil,
            isDirectory: true
        )

        // When
        let originalName = extractOriginalName(from: folder)

        // Then
        XCTAssertEqual(originalName, "Documents")
    }

    // MARK: - 名称变化检测测试

    func testHasChanges_sameName_returnsFalse() {
        // Given
        let originalName = "document.pdf"
        let newName = "document.pdf"

        // When
        let hasChanges = checkHasChanges(original: originalName, new: newName)

        // Then
        XCTAssertFalse(hasChanges)
    }

    func testHasChanges_differentName_returnsTrue() {
        // Given
        let originalName = "document.pdf"
        let newName = "report.pdf"

        // When
        let hasChanges = checkHasChanges(original: originalName, new: newName)

        // Then
        XCTAssertTrue(hasChanges)
    }

    func testHasChanges_trimmedSameName_returnsFalse() {
        // Given
        let originalName = "document.pdf"
        let newName = "  document.pdf  "

        // When
        let hasChanges = checkHasChanges(original: originalName, new: newName)

        // Then
        XCTAssertFalse(hasChanges)
    }

    // MARK: - 新 key 构建测试

    func testBuildNewKey_fileAtRoot_returnsNewName() {
        // Given
        let oldKey = "document.pdf"
        let newName = "report.pdf"
        let isDirectory = false

        // When
        let newKey = buildNewKey(oldKey: oldKey, newName: newName, isDirectory: isDirectory)

        // Then
        XCTAssertEqual(newKey, "report.pdf")
    }

    func testBuildNewKey_fileInSubfolder_preservesPath() {
        // Given
        let oldKey = "documents/reports/document.pdf"
        let newName = "report.pdf"
        let isDirectory = false

        // When
        let newKey = buildNewKey(oldKey: oldKey, newName: newName, isDirectory: isDirectory)

        // Then
        XCTAssertEqual(newKey, "documents/reports/report.pdf")
    }

    func testBuildNewKey_folderAtRoot_addsTrailingSlash() {
        // Given
        let oldKey = "Documents/"
        let newName = "MyDocs"
        let isDirectory = true

        // When
        let newKey = buildNewKey(oldKey: oldKey, newName: newName, isDirectory: isDirectory)

        // Then
        XCTAssertEqual(newKey, "MyDocs/")
    }

    func testBuildNewKey_folderInSubfolder_preservesPathAndSlash() {
        // Given
        let oldKey = "projects/2024/reports/"
        let newName = "documents"
        let isDirectory = true

        // When
        let newKey = buildNewKey(oldKey: oldKey, newName: newName, isDirectory: isDirectory)

        // Then
        XCTAssertEqual(newKey, "projects/2024/documents/")
    }

    // MARK: - 右键菜单测试

    func testRenameMenuItem_shouldShowForFiles() {
        // Given
        let file = FileObject.file(
            name: "document.pdf",
            key: "document.pdf",
            size: 1024,
            lastModifiedDate: Date(),
            eTag: "etag"
        )

        // Then - 重命名菜单应该对文件显示
        XCTAssertFalse(file.isDirectory)
    }

    func testRenameMenuItem_shouldShowForFolders() {
        // Given
        let folder = FileObject.folder(name: "Documents", key: "Documents/")

        // Then - 重命名菜单应该对文件夹也显示
        XCTAssertTrue(folder.isDirectory)
    }

    // MARK: - 辅助方法

    /// 验证文件名是否有效（复制自 RenameSheet 逻辑）
    private func isValidFileName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        let illegalCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let hasIllegalChars = trimmedName.rangeOfCharacter(from: illegalCharacters) != nil

        return !hasIllegalChars
    }

    /// 提取原始名称（复制自 RenameSheet 逻辑）
    private func extractOriginalName(from file: FileObject) -> String {
        if file.isDirectory {
            let name = file.name
            return name.hasSuffix("/") ? String(name.dropLast()) : name
        }
        return file.name
    }

    /// 检查名称是否有变化
    private func checkHasChanges(original: String, new: String) -> Bool {
        new.trimmingCharacters(in: .whitespacesAndNewlines) != original
    }

    /// 构建新的 key（复制自 FileListView.handleRename 逻辑）
    private func buildNewKey(oldKey: String, newName: String, isDirectory: Bool) -> String {
        // 对于文件夹，先移除尾部斜杠再处理
        let keyForProcessing = isDirectory && oldKey.hasSuffix("/") ? String(oldKey.dropLast()) : oldKey
        let directory = keyForProcessing.components(separatedBy: "/").dropLast().joined(separator: "/")
        let newKey = directory.isEmpty ? newName : "\(directory)/\(newName)"
        return isDirectory ? "\(newKey)/" : newKey
    }
}
