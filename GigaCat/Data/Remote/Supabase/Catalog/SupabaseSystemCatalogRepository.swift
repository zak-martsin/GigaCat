import Foundation
import Supabase

/// Narrow SDK boundary for reading the server-owned workout catalog.
protocol SupabaseSystemCatalogClient: Sendable {
    func systemPrograms() async throws -> [WorkoutProgramCatalogDTO]
    func exercises() async throws -> [ExerciseCatalogDTO]
}

struct LiveSupabaseSystemCatalogClient: SupabaseSystemCatalogClient {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func systemPrograms() async throws -> [WorkoutProgramCatalogDTO] {
        try await client
            .from("workout_programs")
            .select(
                """
                id,author_id,target_audience,title,description,tags,
                is_active,
                workout_days(
                    id,program_id,title,order_index,
                    workout_day_exercises(
                        id,workout_day_id,exercise_id,target_sets,target_reps,order_index
                    )
                )
                """
            )
            .is("author_id", value: nil)
            .eq("is_active", value: true)
            .order("title")
            .execute()
            .value
    }

    func exercises() async throws -> [ExerciseCatalogDTO] {
        try await client
            .from("exercises")
            .select("id,name,muscle_group")
            .order("name")
            .execute()
            .value
    }
}

/// Maps Supabase rows into one validated domain snapshot.
struct SupabaseSystemCatalogRepository: SystemCatalogRemoteRepository {
    private let catalogClient: any SupabaseSystemCatalogClient

    init(client: SupabaseClient) {
        catalogClient = LiveSupabaseSystemCatalogClient(client: client)
    }

    init(catalogClient: any SupabaseSystemCatalogClient) {
        self.catalogClient = catalogClient
    }

    func fetchSystemCatalog() async throws -> SystemCatalogSnapshot {
        async let programRows = catalogClient.systemPrograms()
        async let exerciseRows = catalogClient.exercises()

        let (programDTOs, exerciseDTOs) = try await (programRows, exerciseRows)

        return try SystemCatalogSnapshot(
            entries: programDTOs.map(Self.makeEntry),
            workoutDays: programDTOs
                .flatMap(\.workoutDays)
                .map(Self.makeWorkoutDay),
            dayExercises: programDTOs
                .flatMap(\.workoutDays)
                .flatMap(\.dayExercises)
                .map(Self.makeDayExercise),
            exercises: exerciseDTOs.map(Self.makeExercise)
        )
    }
}

private extension SupabaseSystemCatalogRepository {
    static func makeEntry(_ dto: WorkoutProgramCatalogDTO) throws -> ProgramCatalogEntry {
        let program = try WorkoutProgram(
            id: dto.id,
            authorId: dto.authorID,
            audience: dto.targetAudience,
            isActive: dto.isActive,
            title: dto.title,
            description: dto.description,
            tags: dto.tags
        )

        return ProgramCatalogEntry(program: program)
    }

    static func makeWorkoutDay(_ dto: WorkoutDayCatalogDTO) throws -> WorkoutDay {
        try WorkoutDay(
            id: dto.id,
            programId: dto.programID,
            title: dto.title,
            orderIndex: dto.orderIndex
        )
    }

    static func makeDayExercise(
        _ dto: WorkoutDayExerciseCatalogDTO
    ) throws -> WorkoutDayExercise {
        try WorkoutDayExercise(
            id: dto.id,
            workoutDayId: dto.workoutDayID,
            exerciseId: dto.exerciseID,
            targetSets: dto.targetSets,
            targetReps: dto.targetReps,
            orderIndex: dto.orderIndex
        )
    }

    static func makeExercise(_ dto: ExerciseCatalogDTO) throws -> Exercise {
        try Exercise(
            id: dto.id,
            name: dto.name,
            muscleGroup: dto.muscleGroup
        )
    }
}

struct WorkoutProgramCatalogDTO: Decodable, Equatable, Sendable {
    let id: UUID
    let authorID: UUID?
    let targetAudience: WorkoutProgramAudience?
    let title: String
    let description: String
    let tags: [WorkoutProgramTag]
    let isActive: Bool
    let workoutDays: [WorkoutDayCatalogDTO]

    enum CodingKeys: String, CodingKey {
        case id
        case authorID = "author_id"
        case targetAudience = "target_audience"
        case title
        case description
        case tags
        case isActive = "is_active"
        case workoutDays = "workout_days"
    }
}

struct WorkoutDayCatalogDTO: Decodable, Equatable, Sendable {
    let id: UUID
    let programID: UUID
    let title: String
    let orderIndex: Int
    let dayExercises: [WorkoutDayExerciseCatalogDTO]

    enum CodingKeys: String, CodingKey {
        case id
        case programID = "program_id"
        case title
        case orderIndex = "order_index"
        case dayExercises = "workout_day_exercises"
    }
}

struct WorkoutDayExerciseCatalogDTO: Decodable, Equatable, Sendable {
    let id: UUID
    let workoutDayID: UUID
    let exerciseID: UUID
    let targetSets: Int?
    let targetReps: Int?
    let orderIndex: Int

    enum CodingKeys: String, CodingKey {
        case id
        case workoutDayID = "workout_day_id"
        case exerciseID = "exercise_id"
        case targetSets = "target_sets"
        case targetReps = "target_reps"
        case orderIndex = "order_index"
    }
}

struct ExerciseCatalogDTO: Decodable, Equatable, Sendable {
    let id: UUID
    let name: String
    let muscleGroup: ExerciseMuscleGroup

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case muscleGroup = "muscle_group"
    }
}
