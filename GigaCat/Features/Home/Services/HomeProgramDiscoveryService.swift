import Foundation

/// Encapsulates Home-specific discovery rules such as tag availability, filtering, and keyword search.
protocol HomeProgramDiscoveryServicing: Sendable {
    func availableTags(in programs: [ProgramSectionItem]) -> [ProgramFilterTag]
    func programs(in programs: [ProgramSectionItem], matching tag: ProgramFilterTag) -> [ProgramSectionItem]
    func searchResults(for query: String, in programs: [ProgramSectionItem]) -> [ProgramSectionItem]
}

/// Pure discovery service used by Home to keep filtering and search logic out of the view model.
struct HomeProgramDiscoveryService: HomeProgramDiscoveryServicing {
    private let preferredTagOrder: [WorkoutProgramTag] = [
        .streetWorkout,
        .gym,
        .home,
        .cardio,
        .strength,
        .muscleGain,
        .mobility,
        .hiit,
        .bodyweight
    ]

    func availableTags(in programs: [ProgramSectionItem]) -> [ProgramFilterTag] {
        let usedTags = Set(programs.flatMap(\.tags))
        let orderedTags = preferredTagOrder.filter { usedTags.contains($0) }
        return [.all] + orderedTags.map { .tag($0) }
    }

    func programs(in programs: [ProgramSectionItem], matching tag: ProgramFilterTag) -> [ProgramSectionItem] {
        guard case let .tag(selectedTag) = tag else { return [] }
        return programs.filter { $0.tags.contains(selectedTag) }
    }

    func searchResults(for query: String, in programs: [ProgramSectionItem]) -> [ProgramSectionItem] {
        let tokens = normalizedSearchTokens(from: query)
        guard !tokens.isEmpty else { return [] }

        return programs.filter { item in
            // Every token must match so short multi-word queries stay predictable.
            let searchableText = searchableText(for: item)
            return tokens.allSatisfy { searchableText.contains($0) }
        }
    }

    private func searchableText(for item: ProgramSectionItem) -> String {
        let tagsText = item.tags.map(\.title).joined(separator: " ")
        return "\(item.title) \(item.description) \(tagsText)".folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
    }

    private func normalizedSearchTokens(from query: String) -> [String] {
        query
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }
}
