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
    private(set) var weekPages: [ProgressWeekViewData] = []
    private(set) var displayedWeekStart: Date
    private(set) var selectedDate: Date?
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
    private var loadTracker = DataLoadTracker()

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
        guard loadTracker.needsLoading else { return }
        await load()
    }

    /// Reloads completed workout history and rebuilds the displayed week.
    func load() async {
        guard !isLoading else { return }

        let loadingRevision = loadTracker.currentRevision
        isLoading = true
        loadState = .loading
        defer { isLoading = false }

        do {
            let history = try await historyService.loadHistory()
            historyContext = history
            loadTracker.markLoaded(revision: loadingRevision)
            rebuildWeekPages()
            loadState = history.sessions.isEmpty ? .empty : .loaded
        } catch {
            historyContext = nil
            weekViewData = nil
            weekPages = []
            loadState = .failed
        }
    }

    /// Marks cached history as stale while preserving the current presentation until re-entry.
    func invalidate() {
        loadTracker.invalidate()
    }

    // MARK: - Week Navigation

    func showPreviousWeek() {
        guard displayedWeekIndex != nil else { return }

        if displayedWeekIndex == weekPages.startIndex {
            prependPreviousWeek()
        }

        guard let currentIndex = displayedWeekIndex,
              currentIndex > weekPages.startIndex else {
            return
        }
        showWeek(startingAt: weekPages[currentIndex - 1].startDate)
    }

    func showNextWeek() {
        guard let currentIndex = displayedWeekIndex,
              currentIndex < weekPages.index(before: weekPages.endIndex) else {
            return
        }

        showWeek(startingAt: weekPages[currentIndex + 1].startDate)
    }

    func showWeek(startingAt date: Date) {
        guard let page = weekPages.first(where: {
            $0.startDate == date
        }) else {
            return
        }

        displayedWeekStart = page.startDate
        weekViewData = page

        if page.startDate == weekPages.first?.startDate {
            prependPreviousWeek()
        }
    }

    func selectDate(_ date: Date) {
        guard weekPages.contains(where: {
            $0.days.contains(where: { $0.date == date })
        }) else {
            return
        }

        selectedDate = date
    }

    // MARK: - Calendar Presentation

    func makeCalendarViewModel(
        selectedDate: Date? = nil
    ) -> ProgressCalendarViewModel? {
        guard let historyContext else { return nil }

        return ProgressCalendarViewModel(
            historyContext: historyContext,
            selectedDate: selectedDate,
            dateService: dateService,
            mapper: mapper,
            now: now
        )
    }

    // MARK: - Presentation Mapping

    private var displayedWeekIndex: Int? {
        weekPages.firstIndex {
            $0.startDate == displayedWeekStart
        }
    }

    private func rebuildWeekPages() {
        guard let historyContext else { return }

        let currentDate = now()
        let currentWeek = dateService.week(containing: currentDate)
        let defaultFirstWeekStart = dateService.addingWeeks(
            -1,
            to: currentWeek.startDate
        )
        let firstWeekStart = weekPages.first?.startDate
            ?? defaultFirstWeekStart
        let pageStarts = makeWeekStarts(
            from: firstWeekStart,
            through: currentWeek.startDate
        )

        weekPages = pageStarts.map { startDate in
            let week = dateService.week(containing: startDate)
            return mapper.mapWeek(
                week,
                history: historyContext,
                today: currentDate,
                canShowNextWeek: startDate < currentWeek.startDate
            )
        }

        let selectedPage = weekPages.first {
            $0.startDate == displayedWeekStart
        } ?? weekPages.last

        displayedWeekStart = selectedPage?.startDate ?? currentWeek.startDate
        weekViewData = selectedPage
    }

    private func prependPreviousWeek() {
        guard let historyContext,
              let firstPage = weekPages.first else {
            return
        }

        let previousStart = dateService.addingWeeks(
            -1,
            to: firstPage.startDate
        )
        guard previousStart < firstPage.startDate else { return }

        let currentDate = now()
        let previousWeek = dateService.week(containing: previousStart)
        let page = mapper.mapWeek(
            previousWeek,
            history: historyContext,
            today: currentDate,
            canShowNextWeek: true
        )
        weekPages.insert(page, at: weekPages.startIndex)
    }

    private func makeWeekStarts(
        from firstWeekStart: Date,
        through currentWeekStart: Date
    ) -> [Date] {
        var starts: [Date] = []
        var cursor = firstWeekStart

        while cursor <= currentWeekStart {
            starts.append(cursor)
            let next = dateService.addingWeeks(1, to: cursor)
            guard next > cursor else { break }
            cursor = next
        }

        return starts
    }
}
