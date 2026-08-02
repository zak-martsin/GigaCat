import Foundation
import Observation

enum LibraryLoadState: Equatable {
    case loading
    case loaded
    case empty
    case failed
}

@MainActor
@Observable
final class LibraryViewModel {
    // MARK: - Presentation State

    private(set) var loadState: LibraryLoadState = .loading
    private(set) var programs: [WorkoutProgram] = []
    private(set) var removalErrorMessage: String?
    private(set) var programDetailErrorMessage: String?
    private(set) var presentedProgramDetail: ProgramDetail?
    private(set) var programSelectionConflictAlert: ProgramSelectionConflictAlert?

    // MARK: - Dependencies

    @ObservationIgnored
    private let userRepository: UserRepository

    @ObservationIgnored
    private let libraryRepository: WorkoutProgramLibraryRepository

    @ObservationIgnored
    private let programDetailService: ProgramDetailServicing

    @ObservationIgnored
    private let onDataChanged: AppDataChangeHandler

    @ObservationIgnored
    private var currentUser: User?

    @ObservationIgnored
    private var pendingProgramSelectionID: UUID?

    @ObservationIgnored
    private var loadTracker = DataLoadTracker()

    @ObservationIgnored
    private var isLoading = false

    @ObservationIgnored
    private var programIDsBeingRemoved: Set<UUID> = []

    // MARK: - Initialization

    init(
        userRepository: UserRepository,
        libraryRepository: WorkoutProgramLibraryRepository,
        programDetailService: ProgramDetailServicing,
        onDataChanged: @escaping AppDataChangeHandler = { _ in }
    ) {
        self.userRepository = userRepository
        self.libraryRepository = libraryRepository
        self.programDetailService = programDetailService
        self.onDataChanged = onDataChanged
    }

    // MARK: - Loading

    func loadIfNeeded() async {
        guard loadTracker.needsLoading else { return }
        await load()
    }

    /// Marks the saved-program cache stale so the next Library load reads the source of truth.
    func invalidate() {
        loadTracker.invalidate()
    }

    func load() async {
        guard !isLoading else { return }

        let loadingRevision = loadTracker.currentRevision
        isLoading = true
        loadState = .loading
        defer { isLoading = false }

        do {
            guard let user = try await userRepository.currentUser() else {
                currentUser = nil
                programs = []
                loadState = .failed
                return
            }

            let savedPrograms = try await libraryRepository.fetchSavedPrograms(for: user.id)
            currentUser = user
            programs = savedPrograms
            loadTracker.markLoaded(revision: loadingRevision)
            loadState = savedPrograms.isEmpty ? .empty : .loaded
        } catch {
            currentUser = nil
            programs = []
            loadState = .failed
        }
    }

    // MARK: - Mutations

    func removeProgram(_ programID: UUID) async {
        _ = await removeProgramMembership(programID)
    }

    func removePresentedProgramFromLibrary() async {
        guard let detail = presentedProgramDetail,
              detail.isSavedToLibrary else {
            return
        }

        guard await removeProgramMembership(detail.id) else { return }
        dismissProgramDetail()
    }

    private func removeProgramMembership(_ programID: UUID) async -> Bool {
        guard let currentUser,
              programs.contains(where: { $0.id == programID }),
              programIDsBeingRemoved.insert(programID).inserted else {
            return false
        }

        defer { programIDsBeingRemoved.remove(programID) }

        do {
            try await libraryRepository.removeProgram(programID, for: currentUser.id)
            programs.removeAll { $0.id == programID }
            loadState = programs.isEmpty ? .empty : .loaded
            await onDataChanged(.library)
            return true
        } catch {
            removalErrorMessage = error.localizedDescription
            return false
        }
    }

    func dismissRemovalError() {
        removalErrorMessage = nil
    }

    // MARK: - Program Detail

    func presentProgramDetail(for programID: UUID) async {
        do {
            guard let user = try await userRepository.currentUser() else {
                programDetailErrorMessage = "No active user was found."
                return
            }

            currentUser = user
            presentedProgramDetail = try await programDetailService.makeDetail(
                for: programID,
                user: user
            )
        } catch {
            programDetailErrorMessage = error.localizedDescription
        }
    }

    func dismissProgramDetail() {
        presentedProgramDetail = nil
    }

    func selectPresentedProgram() async {
        guard let detail = presentedProgramDetail,
              let currentUser else {
            return
        }

        do {
            let result = try await programDetailService.selectProgram(
                detail.id,
                for: currentUser
            )

            switch result {
            case let .switched(updatedUser):
                self.currentUser = updatedUser
                dismissProgramDetail()
                await onDataChanged(.selectedProgram)
            case let .blocked(pendingProgramID, alert):
                pendingProgramSelectionID = pendingProgramID
                programSelectionConflictAlert = alert
                dismissProgramDetail()
            }
        } catch {
            programDetailErrorMessage = error.localizedDescription
        }
    }

    func completeActiveSessionAndSelectPendingProgram() async {
        await resolveProgramSelectionConflict(using: .finishSession)
    }

    func cancelActiveSessionAndSelectPendingProgram() async {
        await resolveProgramSelectionConflict(using: .cancelSession)
    }

    func cancelProgramSelectionConflict() {
        pendingProgramSelectionID = nil
        programSelectionConflictAlert = nil
    }

    func completePresentedProgramSession() async {
        guard let detail = presentedProgramDetail,
              let currentUser else {
            return
        }

        do {
            let didComplete = try await programDetailService.completeActiveSession(
                for: detail.id,
                userID: currentUser.id
            )
            guard didComplete else { return }

            dismissProgramDetail()
            await onDataChanged(.workoutSession)
        } catch {
            programDetailErrorMessage = error.localizedDescription
        }
    }

    func cancelPresentedProgramSession() async {
        guard let detail = presentedProgramDetail,
              let currentUser else {
            return
        }

        do {
            let didCancel = try await programDetailService.cancelActiveSession(
                for: detail.id,
                userID: currentUser.id
            )
            guard didCancel else { return }

            dismissProgramDetail()
            await onDataChanged(.workoutSession)
        } catch {
            programDetailErrorMessage = error.localizedDescription
        }
    }

    func dismissProgramDetailError() {
        programDetailErrorMessage = nil
    }

    private func resolveProgramSelectionConflict(
        using resolution: ProgramDetailConflictResolution
    ) async {
        guard let pendingProgramSelectionID,
              let currentUser else {
            return
        }

        do {
            let updatedUser = try await programDetailService.resolveSelectionConflict(
                selecting: pendingProgramSelectionID,
                for: currentUser,
                resolution: resolution
            )
            self.currentUser = updatedUser
            cancelProgramSelectionConflict()
            await onDataChanged(.selectedProgram)
        } catch {
            programDetailErrorMessage = error.localizedDescription
        }
    }
}
