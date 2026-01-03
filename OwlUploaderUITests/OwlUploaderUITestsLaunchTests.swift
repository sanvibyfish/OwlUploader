//
//  OwlUploaderUITestsLaunchTests.swift
//  OwlUploaderUITests
//
//  Created by Sanvi Lu on 2025/5/25.
//

import XCTest

final class OwlUploaderUITestsLaunchTests: XCTestCase {

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launchArguments += ["-AppleLanguages", "(zh)", "-AppleLocale", "zh_CN"]
        return app
    }

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = makeApp()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
