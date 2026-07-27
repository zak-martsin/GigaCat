import Foundation

/// Projects resolved workout history and calendar periods into Progress presentation data.
protocol ProgressViewDataMapping: Sendable {
    func mapWeek(
        _ week: ProgressWeek,
        history: ProgressHistoryContext,
        today: Date,
        canShowNextWeek: Bool
    ) -> ProgressWeekViewData

    func mapMonth(
        _ month: ProgressMonth,
        history: ProgressHistoryContext,
        selectedDate: Date,
        today: Date
    ) -> ProgressMonthViewData

    func mapSessions(
        on date: Date,
        history: ProgressHistoryContext
    ) -> [ProgressSessionViewData]
}

struct ProgressViewDataMapper: ProgressViewDataMapping {
    private let calendar: Calendar
    private let locale: Locale

    init(
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) {
        self.calendar = calendar
        self.locale = locale
    }

    func mapWeek(
        _ week: ProgressWeek,
        history: ProgressHistoryContext,
        today: Date,
        canShowNextWeek: Bool
    ) -> ProgressWeekViewData {
        let workoutDays = workoutDayDates(in: history)

        return ProgressWeekViewData(
            periodTitle: makeWeekPeriodTitle(from: week),
            days: week.days.map { date in
                ProgressWeekDayViewData(
                    date: date,
                    weekdayText: weekdayTitle(for: date),
                    dayNumberText: dayNumber(for: date),
                    hasWorkout: workoutDays.contains(calendar.startOfDay(for: date)),
                    isToday: calendar.isDate(date, inSameDayAs: today)
                )
            },
            canShowNextWeek: canShowNextWeek
        )
    }

    func mapMonth(
        _ month: ProgressMonth,
        history: ProgressHistoryContext,
        selectedDate: Date,
        today: Date
    ) -> ProgressMonthViewData {
        let workoutDays = workoutDayDates(in: history)

        return ProgressMonthViewData(
            title: formattedDate(month.startDate, template: "LLLL yyyy"),
            weekdayTitles: orderedWeekdayTitles(),
            leadingEmptyDayCount: month.leadingEmptyDayCount,
            days: month.days.map { date in
                ProgressCalendarDayViewData(
                    date: date,
                    dayNumberText: dayNumber(for: date),
                    hasWorkout: workoutDays.contains(calendar.startOfDay(for: date)),
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isToday: calendar.isDate(date, inSameDayAs: today)
                )
            }
        )
    }

    func mapSessions(
        on date: Date,
        history: ProgressHistoryContext
    ) -> [ProgressSessionViewData] {
        history.sessions
            .filter { calendar.isDate($0.session.startedAt, inSameDayAs: date) }
            .sorted(by: Self.isEarlierSession)
            .map(mapSession)
    }

    private func mapSession(
        _ history: ProgressSessionHistory
    ) -> ProgressSessionViewData {
        ProgressSessionViewData(
            id: history.session.id,
            workoutDayTitle: history.workoutDay.title,
            timeText: formattedTime(history.session.startedAt),
            exercises: history.exercises.map { exerciseHistory in
                ProgressExerciseViewData(
                    id: exerciseHistory.dayExercise.id,
                    name: exerciseHistory.exercise.name,
                    sets: exerciseHistory.logs.map(mapSet)
                )
            }
        )
    }

    private func mapSet(_ log: ExerciseLog) -> ProgressSetViewData {
        ProgressSetViewData(
            id: log.id,
            setNumberText: String(log.setNumber),
            weightText: "\(formattedWeight(log.weight)) kg",
            repetitionsText: "\(log.reps) \(log.reps == 1 ? "rep" : "reps")"
        )
    }

    private func workoutDayDates(
        in history: ProgressHistoryContext
    ) -> Set<Date> {
        Set(history.sessions.map {
            calendar.startOfDay(for: $0.session.startedAt)
        })
    }

    private func makeWeekPeriodTitle(from week: ProgressWeek) -> String {
        guard let endDate = week.days.last else {
            return formattedDate(week.startDate, template: "d MMM")
        }

        let startComponents = calendar.dateComponents(
            [.month, .year],
            from: week.startDate
        )
        let endComponents = calendar.dateComponents(
            [.month, .year],
            from: endDate
        )
        let includesYear = startComponents.year != endComponents.year
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateTemplate = includesYear ? "d MMM yyyy" : "d MMM"
        return formatter.string(from: week.startDate, to: endDate)
    }

    private func orderedWeekdayTitles() -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return symbols }

        return (0..<symbols.count).map { offset in
            let index = (calendar.firstWeekday - 1 + offset) % symbols.count
            return symbols[index]
        }
    }

    private func weekdayTitle(for date: Date) -> String {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let index = calendar.component(.weekday, from: date) - 1
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }

    private func dayNumber(for date: Date) -> String {
        String(calendar.component(.day, from: date))
    }

    private func formattedDate(
        _ date: Date,
        template: String
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formattedWeight(_ weight: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: weight)) ?? String(weight)
    }

    private static func isEarlierSession(
        _ lhs: ProgressSessionHistory,
        _ rhs: ProgressSessionHistory
    ) -> Bool {
        if lhs.session.startedAt == rhs.session.startedAt {
            return lhs.session.id.uuidString < rhs.session.id.uuidString
        }

        return lhs.session.startedAt < rhs.session.startedAt
    }
}
