//
//  GigaCatUITests.swift
//  GigaCatUITests
//
//  Created by Захар Марцинкевич on 23/06/2026.
//

import XCTest

final class GigaCatUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testReturningToWorkoutClosesExerciseDetail() throws {
        let app = launchTestApp()

        tapCenter(app.tabBars.buttons["Workout"])

        let exerciseList = app.scrollViews["workout.exerciseList"]
        XCTAssertTrue(exerciseList.waitForExistence(timeout: 10))

        let exercise = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'workout.exercise.'"))
            .firstMatch
        XCTAssertTrue(exercise.waitForExistence(timeout: 5))
        exercise.tap()

        let exerciseDetail = app.scrollViews["workout.exerciseDetail"]
        XCTAssertTrue(exerciseDetail.waitForExistence(timeout: 5))

        tapCenter(app.tabBars.buttons["Catalog"])
        tapCenter(app.tabBars.buttons["Workout"])

        XCTAssertTrue(exerciseList.waitForExistence(timeout: 5))
        XCTAssertFalse(exerciseDetail.exists)
    }

    @MainActor
    func testWorkoutProgramInformationOpensSharedDetail() throws {
        let app = launchTestApp()

        app.tabBars.buttons["Workout"].tap()

        let programInformation = app.buttons["Program information"]
        XCTAssertTrue(programInformation.waitForExistence(timeout: 5))
        programInformation.tap()

        XCTAssertTrue(app.scrollViews["programDetail.sheet"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testProfileShowsFriendlySyncFailureWithoutRawError() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-sync-failed"]
        app.launch()

        tapCenter(app.buttons["Profile"])

        let status = app.descendants(matching: .any)["profileSyncFailureStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Internal database error"].exists)
    }

    private func launchTestApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()
        return app
    }

    @MainActor
    private func tapCenter(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
