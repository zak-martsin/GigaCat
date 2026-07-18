//
//  GigaCatUITestsLaunchTests.swift
//  GigaCatUITests
//
//  Created by Захар Марцинкевич on 23/06/2026.
//

import XCTest

final class GigaCatUITestsLaunchTests: XCTestCase {

    // swiftlint:disable:next static_over_final_class
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    /// Verifies that the app launches successfully and preserves a screenshot of the initial UI state.
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
