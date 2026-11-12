import Foundation

struct WorkoutSetDraftKey: Hashable, Sendable {
    let dayExerciseID: UUID
    let setNumber: Int
}

struct WorkoutSetDraft: Equatable, Sendable {
    var weightText: String
    var repsText: String
}

/// Keeps unsaved input alive while the exercise detail screen switches between exercises.
struct WorkoutSetDraftCollection: Equatable, Sendable {
    private var draftsByKey: [WorkoutSetDraftKey: WorkoutSetDraft] = [:]

    func draft(
        for key: WorkoutSetDraftKey,
        fallback: WorkoutSetDraft
    ) -> WorkoutSetDraft {
        draftsByKey[key] ?? fallback
    }

    func highestEnteredSetNumber(for dayExerciseID: UUID) -> Int {
        draftsByKey.filter { key, value in
            key.dayExerciseID == dayExerciseID && (!value.weightText.isEmpty || !value.repsText.isEmpty)
        }.keys.map(\.setNumber).max() ?? 0
    }

    mutating func update(
        _ draft: WorkoutSetDraft,
        for key: WorkoutSetDraftKey
    ) {
        draftsByKey[key] = draft
    }
}
