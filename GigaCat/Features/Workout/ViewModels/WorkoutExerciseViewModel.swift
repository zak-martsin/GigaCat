import Foundation
import Observation

enum WorkoutExerciseLogsLoadState: Equatable {
    case loading
    case loaded
    case failed
}

enum WorkoutSetSaveState: Equatable {
    case ready
    case saving(setNumber: Int)
    case saved(setNumber: Int, didStartSession: Bool)
    case failed(setNumber: Int)
}

@MainActor
@Observable
final class WorkoutExerciseViewModel {
    let userID: UUID
    let day: WorkoutDay
    let exercises: [WorkoutExerciseContent]
    private(set) var selectedDayExerciseID: UUID?
    private(set) var activeSession: WorkoutSession?
    private(set) var logsByDayExerciseID: [UUID: [Int: ExerciseLog]] = [:]
    private(set) var logsLoadState: WorkoutExerciseLogsLoadState = .loading
    private(set) var setSaveState: WorkoutSetSaveState = .ready

    @ObservationIgnored
    private let workoutRepository: WorkoutRepository

    @ObservationIgnored
    private let onSessionChanged: (WorkoutSession) -> Void

    init(
        userID: UUID,
        activeSession: WorkoutSession?,
        dayContent: WorkoutDayContent,
        initialDayExerciseID: UUID,
        workoutRepository: WorkoutRepository,
        onSessionChanged: @escaping (WorkoutSession) -> Void = { _ in }
    ) {
        let orderedExercises = dayContent.exercises.sorted {
            $0.dayExercise.orderIndex < $1.dayExercise.orderIndex
        }

        self.userID = userID
        day = dayContent.day
        exercises = orderedExercises
        self.activeSession = activeSession
        self.workoutRepository = workoutRepository
        self.onSessionChanged = onSessionChanged
        selectedDayExerciseID = orderedExercises.contains {
            $0.dayExercise.id == initialDayExerciseID
        } ? initialDayExerciseID : orderedExercises.first?.dayExercise.id
    }

    var selectedExercise: WorkoutExerciseContent? {
        guard let selectedDayExerciseID else { return nil }
        return exercises.first { $0.dayExercise.id == selectedDayExerciseID }
    }

    var selectedExerciseIndex: Int? {
        guard let selectedDayExerciseID else { return nil }
        return exercises.firstIndex { $0.dayExercise.id == selectedDayExerciseID }
    }

    var canSelectPreviousExercise: Bool {
        guard let selectedExerciseIndex else { return false }
        return selectedExerciseIndex > exercises.startIndex
    }

    var canSelectNextExercise: Bool {
        guard let selectedExerciseIndex else { return false }
        return selectedExerciseIndex < exercises.index(before: exercises.endIndex)
    }

    func selectPreviousExercise() {
        guard let selectedExerciseIndex, canSelectPreviousExercise else { return }
        selectedDayExerciseID = exercises[selectedExerciseIndex - 1].dayExercise.id
    }

    func selectNextExercise() {
        guard let selectedExerciseIndex, canSelectNextExercise else { return }
        selectedDayExerciseID = exercises[selectedExerciseIndex + 1].dayExercise.id
    }

    func loadLogs() async {
        logsLoadState = .loading

        guard let activeSession,
              activeSession.workoutDayId == day.id else {
            logsByDayExerciseID = [:]
            logsLoadState = .loaded
            return
        }

        do {
            let logs = try await workoutRepository.fetchExerciseLogs(
                sessionId: activeSession.id
            )
            logsByDayExerciseID = makeLogsByDayExerciseID(from: logs)
            logsLoadState = .loaded
        } catch {
            logsByDayExerciseID = [:]
            logsLoadState = .failed
        }
    }

    func savedLog(
        dayExerciseID: UUID,
        setNumber: Int
    ) -> ExerciseLog? {
        logsByDayExerciseID[dayExerciseID]?[setNumber]
    }

    func saveSet(
        weight: Double,
        reps: Int,
        setNumber: Int,
        performedAt: Date = Date()
    ) async {
        guard let selectedExercise else { return }

        setSaveState = .saving(setNumber: setNumber)

        do {
            let result = try await workoutRepository.saveSet(
                WorkoutSetInput(
                    userId: userID,
                    workoutDayId: day.id,
                    workoutDayExerciseId: selectedExercise.dayExercise.id,
                    weight: weight,
                    reps: reps,
                    setNumber: setNumber,
                    performedAt: performedAt
                )
            )

            activeSession = result.session
            var exerciseLogs = logsByDayExerciseID[result.log.workoutDayExerciseId] ?? [:]
            exerciseLogs[result.log.setNumber] = result.log
            logsByDayExerciseID[result.log.workoutDayExerciseId] = exerciseLogs
            setSaveState = .saved(
                setNumber: result.log.setNumber,
                didStartSession: result.didStartSession
            )
            onSessionChanged(result.session)
        } catch {
            setSaveState = .failed(setNumber: setNumber)
        }
    }

    private func makeLogsByDayExerciseID(
        from logs: [ExerciseLog]
    ) -> [UUID: [Int: ExerciseLog]] {
        let validExerciseIDs = Set(exercises.map(\.dayExercise.id))
        var result: [UUID: [Int: ExerciseLog]] = [:]

        for log in logs where validExerciseIDs.contains(log.workoutDayExerciseId) {
            var exerciseLogs = result[log.workoutDayExerciseId] ?? [:]
            exerciseLogs[log.setNumber] = log
            result[log.workoutDayExerciseId] = exerciseLogs
        }

        return result
    }
}
