import Foundation

extension MockSeedData {
    static func makeUsers(_ context: MockSeedContext) -> [User] {
        compact([
            try? User(
                id: context.currentUserID,
                appleUserId: "mock-apple-user",
                selectedProgramId: context.upperBodyProgramID,
                createdAt: context.createdAt,
                updatedAt: context.createdAt
            ),
            try? User(
                id: context.secondUserID,
                appleUserId: "mock-second-user",
                selectedProgramId: context.strengthProgramID,
                createdAt: context.createdAt.addingTimeInterval(600),
                updatedAt: context.createdAt.addingTimeInterval(600)
            )
        ])
    }

    static func makePrograms(_ context: MockSeedContext) -> [WorkoutProgram] {
        compact([
            try? WorkoutProgram(
                id: context.upperBodyProgramID,
                title: "Upper Body Foundation",
                description: "A three-day upper body split focused on steady strength and hypertrophy work.",
                tags: [.gym, .strength, .muscleGain]
            ),
            try? WorkoutProgram(
                id: context.strengthProgramID,
                title: "Strength Essentials",
                description: "A barbell-focused plan built around compound lifts and simple linear progression.",
                tags: [.gym, .strength, .muscleGain]
            ),
            try? WorkoutProgram(
                id: context.conditioningProgramID,
                title: "Conditioning Boost",
                description: "A faster, lighter training block for work capacity, cardio, and bodyweight output.",
                tags: [.home, .cardio, .hiit, .mobility, .bodyweight]
            ),
            try? WorkoutProgram(
                id: context.mobilityProgramID,
                title: "Mobility Reset",
                description: "A recovery-focused program for posture, movement quality, and full-body mobility.",
                tags: [.home, .mobility, .bodyweight]
            )
        ])
    }

    static func makeHomeProgramCatalogMetadata(
        _ context: MockSeedContext
    ) -> [UUID: HomeProgramCatalogMetadata] {
        [
            context.upperBodyProgramID: HomeProgramCatalogMetadata(
                isRecommended: true,
                isPopular: true,
                rateScore: 4.8
            ),
            context.strengthProgramID: HomeProgramCatalogMetadata(
                isRecommended: true,
                isPopular: true,
                rateScore: 4.9
            ),
            context.conditioningProgramID: HomeProgramCatalogMetadata(
                isRecommended: false,
                isPopular: true,
                rateScore: 4.6
            ),
            context.mobilityProgramID: HomeProgramCatalogMetadata(
                isRecommended: false,
                isPopular: false,
                rateScore: nil
            )
        ]
    }
}
