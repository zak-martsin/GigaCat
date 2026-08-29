//
//  SwiftDataStack.swift
//  GigaCat
//
//  Created by OpenAI on 13/08/2026.
//

import Foundation
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
        SyncOperationEntity.self
    ])

    let container: ModelContainer
    let mainContext: ModelContext

    /// Creates the app store, an isolated in-memory store, or a store at a test-controlled URL.
    init(
        isStoredInMemoryOnly: Bool = false,
        storeURL: URL? = nil
    ) throws {
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(
                "GigaCat",
                schema: Self.schema,
                url: storeURL
            )
        } else {
            configuration = ModelConfiguration(
                schema: Self.schema,
                isStoredInMemoryOnly: isStoredInMemoryOnly
            )
        }
        let container = try ModelContainer(
            for: Self.schema,
            configurations: [configuration]
        )

        self.container = container
        mainContext = container.mainContext
    }
}
