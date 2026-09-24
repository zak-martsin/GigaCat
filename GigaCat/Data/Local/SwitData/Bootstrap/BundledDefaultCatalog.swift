import Foundation

/// Loads the production fallback catalog bundled for first-launch offline use.
enum BundledDefaultCatalog {
    static func load(bundle: Bundle = .main) throws -> WorkoutCatalogSeed {
        guard let url = bundle.url(forResource: "DefaultCatalog", withExtension: "json") else {
            throw BundledDefaultCatalogError.resourceNotFound
        }

        return try decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> WorkoutCatalogSeed {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        let catalog = try WorkoutCatalogSeed(
            programs: payload.programs.map { try $0.makeDomain() },
            workoutDays: payload.workoutDays.map { try $0.makeDomain() },
            dayExercises: payload.dayExercises.map { try $0.makeDomain() },
            exercises: payload.exercises.map { try $0.makeDomain() }
        )
        try validate(catalog)
        return catalog
    }
}

enum BundledDefaultCatalogError: Error, Equatable {
    case resourceNotFound
    case invalidStructure
}

private extension BundledDefaultCatalog {
    struct Payload: Decodable {
        let programs: [ProgramPayload]
        let workoutDays: [WorkoutDayPayload]
        let dayExercises: [DayExercisePayload]
        let exercises: [ExercisePayload]
    }

    struct ProgramPayload: Decodable {
        let id: UUID
        let authorId: UUID?
        let audience: WorkoutProgramAudience?
        let isActive: Bool
        let title: String
        let description: String
        let tags: [WorkoutProgramTag]
        let artworkPath: String?
        let artworkRevision: Int

        func makeDomain() throws -> WorkoutProgram {
            try WorkoutProgram(
                id: id,
                authorId: authorId,
                audience: audience,
                isActive: isActive,
                title: title,
                description: description,
                tags: tags,
                artwork: try makeArtwork()
            )
        }

        private func makeArtwork() throws -> ProgramArtwork? {
            guard let artworkPath else { return nil }
            return try ProgramArtwork(path: artworkPath, revision: artworkRevision)
        }
    }

    struct WorkoutDayPayload: Decodable {
        let id: UUID
        let programId: UUID
        let title: String
        let orderIndex: Int

        func makeDomain() throws -> WorkoutDay {
            try WorkoutDay(
                id: id,
                programId: programId,
                title: title,
                orderIndex: orderIndex
            )
        }
    }

    struct DayExercisePayload: Decodable {
        let id: UUID
        let workoutDayId: UUID
        let exerciseId: UUID
        let targetSets: Int?
        let targetReps: Int?
        let orderIndex: Int

        func makeDomain() throws -> WorkoutDayExercise {
            try WorkoutDayExercise(
                id: id,
                workoutDayId: workoutDayId,
                exerciseId: exerciseId,
                targetSets: targetSets,
                targetReps: targetReps,
                orderIndex: orderIndex
            )
        }
    }

    struct ExercisePayload: Decodable {
        let id: UUID
        let name: String
        let muscleGroup: ExerciseMuscleGroup

        func makeDomain() throws -> Exercise {
            try Exercise(id: id, name: name, muscleGroup: muscleGroup)
        }
    }

    static func validate(_ catalog: WorkoutCatalogSeed) throws {
        let programIDs = Set(catalog.programs.map(\.id))
        let dayIDs = Set(catalog.workoutDays.map(\.id))
        let assignmentIDs = Set(catalog.dayExercises.map(\.id))
        let exerciseIDs = Set(catalog.exercises.map(\.id))

        guard !programIDs.isEmpty,
              programIDs.count == catalog.programs.count,
              dayIDs.count == catalog.workoutDays.count,
              assignmentIDs.count == catalog.dayExercises.count,
              exerciseIDs.count == catalog.exercises.count,
              catalog.programs.allSatisfy({ $0.authorId == nil && $0.isActive }),
              catalog.workoutDays.allSatisfy({ programIDs.contains($0.programId) }),
              catalog.dayExercises.allSatisfy({
                  dayIDs.contains($0.workoutDayId) && exerciseIDs.contains($0.exerciseId)
              }),
              programIDs.allSatisfy({ programID in
                  catalog.workoutDays.contains { $0.programId == programID }
              }),
              dayIDs.allSatisfy({ dayID in
                  catalog.dayExercises.contains { $0.workoutDayId == dayID }
              }) else {
            throw BundledDefaultCatalogError.invalidStructure
        }
    }
}
