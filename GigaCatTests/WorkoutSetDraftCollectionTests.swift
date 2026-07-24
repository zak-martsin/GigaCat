import Foundation
import Testing
@testable import GigaCat

struct WorkoutSetDraftCollectionTests {

    @Test
    func keepsDraftsSeparateByExerciseAndSetNumber() {
        var collection = WorkoutSetDraftCollection()
        let firstKey = WorkoutSetDraftKey(dayExerciseID: UUID(), setNumber: 1)
        let secondKey = WorkoutSetDraftKey(dayExerciseID: UUID(), setNumber: 1)
        let firstDraft = WorkoutSetDraft(weightText: "60", repsText: "8")
        let secondDraft = WorkoutSetDraft(weightText: "40", repsText: "12")

        collection.update(firstDraft, for: firstKey)
        collection.update(secondDraft, for: secondKey)

        #expect(collection.draft(for: firstKey, fallback: secondDraft) == firstDraft)
        #expect(collection.draft(for: secondKey, fallback: firstDraft) == secondDraft)
    }

    @Test
    func updatingSavedValuesReplacesExistingDraft() {
        var collection = WorkoutSetDraftCollection()
        let key = WorkoutSetDraftKey(dayExerciseID: UUID(), setNumber: 2)
        collection.update(
            WorkoutSetDraft(weightText: "62", repsText: "7"),
            for: key
        )

        collection.update(
            WorkoutSetDraft(weightText: "62.5", repsText: "8"),
            for: key
        )

        #expect(
            collection.draft(
                for: key,
                fallback: WorkoutSetDraft(weightText: "", repsText: "")
            ) == WorkoutSetDraft(weightText: "62.5", repsText: "8")
        )
    }
}
