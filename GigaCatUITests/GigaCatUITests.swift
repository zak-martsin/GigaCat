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

    @MainActor
    func testProfileSavesAndResetsRecommendationsWithoutLosingSetDraft() throws {
        let app = launchTestApp()
        tapCenter(app.tabBars.buttons["Workout"])
        let exercise = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'workout.exercise.'")).firstMatch
        if !exercise.waitForExistence(timeout: 5) { app.tabBars.buttons["Workout"].tap() }
        guard exercise.waitForExistence(timeout: 10) else {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.lifetime = .keepAlways
            add(screenshot)
            XCTFail("Workout did not open: \(app.debugDescription)")
            return
        }
        exercise.tap()
        XCTAssertTrue(app.scrollViews["workout.exerciseDetail"].waitForExistence(timeout: 5))
        app.buttons["Add set"].tap()
        let weight = app.textFields["workout.set.3.kg"]
        let reps = app.textFields["workout.set.3.rep"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        weight.typeText("123.5")
        let detail = app.scrollViews["workout.exerciseDetail"]
        detail.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
            .press(forDuration: 0.1, thenDragTo: detail.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
        reps.tap()
        reps.typeText("9")
        app.navigationBars.buttons["Profile"].tap()
        XCTAssertTrue(app.staticTexts["athlete@example.com"].waitForExistence(timeout: 5))
        app.buttons["profile.goal"].tap()
        app.buttons["Build muscle"].tap()
        app.buttons["profile.level"].tap()
        app.buttons["Advanced"].tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Profile v1"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["profile.save"].tap()
        let recommendation = app.staticTexts["workout.recommendation"]
        XCTAssertTrue(recommendation.waitForExistence(timeout: 5))
        XCTAssertTrue(recommendation.label.contains("4 sets"))
        XCTAssertEqual(weight.value as? String, "123.5")
        XCTAssertEqual(reps.value as? String, "9")
        app.navigationBars.buttons["Profile"].tap()
        app.buttons["profile.goal"].tap()
        app.buttons["Not set"].tap()
        app.buttons["profile.level"].tap()
        app.buttons["Not set"].tap()
        app.buttons["profile.save"].tap()
        XCTAssertTrue(recommendation.waitForExistence(timeout: 5))
        XCTAssertTrue(recommendation.label.contains("2 sets"))
        XCTAssertEqual(weight.value as? String, "123.5")
        XCTAssertEqual(reps.value as? String, "9")
    }

    @MainActor
    func testCancelProfileDiscardsUnsavedPreferences() throws {
        let app = launchTestApp()
        tapCenter(app.buttons["Profile"])
        let goal = app.buttons["profile.goal"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5))
        goal.tap()
        app.buttons["Build muscle"].tap()
        app.buttons["profile.cancel"].tap()
        tapCenter(app.buttons["Profile"])
        XCTAssertTrue(goal.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["profile.save"].isEnabled)
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
