import Foundation
@testable import GigaCat

actor ArtworkServiceTestDouble: ArtworkServicing {
    enum TestError: Error {
        case unavailable
    }

    struct Request: Equatable, Sendable {
        let owner: ArtworkOwner
        let artwork: ArtworkReference
    }

    private let result: Result<URL, TestError>
    private(set) var requests: [Request] = []

    init(fileURL: URL = URL(filePath: "/tmp/exercise-artwork.png")) {
        result = .success(fileURL)
    }

    init(error: TestError) {
        result = .failure(error)
    }

    func fileURL(
        for owner: ArtworkOwner,
        artwork: ArtworkReference
    ) async throws -> URL {
        requests.append(Request(owner: owner, artwork: artwork))
        return try result.get()
    }
}

@MainActor
extension WorkoutViewModel {
    convenience init(
        contextService: WorkoutContextServicing,
        workoutRepository: WorkoutRepository,
        onDataChanged: @escaping AppDataChangeHandler = { _ in }
    ) {
        self.init(
            contextService: contextService,
            workoutRepository: workoutRepository,
            artworkService: ArtworkServiceTestDouble(),
            onDataChanged: onDataChanged
        )
    }
}

@MainActor
extension WorkoutExerciseViewModel {
    convenience init(
        userID: UUID,
        activeSession: WorkoutSession?,
        dayContent: WorkoutDayContent,
        initialDayExerciseID: UUID,
        initialSetCounts: [UUID: Int] = [:],
        workoutRepository: WorkoutRepository,
        onEvent: @escaping (WorkoutExerciseEvent) -> Void = { _ in },
        onDataChanged: @escaping AppDataChangeHandler = { _ in }
    ) {
        self.init(
            userID: userID,
            activeSession: activeSession,
            dayContent: dayContent,
            initialDayExerciseID: initialDayExerciseID,
            initialSetCounts: initialSetCounts,
            workoutRepository: workoutRepository,
            artworkService: ArtworkServiceTestDouble(),
            onEvent: onEvent,
            onDataChanged: onDataChanged
        )
    }
}
