//
//  FilePreviewTests.swift
//  OwlUploaderTests
//
//  文件预览相关测试
//  - PreviewFileType 文件类型检测
//  - FileObject 媒体类型判断
//

import XCTest
@testable import OwlUploader

// MARK: - PreviewFileType Tests

final class PreviewFileTypeTests: XCTestCase {

    func testPreviewFileType_displayName_notEmpty() {
        // Given — 所有类型都应有显示名称
        let types: [PreviewFileType] = [.image, .video, .audio, .pdf, .text, .unknown]

        // Then
        for type in types {
            XCTAssertFalse(type.displayName.isEmpty,
                "\(type) 应有非空的 displayName")
        }
    }
}

// MARK: - FileObject Media Type Detection Tests

final class FileObjectMediaTypeTests: XCTestCase {

    // MARK: - isAudio Tests

    func testIsAudio_supportedFormats() {
        // Given — 所有应支持的音频格式
        let audioExtensions = ["mp3", "wav", "aac", "flac", "ogg", "m4a"]

        for ext in audioExtensions {
            let file = FileObject(
                name: "track.\(ext)",
                key: "music/track.\(ext)",
                size: 1024,
                lastModifiedDate: nil,
                isDirectory: false,
                eTag: nil
            )

            // Then
            XCTAssertTrue(file.isAudio, "\(ext) 应被识别为音频文件")
        }
    }

    func testIsAudio_caseInsensitive() {
        // Given — 大写扩展名也应识别
        let file = FileObject(
            name: "track.MP3",
            key: "music/track.MP3",
            size: 1024,
            lastModifiedDate: nil,
            isDirectory: false,
            eTag: nil
        )

        // Then
        XCTAssertTrue(file.isAudio, "大写 MP3 应被识别为音频")
    }

    func testIsAudio_videoFileNotAudio() {
        // Given
        let file = FileObject(
            name: "movie.mp4",
            key: "video/movie.mp4",
            size: 1024,
            lastModifiedDate: nil,
            isDirectory: false,
            eTag: nil
        )

        // Then
        XCTAssertFalse(file.isAudio, "mp4 视频不应被识别为音频")
        XCTAssertTrue(file.isVideo, "mp4 应被识别为视频")
    }

    func testIsAudio_directoryNotAudio() {
        // Given
        let folder = FileObject.folder(name: "mp3", key: "mp3/")

        // Then
        XCTAssertFalse(folder.isAudio, "文件夹不应被识别为音频")
    }

    // MARK: - isVideo Tests

    func testIsVideo_supportedFormats() {
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm"]

        for ext in videoExtensions {
            let file = FileObject(
                name: "clip.\(ext)",
                key: "video/clip.\(ext)",
                size: 1024,
                lastModifiedDate: nil,
                isDirectory: false,
                eTag: nil
            )

            XCTAssertTrue(file.isVideo, "\(ext) 应被识别为视频文件")
        }
    }

    // MARK: - isImage Tests

    func testIsImage_supportedFormats() {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp"]

        for ext in imageExtensions {
            let file = FileObject(
                name: "photo.\(ext)",
                key: "images/photo.\(ext)",
                size: 1024,
                lastModifiedDate: nil,
                isDirectory: false,
                eTag: nil
            )

            XCTAssertTrue(file.isImage, "\(ext) 应被识别为图片文件")
        }
    }

    // MARK: - Mutual Exclusivity Tests

    func testMediaTypes_mutuallyExclusive() {
        // Given — 一个文件不应同时属于多种媒体类型
        let testFiles: [(name: String, expectedType: String)] = [
            ("photo.jpg", "image"),
            ("video.mp4", "video"),
            ("track.mp3", "audio"),
            ("doc.pdf", "other"),
        ]

        for (name, expectedType) in testFiles {
            let file = FileObject(
                name: name,
                key: name,
                size: 1024,
                lastModifiedDate: nil,
                isDirectory: false,
                eTag: nil
            )

            let typeFlags = [
                ("image", file.isImage),
                ("video", file.isVideo),
                ("audio", file.isAudio),
            ]

            let trueCount = typeFlags.filter { $0.1 }.count
            if expectedType == "other" {
                XCTAssertEqual(trueCount, 0, "\(name) 不应匹配任何媒体类型")
            } else {
                XCTAssertEqual(trueCount, 1, "\(name) 应只匹配一种媒体类型")
                XCTAssertTrue(typeFlags.first { $0.0 == expectedType }?.1 ?? false,
                    "\(name) 应匹配 \(expectedType)")
            }
        }
    }
}
