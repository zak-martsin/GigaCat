import Foundation
import Observation

enum ProgressLoadState: Equatable {
    case loading
    case loaded
    case empty
    case failed
}

@MainActor
@Observable
final class ProgressViewModel {
    // MARK: - Presentation State

    private(set) var loadState: ProgressLoadState = .loading
    private(set) var weekViewData: ProgressWeekViewData?
    private(set) var displayedWeekStart: Date
    private(set) var historyContext: ProgressHistoryContext?

    // MARK: - Dependencies

    @ObservationIgnored
    private let historyService: ProgressHistoryServicing

    @ObservationIgnored
    private let dateService: ProgressDateServicing

    @ObservationIgnored
    private let mapper: ProgressViewDataMapping

    @ObservationIgnored
    private let now: @MainActor () -> Date

    @ObservationIgnored
    private var hasLoaded = false

    @ObservationIgnored
    private var isLoading = false

    // MARK: - Initialization

    init(
        historyService: ProgressHistoryServicing,
        dateService: ProgressDateServicing = ProgressDateService(),
        mapper: ProgressViewDataMapping = ProgressViewDataMapper(),
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        self.historyService = historyService
        self.dateService = dateService
        self.mapper = mapper
        self.now = now
        displayedWeekStart = dateService.week(containing: now()).startDate
    }

    // MARK: - Loading

    /// Loads Progress once until workout history is explicitly invalidated.
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    /// Reloads completed workout history and rebuilds the displayed week.
    func load() async {
        guard !isLoading else { return }

        isLoading = true
        loadState = .loading
        defer { isLoading = false }

        do {
            let history = try await historyService.loadHistory()
            historyContext = history
            hasLoaded = true
            rebuildWeekViewData()
            loadState = history.sessions.isEmpty ? .empty : .loaded
        } catch {
            historyContext = nil
            weekViewData = nil
            hasLoaded = false
            loadState = .failed
        }
    }

    /// Marks cached history as stale while preserving the current presentation until re-entry.
    func invalidate() {
        hasLoaded = false
    }

    // MARK: - Week Navigation

    func showPreviousWeek() {
        guard historyContext != nil else { return }

        displayedWeekStart = dateService.addingWeeks(
            -1,
            to: displayedWeekStart
        )
        rebuildWeekViewData()
    }

    func showNextWeek() {
        guard historyContext != nil,
              weekViewData?.canShowNextWeek == true else {
            return
        }

        displayedWeekStart = dateService.addingWeeks(
            1,
            to: displayedWeekStart
        )
        rebuildWeekViewData()
    }

    // MARK: - Presentation Mapping

    private func rebuildWeekViewData() {
        guard let historyContext else { return }

        let currentDate = now()
        let displayedWeek = dateService.week(containing: displayedWeekStart)
        let currentWeek = dateService.week(containing: currentDate)
        displayedWeekStart = displayedWeek.startDate
        weekViewData = mapper.mapWeek(
            displayedWeek,
            history: historyContext,
            today: currentDate,
            canShowNextWeek: displayedWeek.startDate < currentWeek.startDate
        )
    }
}
