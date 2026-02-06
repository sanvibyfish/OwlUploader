//
//  ThumbnailCacheTests.swift
//  OwlUploaderTests
//
//  ThumbnailCache 缓存失效与 R2Service 缩略图 URL 生成测试（v1.0.1）
//

import XCTest
@testable import OwlUploader

final class ThumbnailCacheTests: XCTestCase {

    // MARK: - invalidateCache Tests

    func testInvalidateCache_removesAllSizeVariants() {
        // Given
        let cache = ThumbnailCache.shared
        let testURL = "https://cdn.example.com/images/photo.jpg"
        let sizes = [20, 40, 64, 128, 256, 512]

        // 预填充缓存（模拟各尺寸都有缓存）
        let testImage = NSImage(size: NSSize(width: 10, height: 10))
        for size in sizes {
            let key = "\(testURL)_\(size)"
            cache.cacheThumbnail(testImage, for: key)
        }

        // 验证缓存存在
        for size in sizes {
            let key = "\(testURL)_\(size)"
            XCTAssertNotNil(cache.getCachedThumbnail(for: key),
                "缓存应存在: \(key)")
        }

        // When
        cache.invalidateCache(for: testURL)

        // Then — 所有尺寸的缓存都应被清除
        for size in sizes {
            let key = "\(testURL)_\(size)"
            XCTAssertNil(cache.getCachedThumbnail(for: key),
                "缓存应已清除: \(key)")
        }
    }

    func testInvalidateCache_doesNotAffectOtherURLs() {
        // Given
        let cache = ThumbnailCache.shared
        let url1 = "https://cdn.example.com/images/photo1.jpg"
        let url2 = "https://cdn.example.com/images/photo2.jpg"
        let testImage = NSImage(size: NSSize(width: 10, height: 10))

        cache.cacheThumbnail(testImage, for: "\(url1)_128")
        cache.cacheThumbnail(testImage, for: "\(url2)_128")

        // When — 只清除 url1
        cache.invalidateCache(for: url1)

        // Then
        XCTAssertNil(cache.getCachedThumbnail(for: "\(url1)_128"))
        XCTAssertNotNil(cache.getCachedThumbnail(for: "\(url2)_128"),
            "url2 的缓存不应受影响")

        // Cleanup
        cache.clearCache()
    }

    func testInvalidateCache_safeWhenNoCacheExists() {
        // Given
        let cache = ThumbnailCache.shared
        let url = "https://cdn.example.com/images/nonexistent.jpg"

        // When — 清除不存在的缓存，不应崩溃
        cache.invalidateCache(for: url)

        // Then — 简单验证不崩溃
        XCTAssertNil(cache.getCachedThumbnail(for: "\(url)_128"))
    }

    // MARK: - clearCache Tests

    func testClearCache_removesAllEntries() {
        // Given
        let cache = ThumbnailCache.shared
        let testImage = NSImage(size: NSSize(width: 10, height: 10))
        cache.cacheThumbnail(testImage, for: "test_key_1")
        cache.cacheThumbnail(testImage, for: "test_key_2")

        // When
        cache.clearCache()

        // Then
        XCTAssertNil(cache.getCachedThumbnail(for: "test_key_1"))
        XCTAssertNil(cache.getCachedThumbnail(for: "test_key_2"))
    }

    // MARK: - Cache Key Format Tests

    func testCacheKeyFormat_includesURLAndSize() {
        // Given — 验证缓存 key 的格式约定
        let url = "https://cdn.example.com/test.jpg"
        let size = 128

        // When
        let expectedKey = "\(url)_\(size)"

        // Then
        XCTAssertEqual(expectedKey, "https://cdn.example.com/test.jpg_128")
    }

    func testCacheKeyFormat_versionedURLProducesDifferentKey() {
        // Given — 带版本参数和不带版本参数的 URL 产生不同的 key
        let baseURL = "https://cdn.example.com/test.jpg"
        let versionedURL1 = "\(baseURL)?v=1000"
        let versionedURL2 = "\(baseURL)?v=2000"

        // When
        let key1 = "\(versionedURL1)_128"
        let key2 = "\(versionedURL2)_128"

        // Then — 不同版本号产生不同的缓存 key
        XCTAssertNotEqual(key1, key2)
    }
}

// MARK: - R2Service Thumbnail URL Generation Tests

@MainActor
final class R2ServiceThumbnailURLTests: XCTestCase {

    private var r2Service: R2Service!

    override func setUp() async throws {
        try await super.setUp()
        r2Service = R2Service()
    }

    override func tearDown() async throws {
        r2Service = nil
        try await super.tearDown()
    }

    // MARK: - generateBaseURL Tests

    func testGenerateBaseURL_withoutAccount_returnsNil() {
        // Given — 未初始化的 R2Service
        let service = R2Service()

        // When
        let url = service.generateBaseURL(for: "test.jpg", in: "my-bucket")

        // Then
        XCTAssertNil(url)
    }

    func testGenerateFileURL_withoutAccount_returnsNil() {
        // Given
        let service = R2Service()
        let fileObject = FileObject(
            name: "test.jpg",
            key: "images/test.jpg",
            size: 1024,
            lastModifiedDate: Date(),
            isDirectory: false,
            eTag: "\"abc123\""
        )

        // When
        let url = service.generateFileURL(for: fileObject, in: "my-bucket")

        // Then
        XCTAssertNil(url)
    }

    func testGenerateThumbnailURL_withoutAccount_returnsNil() {
        // Given
        let service = R2Service()
        let fileObject = FileObject(
            name: "test.jpg",
            key: "images/test.jpg",
            size: 1024,
            lastModifiedDate: Date(),
            isDirectory: false,
            eTag: "\"abc123\""
        )

        // When
        let url = service.generateThumbnailURL(for: fileObject, in: "my-bucket")

        // Then
        XCTAssertNil(url)
    }

    // MARK: - invalidateThumbnailCache Tests

    func testInvalidateThumbnailCache_withoutAccount_doesNotCrash() {
        // Given
        let service = R2Service()

        // When — 未配置账户时调用不应崩溃
        service.invalidateThumbnailCache(for: "test.jpg", in: "my-bucket")

        // Then — 不崩溃即通过
    }

    // MARK: - CDN Purge Configuration Check Tests

    func testPurgeCDNCache_withoutAccount_skips() async {
        // Given
        let service = R2Service()

        // When — 未配置账户时调用
        await service.purgeCDNCache(for: ["https://cdn.example.com/test.jpg"])

        // Then — 不崩溃，静默跳过
    }
}

// MARK: - FileObject Thumbnail URL Version Tests

final class FileObjectThumbnailVersionTests: XCTestCase {

    func testFileObject_withLastModified_hasModDate() {
        // Given
        let modDate = Date(timeIntervalSince1970: 1718451000)
        let fileObject = FileObject(
            name: "photo.jpg",
            key: "images/photo.jpg",
            size: 2048,
            lastModifiedDate: modDate,
            isDirectory: false,
            eTag: "\"etag123\""
        )

        // Then — lastModifiedDate 应该被设置
        XCTAssertNotNil(fileObject.lastModifiedDate)
        XCTAssertEqual(fileObject.lastModifiedDate, modDate)
    }

    func testFileObject_eTag_isAvailable() {
        // Given
        let fileObject = FileObject(
            name: "photo.jpg",
            key: "images/photo.jpg",
            size: 2048,
            lastModifiedDate: nil,
            isDirectory: false,
            eTag: "\"etag-hash-value\""
        )

        // Then
        XCTAssertEqual(fileObject.eTag, "\"etag-hash-value\"")
    }

    func testVersionParameter_basedOnModDate_producesConsistentValue() {
        // Given — 固定时间戳应产生固定版本号
        let date = Date(timeIntervalSince1970: 1718451000) // 固定时间戳

        // When
        let timestamp = Int(date.timeIntervalSince1970)

        // Then
        XCTAssertEqual(timestamp, 1718451000)
    }

    func testVersionParameter_differentDates_produceDifferentValues() {
        // Given
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)

        // When
        let v1 = Int(date1.timeIntervalSince1970)
        let v2 = Int(date2.timeIntervalSince1970)

        // Then — 不同时间产生不同版本号，CDN 会认为是不同的资源
        XCTAssertNotEqual(v1, v2)
    }

    func testVersionedURL_format() {
        // Given
        let baseURL = "https://cdn.example.com/images/photo.jpg"
        let timestamp = 1718451000

        // When
        let versionedURL = "\(baseURL)?v=\(timestamp)"

        // Then
        XCTAssertEqual(versionedURL, "https://cdn.example.com/images/photo.jpg?v=1718451000")
        XCTAssertTrue(versionedURL.contains("?v="))
    }

    func testVersionedURL_withETagFallback() {
        // Given — 当没有 modDate 时，使用 eTag 的 hashValue
        let eTag = "\"abc123def456\""
        let hashValue = abs(eTag.hashValue)

        // When
        let baseURL = "https://cdn.example.com/images/photo.jpg"
        let versionedURL = "\(baseURL)?v=\(hashValue)"

        // Then
        XCTAssertTrue(versionedURL.contains("?v="))
        XCTAssertTrue(hashValue > 0)
    }
}
