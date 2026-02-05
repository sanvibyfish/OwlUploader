//
//  FileTableSortTests.swift
//  OwlUploaderTests
//
//  FileTableView 排序映射逻辑单元测试
//  验证 FileSortOrder + ascending 与 KeyPathComparator 之间的双向映射
//

import XCTest
@testable import OwlUploader

final class FileTableSortTests: XCTestCase {

    // MARK: - comparators(from:ascending:) Tests

    func testComparators_name_ascending() {
        // When
        let result = FileTableView.comparators(from: .name, ascending: true)

        // Then
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.order, .forward)
        let keyPath = String(describing: result.first!.keyPath)
        XCTAssertTrue(keyPath.contains("name"))
    }

    func testComparators_name_descending() {
        // When
        let result = FileTableView.comparators(from: .name, ascending: false)

        // Then
        XCTAssertEqual(result.first?.order, .reverse)
    }

    func testComparators_size_ascending() {
        // When
        let result = FileTableView.comparators(from: .size, ascending: true)

        // Then
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.order, .forward)
        let keyPath = String(describing: result.first!.keyPath)
        XCTAssertTrue(keyPath.contains("sortableSize"))
    }

    func testComparators_size_descending() {
        // When
        let result = FileTableView.comparators(from: .size, ascending: false)

        // Then
        XCTAssertEqual(result.first?.order, .reverse)
    }

    func testComparators_dateModified_ascending() {
        // When
        let result = FileTableView.comparators(from: .dateModified, ascending: true)

        // Then
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.order, .forward)
        let keyPath = String(describing: result.first!.keyPath)
        XCTAssertTrue(keyPath.contains("sortableDate"))
    }

    func testComparators_kind_ascending() {
        // When
        let result = FileTableView.comparators(from: .kind, ascending: true)

        // Then
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.order, .forward)
        let keyPath = String(describing: result.first!.keyPath)
        XCTAssertTrue(keyPath.contains("sortableKind"))
    }

    // MARK: - sortOrder(from:) Tests

    func testSortOrder_fromNameComparator_returnsName() {
        // Given
        let comparators = [KeyPathComparator(\FileObject.name, order: .forward)]

        // When
        let (order, ascending) = FileTableView.sortOrder(from: comparators)

        // Then
        XCTAssertEqual(order, .name)
        XCTAssertTrue(ascending)
    }

    func testSortOrder_fromSizeComparator_returnsSize() {
        // Given
        let comparators = [KeyPathComparator(\FileObject.sortableSize, order: .reverse)]

        // When
        let (order, ascending) = FileTableView.sortOrder(from: comparators)

        // Then
        XCTAssertEqual(order, .size)
        XCTAssertFalse(ascending)
    }

    func testSortOrder_fromDateComparator_returnsDateModified() {
        // Given
        let comparators = [KeyPathComparator(\FileObject.sortableDate, order: .forward)]

        // When
        let (order, ascending) = FileTableView.sortOrder(from: comparators)

        // Then
        XCTAssertEqual(order, .dateModified)
        XCTAssertTrue(ascending)
    }

    func testSortOrder_fromKindComparator_returnsKind() {
        // Given
        let comparators = [KeyPathComparator(\FileObject.sortableKind, order: .reverse)]

        // When
        let (order, ascending) = FileTableView.sortOrder(from: comparators)

        // Then
        XCTAssertEqual(order, .kind)
        XCTAssertFalse(ascending)
    }

    func testSortOrder_fromEmptyComparators_returnsDefaultNameAscending() {
        // Given
        let comparators: [KeyPathComparator<FileObject>] = []

        // When
        let (order, ascending) = FileTableView.sortOrder(from: comparators)

        // Then
        XCTAssertEqual(order, .name)
        XCTAssertTrue(ascending)
    }

    // MARK: - Round-trip Tests (双向映射一致性)

    func testRoundTrip_allCases() {
        // 验证每种排序 + 方向组合经过 comparators → sortOrder 后还原
        for sortCase in FileSortOrder.allCases {
            for ascending in [true, false] {
                let comparators = FileTableView.comparators(from: sortCase, ascending: ascending)
                let (resultOrder, resultAscending) = FileTableView.sortOrder(from: comparators)

                XCTAssertEqual(resultOrder, sortCase,
                    "Round-trip failed for \(sortCase) ascending=\(ascending): got \(resultOrder)")
                XCTAssertEqual(resultAscending, ascending,
                    "Round-trip failed for \(sortCase): expected ascending=\(ascending), got \(resultAscending)")
            }
        }
    }

    // MARK: - Functional Sort Tests (排序结果正确性)

    func testSort_byName_ascending_sortsAlphabetically() {
        // Given
        let files = createTestFiles()
        let comparators = FileTableView.comparators(from: .name, ascending: true)

        // When
        let sorted = files.sorted(using: comparators)

        // Then
        let names = sorted.map(\.name)
        XCTAssertEqual(names, names.sorted())
    }

    func testSort_byName_descending_sortsReverseAlphabetically() {
        // Given
        let files = createTestFiles()
        let comparators = FileTableView.comparators(from: .name, ascending: false)

        // When
        let sorted = files.sorted(using: comparators)

        // Then
        let names = sorted.map(\.name)
        XCTAssertEqual(names, names.sorted().reversed())
    }

    func testSort_bySize_ascending_sortsBySize() {
        // Given
        let files = createTestFiles()
        let comparators = FileTableView.comparators(from: .size, ascending: true)

        // When
        let sorted = files.sorted(using: comparators)

        // Then
        let sizes = sorted.map(\.sortableSize)
        XCTAssertEqual(sizes, sizes.sorted())
    }

    func testSort_bySize_descending_sortsBySizeReversed() {
        // Given
        let files = createTestFiles()
        let comparators = FileTableView.comparators(from: .size, ascending: false)

        // When
        let sorted = files.sorted(using: comparators)

        // Then
        let sizes = sorted.map(\.sortableSize)
        XCTAssertEqual(sizes, sizes.sorted().reversed())
    }

    func testSort_byDate_ascending_sortsByDate() {
        // Given
        let files = createTestFiles()
        let comparators = FileTableView.comparators(from: .dateModified, ascending: true)

        // When
        let sorted = files.sorted(using: comparators)

        // Then
        let dates = sorted.map(\.sortableDate)
        XCTAssertEqual(dates, dates.sorted())
    }

    func testSort_byKind_ascending_sortsByKind() {
        // Given
        let files = createTestFiles()
        let comparators = FileTableView.comparators(from: .kind, ascending: true)

        // When
        let sorted = files.sorted(using: comparators)

        // Then
        let kinds = sorted.map(\.sortableKind)
        XCTAssertEqual(kinds, kinds.sorted())
    }

    // MARK: - Helpers

    private func createTestFiles() -> [FileObject] {
        let now = Date()
        return [
            FileObject(name: "charlie.txt", key: "charlie.txt", size: 300,
                        lastModifiedDate: now.addingTimeInterval(-100), isDirectory: false, eTag: "c"),
            FileObject(name: "alpha.png", key: "alpha.png", size: 100,
                        lastModifiedDate: now.addingTimeInterval(-300), isDirectory: false, eTag: "a"),
            FileObject(name: "bravo.pdf", key: "bravo.pdf", size: 200,
                        lastModifiedDate: now.addingTimeInterval(-200), isDirectory: false, eTag: "b"),
        ]
    }
}
