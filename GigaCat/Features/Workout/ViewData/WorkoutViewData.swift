import Foundation

struct WorkoutViewData: Equatable, Sendable {
    let programTitle: String
    let days: [WorkoutDayItemViewData]
    let selectedDay: SelectedWorkoutDayViewData
}

struct WorkoutDayItemViewData: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let isSelected: Bool
    let hasActiveSession: Bool
}

struct SelectedWorkoutDayViewData: Identifiable, Equatable, Sendable {
    let id: UUID
    let exercises: [WorkoutExerciseViewData]
}

struct WorkoutExerciseViewData: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let targetSets: Int
    let targetReps: Int
}
