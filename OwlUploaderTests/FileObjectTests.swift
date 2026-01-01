//
//  FileObjectTests.swift
//  OwlUploaderTests
//
//  FileObject 模型单元测试
//

import XCTest
@testable import OwlUploader

final class FileObjectTests: XCTestCase {

    // MARK: - Folder Initialization Tests

    func testFolderInit_setsIsDirectoryTrue() {
        // Given & When
        let folder = FileObject.folder(name: "Documents", key: "documents/")

        // Then
        XCTAssertTrue(folder.isDirectory)
        XCTAssertEqual(folder.name, "Documents")
        XCTAssertEqual(folder.key, "documents/")
        XCTAssertNil(folder.size)
        XCTAssertNil(folder.lastModifiedDate)
        XCTAssertNil(folder.eTag)
    }

    func testFolderInit_idMatchesKey() {
        // Given & When
        let folder = FileObject.folder(name: "Test", key: "test/path/")

        // Then
        XCTAssertEqual(folder.id, "test/path/")
    }

    // MARK: - File Initialization Tests

    func testFileInit_setsIsDirectoryFalse() {
        // Given
        let testDate = Date()

        // When
        let file = FileObject.file(
            name: "report.pdf",
            key: "documents/report.pdf",
            size: 1024,
            lastModifiedDate: testDate,
            eTag: "abc123"
        )

        // Then
        XCTAssertFalse(file.isDirectory)
        XCTAssertEqual(file.name, "report.pdf")
        XCTAssertEqual(file.key, "documents/report.pdf")
        XCTAssertEqual(file.size, 1024)
        XCTAssertEqual(file.lastModifiedDate, testDate)
        XCTAssertEqual(file.eTag, "abc123")
    }

    func testFileInit_idMatchesKey() {
        // Given & When
        let file = FileObject.file(
            name: "test.txt",
            key: "path/to/test.txt",
            size: 100,
            lastModifiedDate: Date(),
            eTag: "xyz"
        )

        // Then
        XCTAssertEqual(file.id, "path/to/test.txt")
    }

    // MARK: - fromCommonPrefix Tests

    func testFromCommonPrefix_extractsCorrectName() {
        // Given
        let prefix = "documents/2023/"

        // When
        let folder = FileObject.fromCommonPrefix(prefix)

        // Then
        XCTAssertEqual(folder.name, "documents/2023")
        XCTAssertEqual(folder.key, "documents/2023/")
        XCTAssertTrue(folder.isDirectory)
    }

    func testFromCommonPrefix_withCurrentPrefix() {
        // Given
        let prefix = "documents/2023/reports/"
        let currentPrefix = "documents/"

        // When
        let folder = FileObject.fromCommonPrefix(prefix, currentPrefix: currentPrefix)

        // Then
        XCTAssertEqual(folder.name, "2023/reports")
        XCTAssertEqual(folder.key, "documents/2023/reports/")
    }

    func testFromCommonPrefix_withMatchingCurrentPrefix() {
        // Given
        let prefix = "images/vacation/"
        let currentPrefix = "images/"

        // When
        let folder = FileObject.fromCommonPrefix(prefix, currentPrefix: currentPrefix)

        // Then
        XCTAssertEqual(folder.name, "vacation")
        XCTAssertEqual(folder.key, "images/vacation/")
    }

    func testFromCommonPrefix_withoutTrailingSlash() {
        // Given - 极端情况：没有尾部斜杠的前缀
        let prefix = "documents"

        // When
        let folder = FileObject.fromCommonPrefix(prefix)

        // Then
        XCTAssertEqual(folder.name, "documents")
        XCTAssertEqual(folder.key, "documents")
    }

    // MARK: - fromS3Object Tests

    func testFromS3Object_mapsAllFields() {
        // Given
        let testDate = Date()
        let key = "documents/report.pdf"
        let size: Int64 = 2048
        let eTag = "d41d8cd98f00b204e9800998ecf8427e"

        // When
        let file = FileObject.fromS3Object(
            key: key,
            size: size,
            lastModified: testDate,
            eTag: eTag
        )

        // Then
        XCTAssertEqual(file.name, "report.pdf")
        XCTAssertEqual(file.key, key)
        XCTAssertEqual(file.size, size)
        XCTAssertEqual(file.lastModifiedDate, testDate)
        XCTAssertEqual(file.eTag, eTag)
        XCTAssertFalse(file.isDirectory)
    }

    func testFromS3Object_withCurrentPrefix() {
        // Given
        let key = "documents/2023/report.pdf"
        let currentPrefix = "documents/"

        // When
        let file = FileObject.fromS3Object(
            key: key,
            size: 1024,
            lastModified: Date(),
            eTag: "abc",
            currentPrefix: currentPrefix
        )

        // Then
        XCTAssertEqual(file.name, "report.pdf")
        XCTAssertEqual(file.key, key)
    }

    func testFromS3Object_withDeepPath() {
        // Given
        let key = "a/b/c/d/file.txt"
        let currentPrefix = "a/b/"

        // When
        let file = FileObject.fromS3Object(
            key: key,
            size: 100,
            lastModified: Date(),
            eTag: "xyz",
            currentPrefix: currentPrefix
        )

        // Then
        XCTAssertEqual(file.name, "file.txt")
    }

    // MARK: - formattedSize Tests

    func testFormattedSize_formatsCorrectly() {
        // Given
        let file = FileObject.file(
            name: "test.txt",
            key: "test.txt",
            size: 1024,
            lastModifiedDate: Date(),
            eTag: "abc"
        )

        // When
        let formatted = file.formattedSize

        // Then
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("KB") || formatted.contains("字节") || formatted.contains("bytes"))
    }

    func testFormattedSize_forLargeFile() {
        // Given - 1.5 GB
        let file = FileObject.file(
            name: "large.zip",
            key: "large.zip",
            size: 1_610_612_736,
            lastModifiedDate: Date(),
            eTag: "abc"
        )

        // When
        let formatted = file.formattedSize

        // Then
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("GB") || formatted.contains("1.5") || formatted.contains("1,5"))
    }

    func testFormattedSize_forFolder_returnsEmpty() {
        // Given
        let folder = FileObject.folder(name: "Documents", key: "documents/")

        // When
        let formatted = folder.formattedSize

        // Then
        XCTAssertEqual(formatted, "")
    }

    // MARK: - iconName Tests

    func testIconName_forFolder_returnsFolderIcon() {
        // Given
        let folder = FileObject.folder(name: "Documents", key: "documents/")

        // When
        let icon = folder.iconName

        // Then
        XCTAssertEqual(icon, "folder.fill")
    }

    func testIconName_forPdf_returnsDocIcon() {
        // Given
        let file = createTestFile(name: "report.pdf")

        // When
        let icon = file.iconName

        // Then
        XCTAssertEqual(icon, "doc.fill")
    }

    func testIconName_forImage_returnsPhotoIcon() {
        // Given
        let jpgFile = createTestFile(name: "photo.jpg")
        let pngFile = createTestFile(name: "image.png")

        // Then
        XCTAssertEqual(jpgFile.iconName, "photo.fill")
        XCTAssertEqual(pngFile.iconName, "photo.fill")
    }

    func testIconName_forVideo_returnsVideoIcon() {
        // Given
        let file = createTestFile(name: "video.mp4")

        // When
        let icon = file.iconName

        // Then
        XCTAssertEqual(icon, "video.fill")
    }

    func testIconName_forAudio_returnsMusicIcon() {
        // Given
        let file = createTestFile(name: "song.mp3")

        // When
        let icon = file.iconName

        // Then
        XCTAssertEqual(icon, "music.note")
    }

    func testIconName_forArchive_returnsArchiveIcon() {
        // Given
        let file = createTestFile(name: "backup.zip")

        // When
        let icon = file.iconName

        // Then
        XCTAssertEqual(icon, "archivebox.fill")
    }

    func testIconName_forUnknownType_returnsDocIcon() {
        // Given
        let file = createTestFile(name: "unknown.xyz")

        // When
        let icon = file.iconName

        // Then
        XCTAssertEqual(icon, "doc.fill")
    }

    // MARK: - fileExtension Tests

    func testFileExtension_returnsCorrectExtension() {
        // Given
        let file = createTestFile(name: "document.pdf")

        // When
        let ext = file.fileExtension

        // Then
        XCTAssertEqual(ext, "pdf")
    }

    func testFileExtension_forFolder_returnsEmpty() {
        // Given
        let folder = FileObject.folder(name: "Documents", key: "documents/")

        // When
        let ext = folder.fileExtension

        // Then
        XCTAssertEqual(ext, "")
    }

    func testFileExtension_forFileWithoutExtension() {
        // Given
        let file = createTestFile(name: "README")

        // When
        let ext = file.fileExtension

        // Then
        XCTAssertEqual(ext, "")
    }

    // MARK: - isImage/isVideo/isAudio Tests

    func testIsImage_forImageFiles() {
        // Given
        let jpgFile = createTestFile(name: "photo.jpg")
        let pngFile = createTestFile(name: "image.png")
        let gifFile = createTestFile(name: "animation.gif")
        let pdfFile = createTestFile(name: "document.pdf")

        // Then
        XCTAssertTrue(jpgFile.isImage)
        XCTAssertTrue(pngFile.isImage)
        XCTAssertTrue(gifFile.isImage)
        XCTAssertFalse(pdfFile.isImage)
    }

    func testIsVideo_forVideoFiles() {
        // Given
        let mp4File = createTestFile(name: "video.mp4")
        let movFile = createTestFile(name: "movie.mov")
        let mp3File = createTestFile(name: "song.mp3")

        // Then
        XCTAssertTrue(mp4File.isVideo)
        XCTAssertTrue(movFile.isVideo)
        XCTAssertFalse(mp3File.isVideo)
    }

    func testIsAudio_forAudioFiles() {
        // Given
        let mp3File = createTestFile(name: "song.mp3")
        let wavFile = createTestFile(name: "sound.wav")
        let mp4File = createTestFile(name: "video.mp4")

        // Then
        XCTAssertTrue(mp3File.isAudio)
        XCTAssertTrue(wavFile.isAudio)
        XCTAssertFalse(mp4File.isAudio)
    }

    // MARK: - Hashable Tests

    func testHashable_canBeUsedInSet() {
        // Given
        let file1 = createTestFile(name: "file1.txt", key: "file1.txt")
        let file2 = createTestFile(name: "file2.txt", key: "file2.txt")
        let folder = FileObject.folder(name: "Folder", key: "folder/")

        // When
        var set = Set<FileObject>()
        set.insert(file1)
        set.insert(file2)
        set.insert(folder)

        // Then
        XCTAssertEqual(set.count, 3)
    }

    func testHashable_sameKeyAreDuplicates() {
        // Given
        let file1 = createTestFile(name: "file.txt", key: "same/key.txt")
        let file2 = createTestFile(name: "different.txt", key: "same/key.txt")

        // When
        var set = Set<FileObject>()
        set.insert(file1)
        set.insert(file2)

        // Then - Same key means same id, so they're duplicates
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - Sample Data Tests

    func testSampleData_isNotEmpty() {
        // Given & When
        let samples = FileObject.sampleData

        // Then
        XCTAssertFalse(samples.isEmpty)
        XCTAssertGreaterThan(samples.count, 0)
    }

    func testSampleData_containsFoldersAndFiles() {
        // Given & When
        let samples = FileObject.sampleData
        let folders = samples.filter { $0.isDirectory }
        let files = samples.filter { !$0.isDirectory }

        // Then
        XCTAssertFalse(folders.isEmpty, "样本数据应该包含文件夹")
        XCTAssertFalse(files.isEmpty, "样本数据应该包含文件")
    }

    func testEmptyData_isEmpty() {
        // Given & When
        let empty = FileObject.emptyData

        // Then
        XCTAssertTrue(empty.isEmpty)
    }

    func testFoldersOnlyData_containsOnlyFolders() {
        // Given & When
        let data = FileObject.foldersOnlyData

        // Then
        XCTAssertFalse(data.isEmpty)
        XCTAssertTrue(data.allSatisfy { $0.isDirectory })
    }

    func testFilesOnlyData_containsOnlyFiles() {
        // Given & When
        let data = FileObject.filesOnlyData

        // Then
        XCTAssertFalse(data.isEmpty)
        XCTAssertTrue(data.allSatisfy { !$0.isDirectory })
    }

    // MARK: - Helper Methods

    private func createTestFile(name: String, key: String? = nil) -> FileObject {
        return FileObject.file(
            name: name,
            key: key ?? name,
            size: 1024,
            lastModifiedDate: Date(),
            eTag: "test-etag"
        )
    }
}
