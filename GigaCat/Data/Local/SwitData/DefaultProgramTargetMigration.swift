import Foundation
import SwiftData

/// One-time catalog data upgrade; subsequent server-provided overrides remain authoritative.
enum DefaultProgramTargetMigration {
    static func apply(in context: ModelContext) throws {
        let programIDs = Set([
            "20000000-0000-0000-0000-000000000001",
            "20000000-0000-0000-0000-000000000002"
        ].compactMap(UUID.init(uuidString:)))
        let days = try context.fetch(FetchDescriptor<WorkoutDayEntity>())
        let dayIDs = Set(days.filter { programIDs.contains($0.programId) }.map(\.id))
        for exercise in try context.fetch(FetchDescriptor<WorkoutDayExerciseEntity>())
        where dayIDs.contains(exercise.workoutDayId) {
            exercise.targetSets = nil
        }
        try context.save()
    }
}
