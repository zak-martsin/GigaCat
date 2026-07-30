import Foundation

struct ProgressWeekViewData: Identifiable, Equatable, Sendable {
    var id: Date { startDate }

    let startDate: Date
    let monthTitle: String
    let days: [ProgressWeekDayViewData]
    let canShowNextWeek: Bool
}

struct ProgressWeekDayViewData: Identifiable, Equatable, Sendable {
    var id: Date { date }

    let date: Date
    let weekdayText: String
    let dayNumberText: String
    let hasWorkout: Bool
    let isToday: Bool
}

struct ProgressMonthViewData: Equatable, Sendable {
    let title: String
    let weekdayTitles: [String]
    let leadingEmptyDayCount: Int
    let days: [ProgressCalendarDayViewData]
}

struct ProgressCalendarDayViewData: Identifiable, Equatable, Sendable {
    var id: Date { date }

    let date: Date
    let dayNumberText: String
    let hasWorkout: Bool
    let isSelected: Bool
    let isToday: Bool
}

struct ProgressSessionViewData: Identifiable, Equatable, Sendable {
    let id: UUID
    let workoutDayTitle: String
    let timeText: String
    let exercises: [ProgressExerciseViewData]
}

struct ProgressExerciseViewData: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let sets: [ProgressSetViewData]
}

struct ProgressSetViewData: Identifiable, Equatable, Sendable {
    let id: UUID
    let setNumberText: String
    let weightText: String
    let repetitionsText: String
}
