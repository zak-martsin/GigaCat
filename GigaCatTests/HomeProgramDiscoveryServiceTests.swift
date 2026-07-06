import Foundation
import Testing
@testable import GigaCat

struct HomeProgramDiscoveryServiceTests {
    private let service = HomeProgramDiscoveryService()

    @Test
    func availableTagsUsePreferredOrderAndOnlyIncludeCatalogTags() {
        let programs = [
            makeProgram(title: "Street Strength", tags: [.strength, .streetWorkout]),
            makeProgram(title: "Mobility Reset", tags: [.mobility]),
            makeProgram(title: "Gym Builder", tags: [.gym, .muscleGain])
        ]

        let tags = service.availableTags(in: programs)

        #expect(tags == [
            .all,
            .tag(.streetWorkout),
            .tag(.gym),
            .tag(.strength),
            .tag(.muscleGain),
            .tag(.mobility)
        ])
    }

    @Test
    func selectedTagReturnsOnlyMatchingPrograms() {
        let programs = [
            makeProgram(title: "Outdoor Session", tags: [.streetWorkout, .bodyweight]),
            makeProgram(title: "Leg Day", tags: [.gym, .strength]),
            makeProgram(title: "Home Burn", tags: [.home, .hiit])
        ]

        let filtered = service.programs(in: programs, matching: .tag(.streetWorkout))

        #expect(filtered.map(\.title) == ["Outdoor Session"])
    }

    @Test
    func searchMatchesTitleDescriptionAndTags() {
        let programs = [
            makeProgram(
                title: "Strength Essentials",
                description: "Build a stable lifting base.",
                tags: [.strength]
            ),
            makeProgram(
                title: "Mobility Reset",
                description: "Restore posture and daily movement quality.",
                tags: [.mobility]
            ),
            makeProgram(
                title: "Home Burner",
                description: "Fast conditioning at home.",
                tags: [.home, .hiit]
            )
        ]

        #expect(service.searchResults(for: "strength essentials", in: programs).map(\.title) == ["Strength Essentials"])
        #expect(service.searchResults(for: "posture", in: programs).map(\.title) == ["Mobility Reset"])
        #expect(service.searchResults(for: "hiit", in: programs).map(\.title) == ["Home Burner"])
        #expect(service.searchResults(for: "   ", in: programs).isEmpty)
    }

    private func makeProgram(
        title: String,
        description: String = "Placeholder description",
        tags: [WorkoutProgramTag]
    ) -> ProgramSectionItem {
        ProgramSectionItem(
            id: UUID(),
            title: title,
            description: description,
            dayCount: 4,
            exerciseCount: 12,
            rateScore: 4.8,
            isSelected: false,
            isRecommended: false,
            isPopular: false,
            tags: tags
        )
    }
}
