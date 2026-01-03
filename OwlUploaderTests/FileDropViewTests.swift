//
//  FileDropViewTests.swift
//  OwlUploaderTests
//
//  FileDropView 单元测试
//  测试文件拖拽、文件夹处理和验证逻辑
//

import XCTest
@testable import OwlUploader

final class FileDropViewTests: XCTestCase {

    // MARK: - 测试辅助属性

    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // 创建临时测试目录
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileDropViewTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // 清理临时目录
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    // MARK: - 文件名验证测试

    func testValidFileName_normalFileName_returnsTrue() {
        // Given
        let validNames = ["test.txt", "photo.jpg", "document.pdf", "file_name.png", "file-name.doc"]

        // Then
        for name in validNames {
            XCTAssertTrue(isValidFileName(name), "Expected '\(name)' to be valid")
        }
    }

    func testValidFileName_hiddenFile_returnsFalse() {
        // Given
        let hiddenFiles = [".DS_Store", ".gitignore", ".hidden"]

        // Then
        for name in hiddenFiles {
            XCTAssertFalse(isValidFileName(name), "Expected '\(name)' to be invalid (hidden file)")
        }
    }

    func testValidFileName_emptyName_returnsFalse() {
        // Given
        let emptyNames = ["", "   ", "\t", "\n"]

        // Then
        for name in emptyNames {
            XCTAssertFalse(isValidFileName(name), "Expected empty/whitespace name to be invalid")
        }
    }

    func testValidFileName_illegalCharacters_returnsFalse() {
        // Given
        let illegalNames = ["file<name.txt", "file>name.txt", "file:name.txt",
                           "file\"name.txt", "file|name.txt", "file?name.txt", "file*name.txt"]

        // Then
        for name in illegalNames {
            XCTAssertFalse(isValidFileName(name), "Expected '\(name)' to be invalid (illegal characters)")
        }
    }

    func testValidFileName_windowsReservedNames_returnsFalse() {
        // Given
        let reservedNames = ["CON", "PRN", "AUX", "NUL",
                            "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
                            "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
                            "CON.txt", "PRN.doc", "AUX.pdf"]

        // Then
        for name in reservedNames {
            XCTAssertFalse(isValidFileName(name), "Expected '\(name)' to be invalid (Windows reserved)")
        }
    }

    func testValidFileName_chineseFileName_returnsTrue() {
        // Given
        let chineseNames = ["文档.txt", "照片_2024.jpg", "测试文件.pdf"]

        // Then
        for name in chineseNames {
            XCTAssertTrue(isValidFileName(name), "Expected '\(name)' to be valid")
        }
    }

    // MARK: - 文件夹递归收集测试

    func testCollectFilesFromFolder_emptyFolder_returnsEmptyArray() throws {
        // Given
        let emptyFolder = tempDirectory.appendingPathComponent("empty_folder")
        try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true)

        // When
        let files = collectFilesFromFolder(emptyFolder)

        // Then
        XCTAssertTrue(files.isEmpty)
    }

    func testCollectFilesFromFolder_withFiles_returnsAllFiles() throws {
        // Given
        let folder = tempDirectory.appendingPathComponent("test_folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // 创建测试文件
        let file1 = folder.appendingPathComponent("file1.txt")
        let file2 = folder.appendingPathComponent("file2.jpg")
        try "test content 1".write(to: file1, atomically: true, encoding: .utf8)
        try "test content 2".write(to: file2, atomically: true, encoding: .utf8)

        // When
        let files = collectFilesFromFolder(folder)

        // Then
        XCTAssertEqual(files.count, 2)
        XCTAssertTrue(files.contains(file1))
        XCTAssertTrue(files.contains(file2))
    }

    func testCollectFilesFromFolder_withSubfolders_returnsAllFilesRecursively() throws {
        // Given
        let folder = tempDirectory.appendingPathComponent("nested_folder")
        let subfolder = folder.appendingPathComponent("subfolder")
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)

        // 创建测试文件
        let file1 = folder.appendingPathComponent("root_file.txt")
        let file2 = subfolder.appendingPathComponent("nested_file.txt")
        try "root content".write(to: file1, atomically: true, encoding: .utf8)
        try "nested content".write(to: file2, atomically: true, encoding: .utf8)

        // When
        let files = collectFilesFromFolder(folder)

        // Then
        XCTAssertEqual(files.count, 2)
        XCTAssertTrue(files.contains(file1))
        XCTAssertTrue(files.contains(file2))
    }

    func testCollectFilesFromFolder_skipsHiddenFiles() throws {
        // Given
        let folder = tempDirectory.appendingPathComponent("hidden_test")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // 创建正常文件和隐藏文件
        let normalFile = folder.appendingPathComponent("normal.txt")
        let hiddenFile = folder.appendingPathComponent(".hidden")
        try "normal".write(to: normalFile, atomically: true, encoding: .utf8)
        try "hidden".write(to: hiddenFile, atomically: true, encoding: .utf8)

        // When
        let files = collectFilesFromFolder(folder)

        // Then
        XCTAssertEqual(files.count, 1)
        XCTAssertTrue(files.contains(normalFile))
        XCTAssertFalse(files.contains(hiddenFile))
    }

    func testCollectFilesFromFolder_skipsEmptyFiles() throws {
        // Given
        let folder = tempDirectory.appendingPathComponent("empty_file_test")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // 创建正常文件和空文件
        let normalFile = folder.appendingPathComponent("normal.txt")
        let emptyFile = folder.appendingPathComponent("empty.txt")
        try "content".write(to: normalFile, atomically: true, encoding: .utf8)
        try "".write(to: emptyFile, atomically: true, encoding: .utf8)

        // When
        let files = collectFilesFromFolder(folder)

        // Then
        XCTAssertEqual(files.count, 1)
        XCTAssertTrue(files.contains(normalFile))
    }

    // MARK: - 相对路径计算测试

    func testRelativePathCalculation_preservesDirectoryStructure() {
        // Given
        let baseFolder = URL(fileURLWithPath: "/Users/test/Documents/MyFolder")
        let filePath = URL(fileURLWithPath: "/Users/test/Documents/MyFolder/subfolder/file.txt")
        let currentPrefix = "uploads/"

        // When
        let basePath = baseFolder.deletingLastPathComponent().path
        let relativePath = filePath.path.replacingOccurrences(of: basePath + "/", with: "")
        let remotePath = currentPrefix.isEmpty ? relativePath : "\(currentPrefix)\(relativePath)"

        // Then
        XCTAssertEqual(relativePath, "MyFolder/subfolder/file.txt")
        XCTAssertEqual(remotePath, "uploads/MyFolder/subfolder/file.txt")
    }

    func testRelativePathCalculation_withEmptyPrefix() {
        // Given
        let baseFolder = URL(fileURLWithPath: "/Users/test/Downloads/Photos")
        let filePath = URL(fileURLWithPath: "/Users/test/Downloads/Photos/2024/image.jpg")
        let currentPrefix = ""

        // When
        let basePath = baseFolder.deletingLastPathComponent().path
        let relativePath = filePath.path.replacingOccurrences(of: basePath + "/", with: "")
        let remotePath = currentPrefix.isEmpty ? relativePath : "\(currentPrefix)\(relativePath)"

        // Then
        XCTAssertEqual(relativePath, "Photos/2024/image.jpg")
        XCTAssertEqual(remotePath, "Photos/2024/image.jpg")
    }

    // MARK: - 辅助方法（模拟 FileDropNSView 的私有方法）

    /// 验证文件名是否有效（复制自 FileDropNSView）
    private func isValidFileName(_ fileName: String) -> Bool {
        let trimmedName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)

        // 检查文件名不为空
        guard !trimmedName.isEmpty else { return false }

        // 检查不是隐藏文件（以.开头）
        guard !trimmedName.hasPrefix(".") else { return false }

        // 检查不包含非法字符
        let illegalCharacters = CharacterSet(charactersIn: "/<>:\"\\|?*")
        guard trimmedName.rangeOfCharacter(from: illegalCharacters) == nil else { return false }

        // 检查不是系统保留名称
        let reservedNames = ["CON", "PRN", "AUX", "NUL",
                            "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
                            "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]
        let nameWithoutExtension = URL(fileURLWithPath: trimmedName).deletingPathExtension().lastPathComponent.uppercased()
        guard !reservedNames.contains(nameWithoutExtension) else { return false }

        return true
    }

    /// 递归收集文件夹中的所有文件（复制自 FileDropNSView）
    private func collectFilesFromFolder(_ folderURL: URL) -> [URL] {
        var files: [URL] = []
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return files
        }

        while let fileURL = enumerator.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey])

                // 只收集文件，跳过子目录
                guard resourceValues.isRegularFile == true else { continue }

                // 检查文件大小
                let fileSize = resourceValues.fileSize ?? 0
                guard fileSize > 0, fileSize <= 5 * 1024 * 1024 * 1024 else { continue }

                // 验证文件名
                guard isValidFileName(fileURL.lastPathComponent) else { continue }

                files.append(fileURL)

            } catch {
                // 跳过无法获取属性的文件
            }
        }

        return files
    }
}
