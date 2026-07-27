import Foundation

/// Provides calendar calculations shared by the weekly overview and full history calendar.
protocol ProgressDateServicing: Sendable {
    func week(containing date: Date) -> ProgressWeek
    func month(containing date: Date) -> ProgressMonth
    func addingWeeks(_ value: Int, to date: Date) -> Date
    func addingMonths(_ value: Int, to date: Date) -> Date
    func startOfDay(for date: Date) -> Date
    func isDate(_ lhs: Date, inSameDayAs rhs: Date) -> Bool
    func groupSessionsByDay(
        _ sessions: [ProgressSessionHistory]
    ) -> [Date: [ProgressSessionHistory]]
}

struct ProgressDateService: ProgressDateServicing {
    private let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func week(containing date: Date) -> ProgressWeek {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            let day = startOfDay(for: date)
            return ProgressWeek(startDate: day, days: [day])
        }

        let startDate = startOfDay(for: interval.start)
        let days = (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: startDate)
        }

        return ProgressWeek(startDate: startDate, days: days)
    }

    func month(containing date: Date) -> ProgressMonth {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let dayRange = calendar.range(of: .day, in: .month, for: interval.start) else {
            let day = startOfDay(for: date)
            return ProgressMonth(
                startDate: day,
                days: [day],
                leadingEmptyDayCount: 0
            )
        }

        let startDate = startOfDay(for: interval.start)
        let days = dayRange.compactMap { day in
            calendar.date(bySetting: .day, value: day, of: startDate)
        }
        let weekday = calendar.component(.weekday, from: startDate)
        let leadingEmptyDayCount = (weekday - calendar.firstWeekday + 7) % 7

        return ProgressMonth(
            startDate: startDate,
            days: days,
            leadingEmptyDayCount: leadingEmptyDayCount
        )
    }

    func addingWeeks(_ value: Int, to date: Date) -> Date {
        calendar.date(byAdding: .weekOfYear, value: value, to: date) ?? date
    }

    func addingMonths(_ value: Int, to date: Date) -> Date {
        calendar.date(byAdding: .month, value: value, to: date) ?? date
    }

    func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    func isDate(_ lhs: Date, inSameDayAs rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    func groupSessionsByDay(
        _ sessions: [ProgressSessionHistory]
    ) -> [Date: [ProgressSessionHistory]] {
        Dictionary(grouping: sessions) {
            startOfDay(for: $0.session.startedAt)
        }
        .mapValues { sessionsForDay in
            sessionsForDay.sorted {
                if $0.session.startedAt == $1.session.startedAt {
                    return $0.session.id.uuidString < $1.session.id.uuidString
                }

                return $0.session.startedAt < $1.session.startedAt
            }
        }
    }
}
