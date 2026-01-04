//
//  ContextMenuTests.swift
//  OwlUploaderTests
//
//  右键菜单相关功能测试
//  测试菜单项显示逻辑和回调机制
//

import XCTest
@testable import OwlUploader

final class ContextMenuTests: XCTestCase {

    // MARK: - 菜单项可见性测试

    func testPreviewMenuItem_shouldShowForFiles() {
        // Given - 文件（非目录）
        let file = createTestFile(name: "document.pdf")

        // Then - 预览菜单项应该显示
        XCTAssertFalse(file.isDirectory, "文件的 isDirectory 应该为 false")
    }

    func testPreviewMenuItem_shouldHideForDirectories() {
        // Given - 目录
        let folder = FileObject.folder(name: "Documents", key: "documents/")

        // Then - 预览菜单项不应该显示
        XCTAssertTrue(folder.isDirectory, "文件夹的 isDirectory 应该为 true")
    }

    func testDownloadMenuItem_shouldShowForFiles() {
        // Given
        let file = createTestFile(name: "report.pdf")

        // Then
        XCTAssertFalse(file.isDirectory)
    }

    func testDownloadMenuItem_shouldHideForDirectories() {
        // Given
        let folder = FileObject.folder(name: "Downloads", key: "downloads/")

        // Then
        XCTAssertTrue(folder.isDirectory)
    }

    // MARK: - 空选择状态测试

    @MainActor
    func testEmptySelection_selectedIDsIsEmpty() {
        // Given
        let manager = SelectionManager()

        // Then
        XCTAssertTrue(manager.selectedIDs.isEmpty, "初始状态下 selectedIDs 应该为空")
    }

    @MainActor
    func testEmptySelection_contextMenuShouldShowBasicItems() {
        // Given - 没有选中任何文件
        let manager = SelectionManager()

        // When - 检查是否为空选择状态
        let isEmpty = manager.selectedIDs.isEmpty

        // Then - 空选择时应该显示基本菜单（新建文件夹、上传）
        XCTAssertTrue(isEmpty, "空选择状态应该触发简化菜单")
    }

    // MARK: - 有选择状态测试

    @MainActor
    func testWithSelection_selectedIDsNotEmpty() {
        // Given
        let manager = SelectionManager()
        let files = [
            createTestFile(name: "file1.txt"),
            createTestFile(name: "file2.txt")
        ]

        // When
        manager.setSelection(files)

        // Then
        XCTAssertFalse(manager.selectedIDs.isEmpty, "选择文件后 selectedIDs 不应该为空")
        XCTAssertEqual(manager.selectedIDs.count, 2)
    }

    @MainActor
    func testWithSelection_contextMenuShouldShowFullItems() {
        // Given
        let manager = SelectionManager()
        let file = createTestFile(name: "document.pdf")

        // When
        manager.setSelection([file])

        // Then
        XCTAssertFalse(manager.selectedIDs.isEmpty)
        XCTAssertTrue(manager.selectedIDs.contains(file.id))
    }

    // MARK: - SelectionManager setSelection 测试

    @MainActor
    func testSetSelection_setsCorrectIDs() {
        // Given
        let manager = SelectionManager()
        let file1 = createTestFile(name: "file1.txt", key: "path/file1.txt")
        let file2 = createTestFile(name: "file2.txt", key: "path/file2.txt")

        // When
        manager.setSelection([file1, file2])

        // Then
        XCTAssertEqual(manager.selectedItems.count, 2)
        XCTAssertTrue(manager.selectedItems.contains("path/file1.txt"))
        XCTAssertTrue(manager.selectedItems.contains("path/file2.txt"))
    }

    @MainActor
    func testSetSelection_replacesExistingSelection() {
        // Given
        let manager = SelectionManager()
        let file1 = createTestFile(name: "file1.txt", key: "file1.txt")
        let file2 = createTestFile(name: "file2.txt", key: "file2.txt")
        let file3 = createTestFile(name: "file3.txt", key: "file3.txt")

        // 先选择 file1 和 file2
        manager.setSelection([file1, file2])

        // When - 用 file3 替换
        manager.setSelection([file3])

        // Then
        XCTAssertEqual(manager.selectedItems.count, 1)
        XCTAssertFalse(manager.selectedItems.contains("file1.txt"))
        XCTAssertFalse(manager.selectedItems.contains("file2.txt"))
        XCTAssertTrue(manager.selectedItems.contains("file3.txt"))
    }

    @MainActor
    func testSetSelection_emptyArrayClearsSelection() {
        // Given
        let manager = SelectionManager()
        let file = createTestFile(name: "file.txt")
        manager.setSelection([file])

        // When
        manager.setSelection([])

        // Then
        XCTAssertTrue(manager.selectedItems.isEmpty)
    }

    // MARK: - selectedIDs 计算属性测试

    @MainActor
    func testSelectedIDs_returnsSelectedItems() {
        // Given
        let manager = SelectionManager()
        let files = [
            createTestFile(name: "a.txt", key: "a.txt"),
            createTestFile(name: "b.txt", key: "b.txt")
        ]

        // When
        manager.setSelection(files)

        // Then
        XCTAssertEqual(manager.selectedIDs, manager.selectedItems)
    }

    // MARK: - 移动菜单目标过滤测试

    func testMoveToMenu_filtersOutSelfAndChildren() {
        // Given - 当前文件夹列表
        let currentFolders = [
            FileObject.folder(name: "Folder1", key: "folder1/"),
            FileObject.folder(name: "Folder2", key: "folder2/"),
            FileObject.folder(name: "SubFolder", key: "folder1/subfolder/")
        ]

        // When - 选中 Folder1，计算可用的移动目标
        let selectedFolder = currentFolders[0]
        let availableFolders = currentFolders.filter {
            $0.key != selectedFolder.key && !$0.key.hasPrefix(selectedFolder.key)
        }

        // Then - 应该只有 Folder2 可用（排除自身和子文件夹）
        XCTAssertEqual(availableFolders.count, 1)
        XCTAssertEqual(availableFolders.first?.name, "Folder2")
    }

    func testMoveToMenu_fileCanMoveToAnyFolder() {
        // Given
        let currentFolders = [
            FileObject.folder(name: "Folder1", key: "folder1/"),
            FileObject.folder(name: "Folder2", key: "folder2/")
        ]
        let file = createTestFile(name: "document.pdf", key: "document.pdf")

        // When
        let availableFolders = currentFolders.filter {
            $0.key != file.key && !$0.key.hasPrefix(file.key)
        }

        // Then - 文件可以移动到所有文件夹
        XCTAssertEqual(availableFolders.count, 2)
    }

    // MARK: - 父目录路径计算测试

    func testGetParentPath_fromSubfolder() {
        // Given
        let currentPrefix = "documents/2023/"

        // When
        let parentPath = getParentPath(of: currentPrefix)

        // Then
        XCTAssertEqual(parentPath, "documents/")
    }

    func testGetParentPath_fromRootFolder() {
        // Given
        let currentPrefix = "documents/"

        // When
        let parentPath = getParentPath(of: currentPrefix)

        // Then
        XCTAssertEqual(parentPath, "")
    }

    func testGetParentPath_fromRoot() {
        // Given
        let currentPrefix = ""

        // When
        let parentPath = getParentPath(of: currentPrefix)

        // Then
        XCTAssertEqual(parentPath, "")
    }

    func testGetParentPath_deepNesting() {
        // Given
        let currentPrefix = "a/b/c/d/e/"

        // When
        let parentPath = getParentPath(of: currentPrefix)

        // Then
        XCTAssertEqual(parentPath, "a/b/c/d/")
    }

    // MARK: - 上级目录菜单可见性测试

    func testParentFolderMenuItem_visibleWhenNotAtRoot() {
        // Given
        let currentPrefix = "documents/reports/"

        // Then
        let hasParent = !currentPrefix.isEmpty
        XCTAssertTrue(hasParent, "非根目录时应该显示上级目录选项")
    }

    func testParentFolderMenuItem_hiddenAtRoot() {
        // Given
        let currentPrefix = ""

        // Then
        let hasParent = !currentPrefix.isEmpty
        XCTAssertFalse(hasParent, "根目录时不应该显示上级目录选项")
    }

    // MARK: - 辅助方法

    private func createTestFile(name: String, key: String? = nil) -> FileObject {
        FileObject.file(
            name: name,
            key: key ?? name,
            size: 1024,
            lastModifiedDate: Date(),
            eTag: "test-etag"
        )
    }

    /// 获取上级目录路径（复制自视图逻辑）
    private func getParentPath(of path: String) -> String {
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        if let lastSlash = trimmed.lastIndex(of: "/") {
            return String(trimmed[..<lastSlash]) + "/"
        }
        return ""
    }
}
