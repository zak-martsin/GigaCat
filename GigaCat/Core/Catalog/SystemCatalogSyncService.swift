/// Downloads the server-owned catalog and commits it to the local source of truth.
@MainActor
protocol SystemCatalogSyncing: AnyObject {
    /// Returns `true` only when the local source of truth changed.
    func refreshSystemCatalog() async throws -> Bool
}

protocol SystemCatalogRemoteRepository: Sendable {
    func fetchSystemCatalog() async throws -> SystemCatalogSnapshot
}

@MainActor
protocol SystemCatalogLocalStore {
    /// Applies a complete snapshot and reports whether any stored catalog value changed.
    func apply(_ snapshot: SystemCatalogSnapshot) throws -> Bool
}

/// Validates and applies a server-owned catalog snapshot to the local source of truth.
@MainActor
final class SystemCatalogSyncService: SystemCatalogSyncing {
    private let remoteRepository: any SystemCatalogRemoteRepository
    private let localStore: any SystemCatalogLocalStore

    init(
        remoteRepository: any SystemCatalogRemoteRepository,
        localStore: any SystemCatalogLocalStore
    ) {
        self.remoteRepository = remoteRepository
        self.localStore = localStore
    }

    func refreshSystemCatalog() async throws -> Bool {
        let snapshot = try await remoteRepository.fetchSystemCatalog()
        guard !snapshot.entries.isEmpty else {
            throw SystemCatalogSyncError.emptyCatalog
        }
        guard snapshot.isStructurallyValid else {
            throw SystemCatalogSyncError.invalidCatalog
        }
        return try localStore.apply(snapshot)
    }
}

enum SystemCatalogSyncError: Error, Equatable {
    /// Prevents a suspicious empty response from erasing a previously cached catalog.
    case emptyCatalog
    /// Prevents incomplete relationships from replacing a coherent local snapshot.
    case invalidCatalog
}

private extension SystemCatalogSnapshot {
    var isStructurallyValid: Bool {
        let programIDs = Set(entries.map(\.id))
        let workoutDayIDs = Set(workoutDays.map(\.id))
        let exerciseIDs = Set(exercises.map(\.id))
        let dayExerciseIDs = Set(dayExercises.map(\.id))

        guard programIDs.count == entries.count,
              workoutDayIDs.count == workoutDays.count,
              exerciseIDs.count == exercises.count,
              dayExerciseIDs.count == dayExercises.count,
              entries.allSatisfy({ $0.program.authorId == nil && $0.program.isActive }),
              !workoutDays.isEmpty,
              !dayExercises.isEmpty,
              !exercises.isEmpty,
              workoutDays.allSatisfy({ programIDs.contains($0.programId) }),
              dayExercises.allSatisfy({
                  workoutDayIDs.contains($0.workoutDayId)
                      && exerciseIDs.contains($0.exerciseId)
              }) else {
            return false
        }

        return programIDs.allSatisfy { programID in
            let programDayIDs = Set(
                workoutDays
                    .filter { $0.programId == programID }
                    .map(\.id)
            )
            return !programDayIDs.isEmpty
                && programDayIDs.allSatisfy { dayID in
                    dayExercises.contains { $0.workoutDayId == dayID }
                }
        }
    }
}
