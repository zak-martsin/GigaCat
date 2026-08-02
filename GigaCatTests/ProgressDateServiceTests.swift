import Foundation
import Testing
@testable import GigaCat

struct ProgressDateServiceTests {

    @Test
    func weekUsesConfiguredFirstWeekdayAcrossYearBoundary() throws {
        let fixture = Fixture()
        let date = try fixture.date(year: 2026, month: 1, day: 1)

        let week = fixture.service.week(containing: date)
        let expectedStart = try fixture.date(year: 2025, month: 12, day: 29)
        let expectedEnd = try fixture.date(year: 2026, month: 1, day: 4)

        #expect(week.startDate == expectedStart)
        #expect(week.days.count == 7)
        #expect(week.days.last == expectedEnd)
    }

    @Test
    func leapYearMonthContainsEveryDayAndCorrectLeadingSpace() throws {
        let fixture = Fixture()
        let date = try fixture.date(year: 2024, month: 2, day: 15)

        let month = fixture.service.month(containing: date)
        let expectedStart = try fixture.date(year: 2024, month: 2, day: 1)
        let expectedEnd = try fixture.date(year: 2024, month: 2, day: 29)

        #expect(month.startDate == expectedStart)
        #expect(month.days.count == 29)
        #expect(month.leadingEmptyDayCount == 3)
        #expect(month.days.last == expectedEnd)
    }

    @Test
    func addingWeeksAndMonthsPreservesCalendarNavigation() throws {
        let fixture = Fixture()
        let date = try fixture.date(year: 2025, month: 12, day: 15)

        let nextWeek = fixture.service.addingWeeks(1, to: date)
        let nextMonth = fixture.service.addingMonths(1, to: date)
        let expectedNextWeek = try fixture.date(year: 2025, month: 12, day: 22)
        let expectedNextMonth = try fixture.date(year: 2026, month: 1, day: 15)

        #expect(nextWeek == expectedNextWeek)
        #expect(nextMonth == expectedNextMonth)
    }

    @Test
    func groupsSessionsByStartDayAndOrdersThemByStartTime() throws {
        let fixture = Fixture()
        let morning = try fixture.sessionHistory(
            startedAt: fixture.date(year: 2026, month: 7, day: 24, hour: 8)
        )
        let evening = try fixture.sessionHistory(
            startedAt: fixture.date(year: 2026, month: 7, day: 24, hour: 18)
        )
        let nextDay = try fixture.sessionHistory(
            startedAt: fixture.date(year: 2026, month: 7, day: 25, hour: 7)
        )

        let grouped = fixture.service.groupSessionsByDay([evening, nextDay, morning])
        let firstDay = try fixture.date(year: 2026, month: 7, day: 24)
        let secondDay = try fixture.date(year: 2026, month: 7, day: 25)

        #expect(grouped[firstDay]?.map(\.session.id) == [morning.session.id, evening.session.id])
        #expect(grouped[secondDay]?.map(\.session.id) == [nextDay.session.id])
    }
}

private extension ProgressDateServiceTests {
    struct Fixture {
        let calendar: Calendar
        let service: ProgressDateService

        init() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = Locale(identifier: "en_US_POSIX")
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            calendar.firstWeekday = 2
            self.calendar = calendar
            service = ProgressDateService(calendar: calendar)
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

        func sessionHistory(startedAt: Date) throws -> ProgressSessionHistory {
            let workoutDay = try WorkoutDay(
                programId: UUID(),
                title: "Workout",
                orderIndex: 0
            )
            let session = try WorkoutSession(
                userId: UUID(),
                workoutDayId: workoutDay.id,
                status: .completed,
                startedAt: startedAt,
                completedAt: startedAt.addingTimeInterval(3_600)
            )

            return ProgressSessionHistory(
                session: session,
                workoutDay: workoutDay,
                programTitle: "Test Program",
                exercises: []
            )
        }
    }
}
