import Foundation

struct WorkoutViewData: Equatable, Sendable {
    let programTitle: String
    let sessionStatus: WorkoutSessionStatusViewData
    let days: [WorkoutDayItemViewData]
    let selectedDay: SelectedWorkoutDayViewData
}

struct WorkoutSessionStatusViewData: Equatable, Sendable {
    let title: String
    let isInProgress: Bool
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
    let exerciseID: UUID
    let name: String
    let targetSets: Int?
    let targetReps: Int?
    let artwork: ArtworkReference?
    let artworkFileURL: URL?

    var artworkLoadIdentifier: ExerciseArtworkLoadIdentifier? {
        artwork.map {
            ExerciseArtworkLoadIdentifier(
                exerciseID: exerciseID,
                artwork: $0
            )
        }
    }
}

/// Identifies one lazy exercise-artwork request across view reuse and revision changes.
struct ExerciseArtworkLoadIdentifier: Hashable, Sendable {
    let exerciseID: UUID
    let artwork: ArtworkReference
}
