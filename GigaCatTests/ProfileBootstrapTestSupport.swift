import Foundation
import SwiftData
@testable import GigaCat

@MainActor
struct LocalProfileFixture {
    let factory: LocalRepositoryFactory
    let userID: UUID
    let programID: UUID

    init() throws {
        let stack = try SwiftDataStack(isStoredInMemoryOnly: true)
        let userID = UUID()
        let program = try WorkoutProgram(title: "Test", description: "Test")
        stack.mainContext.insert(WorkoutProgramMapper.toEntity(program))
        stack.mainContext.insert(UserMapper.toEntity(User(id: userID)))
        try stack.mainContext.save()

        factory = LocalRepositoryFactory(
            stack: stack,
            currentUserIDProvider: CurrentUserContext(userID: userID)
        )
        self.userID = userID
        programID = program.id
    }
}

actor BlockingUserProfileRemoteRepository: UserProfileRemoteRepository {
    private let storedProfile: User
    private var didStartFetch = false
    private var fetchStartedWaiter: CheckedContinuation<Void, Never>?
    private var fetchRelease: CheckedContinuation<Void, Never>?

    init(profile: User) {
        storedProfile = profile
    }

    func profile(for _: UUID) async -> User {
        didStartFetch = true
        fetchStartedWaiter?.resume()
        fetchStartedWaiter = nil
        await withCheckedContinuation { continuation in
            fetchRelease = continuation
        }
        return storedProfile
    }

    func updateProfile(for _: UUID, selectedProgramID _: UUID?) -> User {
        storedProfile
    }

    func waitUntilFetchStarts() async {
        guard !didStartFetch else { return }
        await withCheckedContinuation { continuation in
            fetchStartedWaiter = continuation
        }
    }

    func releaseFetch() {
        fetchRelease?.resume()
        fetchRelease = nil
    }
}
