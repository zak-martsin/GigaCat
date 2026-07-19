import Foundation

struct WorkoutViewData: Equatable, Sendable {
    let programTitle: String
    let programDescription: String
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
    let title: String
    let exercises: [WorkoutExerciseViewData]
}

struct WorkoutExerciseViewData: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let muscleGroup: String
    let targetSets: Int
    let targetReps: Int
    let targetWeight: Double?
}
