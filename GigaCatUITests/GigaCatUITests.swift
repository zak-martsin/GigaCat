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

        app.tabBars.buttons["Workout"].tap()

        let exerciseList = app.scrollViews["workout.exerciseList"]
        XCTAssertTrue(exerciseList.waitForExistence(timeout: 5))

        let exercise = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'workout.exercise.'"))
            .firstMatch
        XCTAssertTrue(exercise.waitForExistence(timeout: 5))
        exercise.tap()

        let exerciseDetail = app.scrollViews["workout.exerciseDetail"]
        XCTAssertTrue(exerciseDetail.waitForExistence(timeout: 5))

        app.tabBars.buttons["Catalog"].tap()
        app.tabBars.buttons["Workout"].tap()

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

    private func launchTestApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()
        return app
    }
}
