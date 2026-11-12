import Foundation
import SwiftData

/// Captures the profile shape before optional personalization fields were introduced.
/// Unchanged model types are shared; freeze their old definitions here before changing them.
enum GigaCatSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [UserEntity.self, WorkoutProgramEntity.self, WorkoutDayEntity.self,
         WorkoutDayExerciseEntity.self, ExerciseEntity.self, WorkoutSessionEntity.self,
         ExerciseLogEntity.self, SyncOperationEntity.self]
    }

    @Model
    final class WorkoutSessionEntity {
        @Attribute(.unique) var id: UUID
        var userId: UUID
        var workoutDayId: UUID
        var statusRawValue: String
        var startedAt: Date
        var completedAt: Date?

        init(id: UUID, userId: UUID, workoutDayId: UUID, statusRawValue: String, startedAt: Date, completedAt: Date?) {
            self.id = id
            self.userId = userId
            self.workoutDayId = workoutDayId
            self.statusRawValue = statusRawValue
            self.startedAt = startedAt
            self.completedAt = completedAt
        }
    }

    @Model
    final class UserEntity {
        @Attribute(.unique) var id: UUID
        var selectedProgramId: UUID?
        var createdAt: Date
        var updatedAt: Date
        var revision: Int = 0

        init(id: UUID, selectedProgramId: UUID?, createdAt: Date, updatedAt: Date) {
            self.id = id
            self.selectedProgramId = selectedProgramId
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }
}

enum GigaCatSchemaV2: VersionedSchema {
    typealias WorkoutSessionEntity = GigaCatSchemaV1.WorkoutSessionEntity
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [UserEntity.self, WorkoutProgramEntity.self, WorkoutDayEntity.self,
         WorkoutDayExerciseEntity.self, ExerciseEntity.self, WorkoutSessionEntity.self,
         ExerciseLogEntity.self, SyncOperationEntity.self]
    }
}

enum GigaCatSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [UserEntity.self, WorkoutProgramEntity.self, WorkoutDayEntity.self,
         WorkoutDayExerciseEntity.self, ExerciseEntity.self, WorkoutSessionEntity.self,
         ExerciseLogEntity.self, SyncOperationEntity.self]
    }
}

/// Preserves legacy history and clears the old two-set defaults only in the two shipped programs.
enum GigaCatSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [GigaCatSchemaV1.self, GigaCatSchemaV2.self, GigaCatSchemaV3.self]
    }
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: GigaCatSchemaV1.self, toVersion: GigaCatSchemaV2.self),
            .custom(
                fromVersion: GigaCatSchemaV2.self, toVersion: GigaCatSchemaV3.self,
                willMigrate: nil,
                didMigrate: { context in
                    try DefaultProgramTargetMigration.apply(in: context)
                }
            )
        ]
    }
}
