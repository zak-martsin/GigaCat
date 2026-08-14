//
//  SwiftDataStack.swift
//  GigaCat
//
//  Created by OpenAI on 13/08/2026.
//

import SwiftData

/// Owns the shared SwiftData schema and container used by local repositories.
@MainActor
final class SwiftDataStack {
    static let schema = Schema([
        UserEntity.self,
        WorkoutProgramEntity.self,
        WorkoutDayEntity.self,
        WorkoutDayExerciseEntity.self,
        ExerciseEntity.self,
        WorkoutSessionEntity.self,
        ExerciseLogEntity.self,
        SavedWorkoutProgramEntity.self,
        ProgramCatalogMetadataEntity.self
    ])

    let container: ModelContainer
    let mainContext: ModelContext

    /// Creates a disk-backed store for the app or an isolated in-memory store for tests.
    init(isStoredInMemoryOnly: Bool = false) throws {
        let configuration = ModelConfiguration(
            schema: Self.schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        let container = try ModelContainer(
            for: Self.schema,
            configurations: [configuration]
        )

        self.container = container
        mainContext = container.mainContext
    }
}
