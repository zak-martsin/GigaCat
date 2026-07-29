import Foundation
import Testing
@testable import GigaCat

@MainActor
struct ProgressViewModelTests {

    @Test
    func loadBuildsCurrentWeekFromCompletedHistory() async throws {
        let fixture = try Fixture(historyDates: [
            Fixture.date(year: 2026, month: 7, day: 27, hour: 8)
        ])

        await fixture.viewModel.load()

        #expect(fixture.viewModel.loadState == .loaded)
        #expect(fixture.viewModel.historyContext == fixture.history)
        #expect(fixture.viewModel.displayedWeekStart == Fixture.date(year: 2026, month: 7, day: 27))
        #expect(fixture.viewModel.weekViewData?.days.first?.hasWorkout == true)
        #expect(fixture.viewModel.weekViewData?.canShowNextWeek == false)
    }

    @Test
    func emptyHistoryKeepsCurrentWeekAvailable() async throws {
        let fixture = try Fixture(historyDates: [])

        await fixture.viewModel.load()

        #expect(fixture.viewModel.loadState == .empty)
        #expect(fixture.viewModel.weekViewData?.days.count == 7)
        #expect(fixture.viewModel.weekViewData?.days.allSatisfy { !$0.hasWorkout } == true)
    }

    @Test
    func failedLoadClearsPreviouslyLoadedPresentation() async throws {
        let history = try Fixture.makeHistory(dates: [
            Fixture.date(year: 2026, month: 7, day: 27, hour: 8)
        ])
        let service = ProgressHistoryServiceSpy(results: [
            .success(history),
            .failure(.currentUserNotFound)
        ])
        let fixture = Fixture(history: history, historyService: service)

        await fixture.viewModel.load()
        await fixture.viewModel.load()

        #expect(fixture.viewModel.loadState == .failed)
        #expect(fixture.viewModel.historyContext == nil)
        #expect(fixture.viewModel.weekViewData == nil)
    }

    @Test
    func weekNavigationStopsAtCurrentWeek() async throws {
        let fixture = try Fixture(historyDates: [
            Fixture.date(year: 2026, month: 7, day: 20, hour: 8)
        ])
        await fixture.viewModel.load()

        fixture.viewModel.showPreviousWeek()

        #expect(fixture.viewModel.displayedWeekStart == Fixture.date(year: 2026, month: 7, day: 20))
        #expect(fixture.viewModel.weekViewData?.canShowNextWeek == true)
        #expect(fixture.viewModel.weekViewData?.days.first?.hasWorkout == true)

        fixture.viewModel.showNextWeek()
        fixture.viewModel.showNextWeek()

        #expect(fixture.viewModel.displayedWeekStart == Fixture.date(year: 2026, month: 7, day: 27))
        #expect(fixture.viewModel.weekViewData?.canShowNextWeek == false)
    }

    @Test
    func invalidationAllowsLoadIfNeededToRefreshHistory() async throws {
        let initialHistory = try Fixture.makeHistory(dates: [])
        let refreshedHistory = try Fixture.makeHistory(dates: [
            Fixture.date(year: 2026, month: 7, day: 27, hour: 8)
        ])
        let service = ProgressHistoryServiceSpy(results: [
            .success(initialHistory),
            .success(refreshedHistory)
        ])
        let fixture = Fixture(
            history: initialHistory,
            historyService: service
        )

        await fixture.viewModel.loadIfNeeded()
        await fixture.viewModel.loadIfNeeded()
        #expect(await service.loadCallCount == 1)

        fixture.viewModel.invalidate()
        await fixture.viewModel.loadIfNeeded()

        #expect(await service.loadCallCount == 2)
        #expect(fixture.viewModel.loadState == .loaded)
        #expect(fixture.viewModel.weekViewData?.days.first?.hasWorkout == true)
    }

    @Test
    func calendarViewModelRequiresLoadedHistory() throws {
        let fixture = try Fixture(historyDates: [])

        let calendarViewModel = fixture.viewModel.makeCalendarViewModel()

        #expect(calendarViewModel == nil)
    }

    @Test
    func calendarViewModelUsesSelectedDateAndLoadedHistory() async throws {
        let selectedDate = Fixture.date(
            year: 2026,
            month: 7,
            day: 27,
            hour: 8
        )
        let fixture = try Fixture(historyDates: [selectedDate])
        await fixture.viewModel.load()

        let calendarViewModel = try #require(
            fixture.viewModel.makeCalendarViewModel(
                selectedDate: selectedDate
            )
        )

        #expect(calendarViewModel.selectedDate == selectedDate)
        #expect(calendarViewModel.selectedDaySessions.count == 1)
    }

    @Test
    func calendarViewModelWithoutSelectionOpensCurrentMonth() async throws {
        let fixture = try Fixture(historyDates: [])
        await fixture.viewModel.load()

        let calendarViewModel = try #require(
            fixture.viewModel.makeCalendarViewModel()
        )

        #expect(calendarViewModel.selectedDate == nil)
        #expect(calendarViewModel.displayedMonthStart == Fixture.date(
            year: 2026,
            month: 7,
            day: 1
        ))
    }
}

private extension ProgressViewModelTests {
    // MARK: - Test Fixture

    @MainActor
    struct Fixture {
        static let now = date(year: 2026, month: 7, day: 27, hour: 12)

        let history: ProgressHistoryContext
        let viewModel: ProgressViewModel

        init(historyDates: [Date]) throws {
            let history = try Self.makeHistory(dates: historyDates)
            self.init(
                history: history,
                historyService: ProgressHistoryServiceSpy(results: [.success(history)])
            )
        }

        init(
            history: ProgressHistoryContext,
            historyService: ProgressHistoryServicing
        ) {
            let calendar = Self.calendar
            self.history = history
            viewModel = ProgressViewModel(
                historyService: historyService,
                dateService: ProgressDateService(calendar: calendar),
                mapper: ProgressViewDataMapper(
                    calendar: calendar,
                    locale: Locale(identifier: "en_US_POSIX")
                ),
                now: { Self.now }
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
        ) -> Date {
            calendar.date(
                from: DateComponents(
                    year: year,
                    month: month,
                    day: day,
                    hour: hour
                )
            ) ?? .distantPast
        }

        static func makeHistory(
            dates: [Date]
        ) throws -> ProgressHistoryContext {
            let userID = UUID()
            let sessions = try dates.map { startedAt in
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
                    exercises: []
                )
            }

            return ProgressHistoryContext(
                userID: userID,
                sessions: sessions
            )
        }
    }

    // MARK: - Test Double

    actor ProgressHistoryServiceSpy: ProgressHistoryServicing {
        private var results: [Result<ProgressHistoryContext, ProgressHistoryError>]
        private(set) var loadCallCount = 0

        init(
            results: [Result<ProgressHistoryContext, ProgressHistoryError>]
        ) {
            self.results = results
        }

        func loadHistory() async throws -> ProgressHistoryContext {
            loadCallCount += 1
            guard !results.isEmpty else {
                throw ProgressHistoryError.currentUserNotFound
            }

            return try results.removeFirst().get()
        }
    }
}
