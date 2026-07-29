import Foundation
import Testing
@testable import GigaCat

struct ProgressViewDataMapperTests {

    @Test
    func mapsWeekLabelsAndCompletedWorkoutMarkers() throws {
        let fixture = Fixture()
        let today = try fixture.date(year: 2026, month: 7, day: 22)
        let workoutDate = try fixture.date(year: 2026, month: 7, day: 20, hour: 8)
        let history = try fixture.history(sessionDates: [workoutDate])
        let week = fixture.dateService.week(containing: today)

        let viewData = fixture.mapper.mapWeek(
            week,
            history: history,
            today: today,
            canShowNextWeek: false
        )

        #expect(viewData.periodTitle.contains("Jul"))
        #expect(viewData.periodTitle.contains("20"))
        #expect(viewData.periodTitle.contains("26"))
        #expect(viewData.days.map(\.weekdayText) == [
            "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"
        ])
        #expect(viewData.days.map(\.dayNumberText) == [
            "20", "21", "22", "23", "24", "25", "26"
        ])
        #expect(viewData.days.map(\.hasWorkout) == [
            true, false, false, false, false, false, false
        ])
        #expect(viewData.days.map(\.isToday) == [
            false, false, true, false, false, false, false
        ])
        #expect(!viewData.canShowNextWeek)
    }

    @Test
    func mapsMonthGridSelectionTodayAndMondayFirstTitles() throws {
        let fixture = Fixture()
        let selectedDate = try fixture.date(year: 2026, month: 7, day: 8)
        let today = try fixture.date(year: 2026, month: 7, day: 25)
        let workoutDate = try fixture.date(year: 2026, month: 7, day: 8, hour: 18)
        let history = try fixture.history(sessionDates: [workoutDate])
        let month = fixture.dateService.month(containing: selectedDate)

        let viewData = fixture.mapper.mapMonth(
            month,
            history: history,
            selectedDate: selectedDate,
            today: today
        )

        #expect(viewData.title == "July 2026")
        #expect(viewData.weekdayTitles == ["M", "T", "W", "T", "F", "S", "S"])
        #expect(viewData.leadingEmptyDayCount == 2)
        #expect(viewData.days.count == 31)
        #expect(viewData.days.first(where: \.isSelected)?.dayNumberText == "8")
        #expect(viewData.days.first(where: \.isToday)?.dayNumberText == "25")
        #expect(viewData.days.filter(\.hasWorkout).map(\.dayNumberText) == ["8"])
    }

    @Test
    func mapsMonthWithoutSelectedDay() throws {
        let fixture = Fixture()
        let today = try fixture.date(year: 2026, month: 7, day: 25)
        let history = try fixture.history(sessionDates: [])
        let month = fixture.dateService.month(containing: today)

        let viewData = fixture.mapper.mapMonth(
            month,
            history: history,
            selectedDate: nil,
            today: today
        )

        #expect(viewData.days.allSatisfy { !$0.isSelected })
    }

    @Test
    func mapsSelectedDaySessionsChronologicallyWithExerciseLogs() throws {
        let fixture = Fixture()
        let selectedDate = try fixture.date(year: 2026, month: 7, day: 24)
        let evening = try fixture.date(year: 2026, month: 7, day: 24, hour: 18)
        let morning = try fixture.date(year: 2026, month: 7, day: 24, hour: 8)
        let nextDay = try fixture.date(year: 2026, month: 7, day: 25, hour: 8)
        let history = try fixture.history(
            sessionDates: [evening, nextDay, morning],
            includesExerciseLogs: true
        )

        let sessions = fixture.mapper.mapSessions(
            on: selectedDate,
            history: history
        )

        let normalizedTimes = sessions.map(\.timeText).map {
            $0.replacingOccurrences(of: "\u{202F}", with: " ")
        }
        #expect(normalizedTimes == ["8:00 AM", "6:00 PM"])
        #expect(sessions.allSatisfy { $0.workoutDayTitle == "Push" })

        let firstExercise = try #require(sessions.first?.exercises.first)
        #expect(firstExercise.name == "Bench Press")
        #expect(firstExercise.sets.map(\.setNumberText) == ["1", "2"])
        #expect(firstExercise.sets.map(\.weightText) == ["62.5 kg", "60 kg"])
        #expect(firstExercise.sets.map(\.repetitionsText) == ["1 rep", "8 reps"])
    }
}

private extension ProgressViewDataMapperTests {
    struct Fixture {
        let calendar: Calendar
        let dateService: ProgressDateService
        let mapper: ProgressViewDataMapper

        init() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = Locale(identifier: "en_US_POSIX")
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            calendar.firstWeekday = 2
            self.calendar = calendar
            dateService = ProgressDateService(calendar: calendar)
            mapper = ProgressViewDataMapper(
                calendar: calendar,
                locale: Locale(identifier: "en_US_POSIX")
            )
        }

        func date(
            year: Int,
            month: Int,
            day: Int,
            hour: Int = 0
        ) throws -> Date {
            try #require(
                calendar.date(
                    from: DateComponents(
                        year: year,
                        month: month,
                        day: day,
                        hour: hour
                    )
                )
            )
        }

        func history(
            sessionDates: [Date],
            includesExerciseLogs: Bool = false
        ) throws -> ProgressHistoryContext {
            let userID = UUID()
            let histories = try sessionDates.map { date in
                try sessionHistory(
                    userID: userID,
                    startedAt: date,
                    includesExerciseLogs: includesExerciseLogs
                )
            }

            return ProgressHistoryContext(
                userID: userID,
                sessions: histories
            )
        }

        private func sessionHistory(
            userID: UUID,
            startedAt: Date,
            includesExerciseLogs: Bool
        ) throws -> ProgressSessionHistory {
            let workoutDay = try WorkoutDay(
                programId: UUID(),
                title: "Push",
                orderIndex: 0
            )
            let session = try WorkoutSession(
                userId: userID,
                workoutDayId: workoutDay.id,
                status: .completed,
                startedAt: startedAt,
                completedAt: startedAt.addingTimeInterval(3_600)
            )

            return ProgressSessionHistory(
                session: session,
                workoutDay: workoutDay,
                exercises: includesExerciseLogs
                    ? [try exerciseHistory(sessionID: session.id, workoutDayID: workoutDay.id)]
                    : []
            )
        }

        private func exerciseHistory(
            sessionID: UUID,
            workoutDayID: UUID
        ) throws -> ProgressExerciseHistory {
            let exercise = try Exercise(
                name: "Bench Press",
                muscleGroup: .chest
            )
            let dayExercise = try WorkoutDayExercise(
                workoutDayId: workoutDayID,
                exerciseId: exercise.id,
                targetSets: 2,
                targetReps: 8,
                orderIndex: 0
            )
            let logs = [
                try ExerciseLog(
                    sessionId: sessionID,
                    workoutDayExerciseId: dayExercise.id,
                    weight: 62.5,
                    reps: 1,
                    setNumber: 1
                ),
                try ExerciseLog(
                    sessionId: sessionID,
                    workoutDayExerciseId: dayExercise.id,
                    weight: 60,
                    reps: 8,
                    setNumber: 2
                )
            ]

            return ProgressExerciseHistory(
                dayExercise: dayExercise,
                exercise: exercise,
                logs: logs
            )
        }
    }
}
