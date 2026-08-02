import Foundation
import Testing
@testable import GigaCat

@MainActor
struct ProgressCalendarViewModelTests {

    @Test
    func initializesOnTargetDateAndMapsItsSessions() throws {
        let targetDate = try Fixture.date(
            year: 2026,
            month: 6,
            day: 15,
            hour: 14
        )
        let fixture = try Fixture(historyDates: [targetDate])

        let viewModel = fixture.makeViewModel(selectedDate: targetDate)
        let expectedMonthStart = try Fixture.date(
            year: 2026,
            month: 6,
            day: 1
        )

        #expect(viewModel.selectedDate == targetDate)
        #expect(viewModel.displayedMonthStart == expectedMonthStart)
        #expect(viewModel.monthViewData.title == "June 2026")
        #expect(viewModel.monthPages.map(\.title) == [
            "May 2026", "June 2026", "July 2026"
        ])
        #expect(viewModel.monthViewData.days.first(where: \.isSelected)?.dayNumberText == "15")
        #expect(viewModel.selectedDaySessions.count == 1)
        #expect(viewModel.canShowNextMonth)
    }

    @Test
    func noSelectedDateOpensCurrentMonthWithoutSessions() throws {
        let fixture = try Fixture(historyDates: [])

        let viewModel = fixture.makeViewModel()
        let expectedMonthStart = try Fixture.date(
            year: 2026,
            month: 7,
            day: 1
        )

        #expect(viewModel.selectedDate == nil)
        #expect(viewModel.displayedMonthStart == expectedMonthStart)
        #expect(viewModel.monthPages.map(\.title) == [
            "June 2026", "July 2026"
        ])
        #expect(viewModel.selectedDaySessions.isEmpty)
        #expect(viewModel.monthViewData.days.allSatisfy { !$0.isSelected })
    }

    @Test
    func previousMonthClearsSelectionAndSelectedDaySessions() throws {
        let initialDate = try Fixture.date(year: 2026, month: 7, day: 29)
        let fixture = try Fixture(historyDates: [initialDate])
        let viewModel = fixture.makeViewModel(selectedDate: initialDate)

        viewModel.showPreviousMonth()
        let expectedMonthStart = try Fixture.date(
            year: 2026,
            month: 6,
            day: 1
        )

        #expect(viewModel.displayedMonthStart == expectedMonthStart)
        #expect(viewModel.selectedDate == nil)
        #expect(viewModel.selectedDaySessions.isEmpty)
        #expect(viewModel.monthViewData.days.allSatisfy { !$0.isSelected })
        #expect(viewModel.monthPages.map(\.title) == [
            "May 2026", "June 2026", "July 2026"
        ])
        #expect(viewModel.canShowNextMonth)
    }

    @Test
    func nextMonthStopsAtCurrentMonth() throws {
        let initialDate = try Fixture.date(year: 2026, month: 6, day: 15)
        let fixture = try Fixture(historyDates: [])
        let viewModel = fixture.makeViewModel(selectedDate: initialDate)

        viewModel.showNextMonth()
        viewModel.showNextMonth()
        let expectedMonthStart = try Fixture.date(
            year: 2026,
            month: 7,
            day: 1
        )

        #expect(viewModel.displayedMonthStart == expectedMonthStart)
        #expect(viewModel.selectedDate == nil)
        #expect(!viewModel.canShowNextMonth)
    }

    @Test
    func selectingVisibleDateMapsItsSessionsAndSelection() throws {
        let initialDate = try Fixture.date(year: 2026, month: 6, day: 15)
        let workoutDate = try Fixture.date(year: 2026, month: 5, day: 10, hour: 8)
        let fixture = try Fixture(historyDates: [workoutDate])
        let viewModel = fixture.makeViewModel(selectedDate: initialDate)
        viewModel.showPreviousMonth()

        viewModel.selectDate(workoutDate)

        #expect(viewModel.selectedDate == workoutDate)
        #expect(viewModel.monthViewData.days.first(where: \.isSelected)?.dayNumberText == "10")
        #expect(viewModel.selectedDaySessions.count == 1)
    }

    @Test
    func selectingDateOutsideDisplayedMonthIsIgnored() throws {
        let initialDate = try Fixture.date(year: 2026, month: 6, day: 15)
        let fixture = try Fixture(historyDates: [])
        let viewModel = fixture.makeViewModel(selectedDate: initialDate)
        let outsideDate = try Fixture.date(year: 2026, month: 5, day: 10)

        viewModel.selectDate(outsideDate)
        let expectedMonthStart = try Fixture.date(
            year: 2026,
            month: 6,
            day: 1
        )

        #expect(viewModel.selectedDate == initialDate)
        #expect(viewModel.displayedMonthStart == expectedMonthStart)
    }

    @Test
    func reachingOldestMonthPrependsAnotherPreviousMonth() throws {
        let fixture = try Fixture(historyDates: [])
        let viewModel = fixture.makeViewModel()
        let oldestMonthStart = try #require(
            viewModel.monthPages.first?.startDate
        )

        viewModel.showMonth(startingAt: oldestMonthStart)

        #expect(viewModel.displayedMonthStart == oldestMonthStart)
        #expect(viewModel.monthPages.map(\.title) == [
            "May 2026", "June 2026", "July 2026"
        ])
    }
}

private extension ProgressCalendarViewModelTests {
    // MARK: - Test Fixture

    @MainActor
    struct Fixture {
        static let now = try? date(
            year: 2026,
            month: 7,
            day: 29,
            hour: 12
        )

        let history: ProgressHistoryContext

        init(historyDates: [Date]) throws {
            let userID = UUID()
            let sessions = try historyDates.map { startedAt in
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
                    programTitle: "Push and Pull",
                    exercises: []
                )
            }

            history = ProgressHistoryContext(
                userID: userID,
                sessions: sessions
            )
        }

        func makeViewModel(
            selectedDate: Date? = nil
        ) -> ProgressCalendarViewModel {
            let calendar = Self.calendar
            return ProgressCalendarViewModel(
                historyContext: history,
                selectedDate: selectedDate,
                dateService: ProgressDateService(calendar: calendar),
                mapper: ProgressViewDataMapper(
                    calendar: calendar,
                    locale: Locale(identifier: "en_US_POSIX")
                ),
                now: { Self.now ?? .distantPast }
            )
        }

        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = Locale(identifier: "en_US_POSIX")
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            calendar.firstWeekday = 2
            return calendar
        }

        static func date(
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
    }
}
