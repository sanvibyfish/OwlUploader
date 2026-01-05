//
//  MoveQueueManagerTests.swift
//  OwlUploaderTests
//
//  Covers move-queue conflict handling expectations.
//

import XCTest
@testable import OwlUploader

@MainActor
final class MoveQueueManagerTests: XCTestCase {

    func testMoveFolderDoesNotDeleteExistingDestination() {
        XCTExpectFailure("Moving into an existing destination should not delete its contents; current implementation removes the target folder.")

        // Skip auto-initialization logic in R2Service during tests.
        if !CommandLine.arguments.contains("--ui-testing") {
            CommandLine.arguments.append("--ui-testing")
        }

        let mockService = MockR2Service()
        mockService.objectExistsHandler = { _, _ in true } // Simulate destination already exists.

        let manager = MoveQueueManager()
        manager.configure(r2Service: mockService, bucketName: "test-bucket")
        MoveQueueManager.setMaxConcurrentMoves(1)

        let expectation = expectation(description: "Move queue completes")
        manager.onQueueComplete = { expectation.fulfill() }

        let folder = FileObject.folder(name: "src", key: "src/")
        manager.addMoveTasks([folder], to: "dest/")

        wait(for: [expectation], timeout: 2.0)

        XCTAssertFalse(mockService.deleteFolderCalled, "Destination contents should not be removed during a move.")
    }
}

// MARK: - Test doubles

private final class MockR2Service: R2Service {
    var deleteFolderCalled = false
    var moveFolderCalled = false
    var objectExistsHandler: ((String, String) -> Bool)?

    override init(accountManager: R2AccountManager = .shared) {
        super.init(accountManager: accountManager)
    }

    override func objectExists(bucket: String, key: String) async throws -> Bool {
        objectExistsHandler?(bucket, key) ?? false
    }

    override func deleteFolder(bucket: String, folderKey: String) async throws -> (deletedCount: Int, failedKeys: [String]) {
        deleteFolderCalled = true
        return (0, [])
    }

    override func moveFolder(bucket: String, sourceFolderKey: String, destinationFolderKey: String) async throws -> (movedCount: Int, failedKeys: [String]) {
        moveFolderCalled = true
        return (1, [])
    }
}
