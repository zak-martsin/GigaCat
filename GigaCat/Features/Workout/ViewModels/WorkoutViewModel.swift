import Foundation
import Observation

enum WorkoutLoadState: Equatable {
    case loading
    case loaded
    case failed
}

@MainActor
@Observable
final class WorkoutViewModel {
    private(set) var context: WorkoutContext?
    private(set) var loadState: WorkoutLoadState = .loading
    private(set) var selectedDayID: UUID?

    @ObservationIgnored
    private let contextService: WorkoutContextServicing

    @ObservationIgnored
    private let workoutRepository: WorkoutRepository

    init(
        contextService: WorkoutContextServicing,
        workoutRepository: WorkoutRepository
    ) {
        self.contextService = contextService
        self.workoutRepository = workoutRepository
    }

    var program: WorkoutProgram? {
        context?.program
    }

    var days: [WorkoutDay] {
        context?.dayContents.map(\.day) ?? []
    }

    var selectedDayContent: WorkoutDayContent? {
        guard let selectedDayID else { return nil }
        return context?.dayContents.first { $0.day.id == selectedDayID }
    }

    var selectedDay: WorkoutDay? {
        selectedDayContent?.day
    }

    var activeSession: WorkoutSession? {
        context?.activeSession
    }

    /// Reloads the workout entry context whenever the user enters the Workout flow.
    func load() async {
        loadState = .loading

        do {
            let context = try await contextService.loadContext()
            self.context = context
            selectedDayID = context.initialDayID
            loadState = .loaded
        } catch {
            context = nil
            selectedDayID = nil
            loadState = .failed
        }
    }

    /// Changes the inspected day without changing the day of an active session.
    func selectDay(id: UUID) {
        guard days.contains(where: { $0.id == id }) else { return }
        selectedDayID = id
    }

    func makeExerciseViewModel(
        dayContent: WorkoutDayContent,
        initialDayExerciseID: UUID
    ) -> WorkoutExerciseViewModel? {
        guard let context,
              context.dayContents.contains(where: { $0.day.id == dayContent.day.id }) else {
            return nil
        }

        return WorkoutExerciseViewModel(
            userID: context.userID,
            activeSession: context.activeSession,
            dayContent: dayContent,
            initialDayExerciseID: initialDayExerciseID,
            workoutRepository: workoutRepository,
            onSessionChanged: updateActiveSession
        )
    }

    private func updateActiveSession(_ session: WorkoutSession) {
        guard let context else { return }

        self.context = WorkoutContext(
            userID: context.userID,
            program: context.program,
            dayContents: context.dayContents,
            initialDayID: context.initialDayID,
            activeSession: session
        )
    }
}
