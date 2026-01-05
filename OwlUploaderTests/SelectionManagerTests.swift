//
//  SelectionManagerTests.swift
//  OwlUploaderTests
//
//  SelectionManager 单元测试
//  测试选择状态管理、批量操作和修饰键处理
//

import XCTest
@testable import OwlUploader

final class SelectionManagerTests: XCTestCase {

    // MARK: - 初始状态测试

    @MainActor
    func testInitialState_noSelection() {
        // Given
        let manager = SelectionManager()

        // Then
        XCTAssertTrue(manager.selectedItems.isEmpty)
        XCTAssertEqual(manager.selectedCount, 0)
        XCTAssertFalse(manager.hasSelection)
    }

    // MARK: - 单选测试

    @MainActor
    func testSelect_singleFile_selectsFile() {
        // Given
        let manager = SelectionManager()
        let file = createTestFileObject(key: "file1.txt")

        // When
        manager.select(file, mode: .single, allFiles: [file])

        // Then
        XCTAssertTrue(manager.isSelected(file))
        XCTAssertEqual(manager.selectedCount, 1)
    }

    @MainActor
    func testSelect_differentFile_replacesSelection() {
        // Given
        let manager = SelectionManager()
        let file1 = createTestFileObject(key: "file1.txt")
        let file2 = createTestFileObject(key: "file2.txt")
        let allFiles = [file1, file2]

        // When
        manager.select(file1, mode: .single, allFiles: allFiles)
        manager.select(file2, mode: .single, allFiles: allFiles)

        // Then
        XCTAssertFalse(manager.isSelected(file1))
        XCTAssertTrue(manager.isSelected(file2))
        XCTAssertEqual(manager.selectedCount, 1)
    }

    @MainActor
    func testSelect_singleSameItem_clearsSelection() {
        // Given
        let manager = SelectionManager()
        let file = createTestFileObject(key: "file1.txt")

        // When
        manager.select(file, mode: .single, allFiles: [file])
        manager.select(file, mode: .single, allFiles: [file])

        // Then
        XCTAssertTrue(manager.selectedItems.isEmpty)
        XCTAssertFalse(manager.hasSelection)
    }

    // MARK: - 多选测试 (Cmd+Click)

    @MainActor
    func testSelect_toggle_addsToSelection() {
        // Given
        let manager = SelectionManager()
        let file1 = createTestFileObject(key: "file1.txt")
        let file2 = createTestFileObject(key: "file2.txt")
        let allFiles = [file1, file2]

        // When
        manager.select(file1, mode: .single, allFiles: allFiles)
        manager.select(file2, mode: .toggle, allFiles: allFiles)

        // Then
        XCTAssertTrue(manager.isSelected(file1))
        XCTAssertTrue(manager.isSelected(file2))
        XCTAssertEqual(manager.selectedCount, 2)
    }

    @MainActor
    func testSelect_toggle_removesFromSelection() {
        // Given
        let manager = SelectionManager()
        let file1 = createTestFileObject(key: "file1.txt")
        let file2 = createTestFileObject(key: "file2.txt")
        let allFiles = [file1, file2]

        // 先选择两个文件
        manager.select(file1, mode: .single, allFiles: allFiles)
        manager.select(file2, mode: .toggle, allFiles: allFiles)

        // When - 再次 toggle 第一个文件
        manager.select(file1, mode: .toggle, allFiles: allFiles)

        // Then
        XCTAssertFalse(manager.isSelected(file1))
        XCTAssertTrue(manager.isSelected(file2))
        XCTAssertEqual(manager.selectedCount, 1)
    }

    // MARK: - 添加选择测试

    @MainActor
    func testSelect_additive_addsWithoutClearing() {
        // Given
        let manager = SelectionManager()
        let file1 = createTestFileObject(key: "file1.txt")
        let file2 = createTestFileObject(key: "file2.txt")
        let allFiles = [file1, file2]

        // When
        manager.select(file1, mode: .single, allFiles: allFiles)
        manager.select(file2, mode: .additive, allFiles: allFiles)

        // Then
        XCTAssertTrue(manager.isSelected(file1))
        XCTAssertTrue(manager.isSelected(file2))
        XCTAssertEqual(manager.selectedCount, 2)
    }

    // MARK: - 范围选择测试 (Shift+Click)

    @MainActor
    func testSelect_range_selectsFilesBetween() {
        // Given
        let manager = SelectionManager()
        let files = (1...5).map { createTestFileObject(key: "file\($0).txt") }

        // When - 先选择第一个，然后 shift+click 第五个
        manager.select(files[0], mode: .single, allFiles: files)
        manager.select(files[4], mode: .range, allFiles: files)

        // Then - 应该选中 1-5
        XCTAssertEqual(manager.selectedCount, 5)
        for file in files {
            XCTAssertTrue(manager.isSelected(file), "File \(file.key) should be selected")
        }
    }

    @MainActor
    func testSelect_range_selectsFilesInReverseOrder() {
        // Given
        let manager = SelectionManager()
        let files = (1...5).map { createTestFileObject(key: "file\($0).txt") }

        // When - 先选择第五个，然后 shift+click 第一个
        manager.select(files[4], mode: .single, allFiles: files)
        manager.select(files[0], mode: .range, allFiles: files)

        // Then - 应该选中 1-5
        XCTAssertEqual(manager.selectedCount, 5)
        for file in files {
            XCTAssertTrue(manager.isSelected(file), "File \(file.key) should be selected")
        }
    }

    @MainActor
    func testSelect_range_withPartialSelection() {
        // Given
        let manager = SelectionManager()
        let files = (1...5).map { createTestFileObject(key: "file\($0).txt") }

        // When - 选择第二个，然后 shift+click 第四个
        manager.select(files[1], mode: .single, allFiles: files)
        manager.select(files[3], mode: .range, allFiles: files)

        // Then - 应该选中 2-4 (索引1-3)
        XCTAssertEqual(manager.selectedCount, 3)
        XCTAssertFalse(manager.isSelected(files[0]))
        XCTAssertTrue(manager.isSelected(files[1]))
        XCTAssertTrue(manager.isSelected(files[2]))
        XCTAssertTrue(manager.isSelected(files[3]))
        XCTAssertFalse(manager.isSelected(files[4]))
    }

    // MARK: - 全选测试

    @MainActor
    func testSelectAll_selectsAllFiles() {
        // Given
        let manager = SelectionManager()
        let keys = ["file1.txt", "file2.txt", "file3.txt"]

        // When
        manager.selectAll(keys)

        // Then
        XCTAssertEqual(manager.selectedCount, 3)
        for key in keys {
            XCTAssertTrue(manager.selectedItems.contains(key))
        }
    }

    // MARK: - 反选与取消选择测试

    @MainActor
    func testInvertSelection_invertsSelectedKeys() {
        // Given
        let manager = SelectionManager()
        let keys = ["file1.txt", "file2.txt", "file3.txt"]
        manager.select("file1.txt", mode: .single, allKeys: keys)

        // When
        manager.invertSelection(keys)

        // Then
        XCTAssertFalse(manager.selectedItems.contains("file1.txt"))
        XCTAssertTrue(manager.selectedItems.contains("file2.txt"))
        XCTAssertTrue(manager.selectedItems.contains("file3.txt"))
        XCTAssertEqual(manager.selectedCount, 2)
    }

    @MainActor
    func testDeselect_removesSingleKey() {
        // Given
        let manager = SelectionManager()
        let keys = ["file1.txt", "file2.txt"]
        manager.selectAll(keys)

        // When
        manager.deselect("file1.txt")

        // Then
        XCTAssertFalse(manager.selectedItems.contains("file1.txt"))
        XCTAssertTrue(manager.selectedItems.contains("file2.txt"))
        XCTAssertEqual(manager.selectedCount, 1)
    }

    @MainActor
    func testDeselect_removesMultipleKeys() {
        // Given
        let manager = SelectionManager()
        let keys = ["file1.txt", "file2.txt", "file3.txt"]
        manager.selectAll(keys)

        // When
        manager.deselect(["file1.txt", "file3.txt"])

        // Then
        XCTAssertFalse(manager.selectedItems.contains("file1.txt"))
        XCTAssertTrue(manager.selectedItems.contains("file2.txt"))
        XCTAssertFalse(manager.selectedItems.contains("file3.txt"))
        XCTAssertEqual(manager.selectedCount, 1)
    }

    // MARK: - 清除选择测试

    @MainActor
    func testClearSelection_removesAllSelections() {
        // Given
        let manager = SelectionManager()
        let file1 = createTestFileObject(key: "file1.txt")
        let file2 = createTestFileObject(key: "file2.txt")
        manager.select(file1, mode: .single, allFiles: [file1, file2])
        manager.select(file2, mode: .toggle, allFiles: [file1, file2])

        // When
        manager.clearSelection()

        // Then
        XCTAssertTrue(manager.selectedItems.isEmpty)
        XCTAssertFalse(manager.hasSelection)
    }

    // MARK: - 获取选中键测试

    @MainActor
    func testGetSelectedKeys_returnsCorrectKeys() {
        // Given
        let manager = SelectionManager()
        let files = [
            createTestFileObject(key: "file1.txt"),
            createTestFileObject(key: "file2.txt"),
            createTestFileObject(key: "file3.txt")
        ]
        manager.select(files[0], mode: .single, allFiles: files)
        manager.select(files[2], mode: .toggle, allFiles: files)

        // When
        let selectedKeys = manager.getSelectedKeys()

        // Then
        XCTAssertEqual(selectedKeys.count, 2)
        XCTAssertTrue(selectedKeys.contains("file1.txt"))
        XCTAssertTrue(selectedKeys.contains("file3.txt"))
    }

    // MARK: - 修饰键映射测试

    @MainActor
    func testModeFromModifiers_noModifiers_returnsSingle() {
        // Given
        let modifiers: NSEvent.ModifierFlags = []

        // When
        let mode = SelectionManager.modeFromModifiers(modifiers)

        // Then
        XCTAssertEqual(mode, .single)
    }

    @MainActor
    func testModeFromModifiers_commandKey_returnsToggle() {
        // Given
        let modifiers: NSEvent.ModifierFlags = .command

        // When
        let mode = SelectionManager.modeFromModifiers(modifiers)

        // Then
        XCTAssertEqual(mode, .toggle)
    }

    @MainActor
    func testModeFromModifiers_shiftKey_returnsRange() {
        // Given
        let modifiers: NSEvent.ModifierFlags = .shift

        // When
        let mode = SelectionManager.modeFromModifiers(modifiers)

        // Then
        XCTAssertEqual(mode, .range)
    }

    @MainActor
    func testModeFromModifiers_bothKeys_returnsRange() {
        // Given - Shift 优先于 Command
        let modifiers: NSEvent.ModifierFlags = [.command, .shift]

        // When
        let mode = SelectionManager.modeFromModifiers(modifiers)

        // Then
        XCTAssertEqual(mode, .range)
    }

    // MARK: - 辅助方法

    private func createTestFileObject(
        key: String,
        isDirectory: Bool = false
    ) -> FileObject {
        FileObject(
            name: (key as NSString).lastPathComponent,
            key: key,
            size: 1024,
            lastModifiedDate: Date(),
            isDirectory: isDirectory,
            eTag: "test-etag"
        )
    }
}
