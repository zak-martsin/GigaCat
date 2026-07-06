import Foundation

protocol HomeViewDataMapping: Sendable {
    func mapProgramSectionItem(
        entry: HomeProgramCatalogEntry,
        dayCount: Int,
        exerciseCount: Int,
        selectedProgramID: UUID?
    ) -> ProgramSectionItem

    func mapSelectedProgramSummary(
        entry: HomeProgramCatalogEntry,
        dayCount: Int,
        nextWorkoutTitle: String?,
        progressText: String?
    ) -> SelectedProgramSummary

    func mapMiniPlayerPresentationForActiveSession(
        session: WorkoutSession,
        programTitle: String,
        workoutDayTitle: String,
        completionPercentage: Int,
        isExpired: Bool
    ) -> MiniPlayerPresentation

    func mapMiniPlayerPresentationForNoProgramSelected() -> MiniPlayerPresentation

    func mapMiniPlayerPresentationForProgramWithoutDays(
        programTitle: String
    ) -> MiniPlayerPresentation

    func mapMiniPlayerPresentationForReadyToStart(
        programTitle: String,
        workoutDayID: UUID,
        workoutDayTitle: String
    ) -> MiniPlayerPresentation

    func mapProgramDetail(
        item: ProgramSectionItem,
        primaryAction: ProgramDetail.PrimaryAction,
        progressText: String?,
        hasActiveSession: Bool,
        workoutDayTitles: [String]
    ) -> ProgramDetail
}

struct HomeViewDataMapper: HomeViewDataMapping {
    func mapProgramSectionItem(
        entry: HomeProgramCatalogEntry,
        dayCount: Int,
        exerciseCount: Int,
        selectedProgramID: UUID?
    ) -> ProgramSectionItem {
        ProgramSectionItem(
            id: entry.program.id,
            title: entry.program.title,
            description: entry.program.description,
            dayCount: dayCount,
            exerciseCount: exerciseCount,
            rateScore: entry.rateScore,
            isSelected: selectedProgramID == entry.program.id,
            isRecommended: entry.isRecommended,
            isPopular: entry.isPopular,
            tags: entry.program.tags
        )
    }

    func mapSelectedProgramSummary(
        entry: HomeProgramCatalogEntry,
        dayCount: Int,
        nextWorkoutTitle: String?,
        progressText: String?
    ) -> SelectedProgramSummary {
        SelectedProgramSummary(
            id: entry.program.id,
            title: entry.program.title,
            subtitle: "\(dayCount) workout days",
            nextWorkoutTitle: nextWorkoutTitle,
            progressText: progressText
        )
    }

    func mapMiniPlayerPresentationForActiveSession(
        session: WorkoutSession,
        programTitle: String,
        workoutDayTitle: String,
        completionPercentage: Int,
        isExpired: Bool
    ) -> MiniPlayerPresentation {
        MiniPlayerPresentation(
            state: MiniPlayerState(
                title: programTitle,
                subtitle: "\(workoutDayTitle) • \(completionPercentage)% completed",
                action: .continueWorkout
            ),
            context: .activeSession(
                session: session,
                programTitle: programTitle,
                workoutDayTitle: workoutDayTitle,
                isExpired: isExpired
            )
        )
    }

    func mapMiniPlayerPresentationForNoProgramSelected() -> MiniPlayerPresentation {
        MiniPlayerPresentation(
            state: MiniPlayerState(
                title: "No Program Selected",
                subtitle: "Choose a program to start training.",
                action: .none
            ),
            context: .noProgramSelected
        )
    }

    func mapMiniPlayerPresentationForProgramWithoutDays(
        programTitle: String
    ) -> MiniPlayerPresentation {
        MiniPlayerPresentation(
            state: MiniPlayerState(
                title: programTitle,
                subtitle: "This program has no workout days yet.",
                action: .none
            ),
            context: .noProgramSelected
        )
    }

    func mapMiniPlayerPresentationForReadyToStart(
        programTitle: String,
        workoutDayID: UUID,
        workoutDayTitle: String
    ) -> MiniPlayerPresentation {
        MiniPlayerPresentation(
            state: MiniPlayerState(
                title: programTitle,
                subtitle: "Next workout: \(workoutDayTitle)",
                action: .start
            ),
            context: .readyToStart(workoutDayID: workoutDayID)
        )
    }

    func mapProgramDetail(
        item: ProgramSectionItem,
        primaryAction: ProgramDetail.PrimaryAction,
        progressText: String?,
        hasActiveSession: Bool,
        workoutDayTitles: [String]
    ) -> ProgramDetail {
        ProgramDetail(
            id: item.id,
            title: item.title,
            description: item.description,
            dayCount: item.dayCount,
            exerciseCount: item.exerciseCount,
            rateScore: item.rateScore,
            isSelected: item.isSelected,
            primaryAction: primaryAction,
            progressText: progressText,
            hasActiveSession: hasActiveSession,
            tags: item.tags,
            workoutDayTitles: workoutDayTitles
        )
    }
}
