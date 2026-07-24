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
    private static let maximumSetCount = 10

    let userID: UUID
    let day: WorkoutDay
    let exercises: [WorkoutExerciseContent]
    private(set) var selectedDayExerciseID: UUID?
    private(set) var activeSession: WorkoutSession?
    private(set) var logsByDayExerciseID: [UUID: [Int: ExerciseLog]] = [:]
    private(set) var previousLogByExerciseID: [UUID: ExerciseLog] = [:]
    private(set) var setCountByDayExerciseID: [UUID: Int]
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
        setCountByDayExerciseID = Dictionary(
            uniqueKeysWithValues: orderedExercises.map {
                ($0.dayExercise.id, $0.dayExercise.targetSets)
            }
        )
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

        do {
            logsByDayExerciseID = try await loadCurrentSessionLogs()
            previousLogByExerciseID = try await loadPreviousExerciseLogs()
            logsLoadState = .loaded
        } catch {
            logsByDayExerciseID = [:]
            previousLogByExerciseID = [:]
            logsLoadState = .failed
        }
    }

    func savedLogs(dayExerciseID: UUID) -> [Int: ExerciseLog] {
        logsByDayExerciseID[dayExerciseID] ?? [:]
    }

    func previousLog(exerciseID: UUID) -> ExerciseLog? {
        previousLogByExerciseID[exerciseID]
    }

    func setCount(dayExerciseID: UUID) -> Int {
        setCountByDayExerciseID[dayExerciseID] ?? 0
    }

    func addSet() {
        guard let selectedExercise else { return }

        let dayExercise = selectedExercise.dayExercise
        let currentCount = setCountByDayExerciseID[dayExercise.id]
            ?? dayExercise.targetSets
        guard currentCount < Self.maximumSetCount else { return }

        setCountByDayExerciseID[dayExercise.id] = currentCount + 1
    }

    func saveSet(
        weightText: String,
        repsText: String,
        setNumber: Int,
        performedAt: Date = Date()
    ) async {
        guard canLogSelectedDay else { return }

        let normalizedWeight = weightText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        let normalizedReps = repsText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let weight = Double(normalizedWeight),
              let reps = Int(normalizedReps) else {
            setSaveState = .failed(setNumber: setNumber)
            return
        }

        await saveSet(
            weight: weight,
            reps: reps,
            setNumber: setNumber,
            performedAt: performedAt
        )
    }

    func saveSet(
        weight: Double,
        reps: Int,
        setNumber: Int,
        performedAt: Date = Date()
    ) async {
        guard canLogSelectedDay, let selectedExercise else { return }

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
            updateSetCount(for: result.log.workoutDayExerciseId, logs: exerciseLogs)
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

    private func loadCurrentSessionLogs() async throws -> [UUID: [Int: ExerciseLog]] {
        guard let activeSession,
              activeSession.workoutDayId == day.id else {
            return [:]
        }

        let logs = try await workoutRepository.fetchExerciseLogs(
            sessionId: activeSession.id
        )
        let groupedLogs = makeLogsByDayExerciseID(from: logs)

        for (dayExerciseID, exerciseLogs) in groupedLogs {
            updateSetCount(for: dayExerciseID, logs: exerciseLogs)
        }

        return groupedLogs
    }

    private func loadPreviousExerciseLogs() async throws -> [UUID: ExerciseLog] {
        var result: [UUID: ExerciseLog] = [:]

        for content in exercises {
            let logs = try await workoutRepository.fetchRecentExerciseLogs(
                userId: userID,
                exerciseId: content.exercise.id,
                limit: content.dayExercise.targetSets + 1
            )

            if let previousLog = logs.first(where: { $0.sessionId != activeSession?.id }) {
                result[content.exercise.id] = previousLog
            }
        }

        return result
    }

    private func updateSetCount(
        for dayExerciseID: UUID,
        logs: [Int: ExerciseLog]
    ) {
        guard let highestSavedSetNumber = logs.keys.max() else { return }
        let currentCount = setCountByDayExerciseID[dayExerciseID] ?? 0
        setCountByDayExerciseID[dayExerciseID] = max(
            currentCount,
            highestSavedSetNumber
        )
    }

    private var canLogSelectedDay: Bool {
        activeSession == nil || activeSession?.workoutDayId == day.id
    }
}
