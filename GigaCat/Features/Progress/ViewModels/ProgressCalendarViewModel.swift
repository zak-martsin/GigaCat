import Foundation
import Observation

@MainActor
@Observable
final class ProgressCalendarViewModel {
    // MARK: - Presentation State

    private(set) var selectedDate: Date?
    private(set) var displayedMonthStart: Date
    private(set) var monthViewData: ProgressMonthViewData
    private(set) var monthPages: [ProgressMonthViewData]
    private(set) var selectedDaySessions: [ProgressSessionViewData]

    var canShowNextMonth: Bool {
        displayedMonthStart < currentMonthStart
    }

    // MARK: - Dependencies

    @ObservationIgnored
    private let historyContext: ProgressHistoryContext

    @ObservationIgnored
    private let dateService: ProgressDateServicing

    @ObservationIgnored
    private let mapper: ProgressViewDataMapping

    @ObservationIgnored
    private let now: @MainActor () -> Date

    // MARK: - Initialization

    init(
        historyContext: ProgressHistoryContext,
        selectedDate: Date? = nil,
        dateService: ProgressDateServicing = ProgressDateService(),
        mapper: ProgressViewDataMapping = ProgressViewDataMapper(),
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        let currentDate = now()
        let dateForDisplayedMonth = selectedDate ?? currentDate
        let requestedMonth = dateService.month(
            containing: dateForDisplayedMonth
        )
        let currentMonth = dateService.month(containing: currentDate)
        let displayedMonth = requestedMonth.startDate <= currentMonth.startDate
            ? requestedMonth
            : currentMonth
        let initialSelectedDate = requestedMonth.startDate == displayedMonth.startDate
            ? selectedDate
            : nil

        self.historyContext = historyContext
        self.dateService = dateService
        self.mapper = mapper
        self.now = now
        self.selectedDate = initialSelectedDate
        displayedMonthStart = displayedMonth.startDate
        monthViewData = mapper.mapMonth(
            displayedMonth,
            history: historyContext,
            selectedDate: initialSelectedDate,
            today: currentDate
        )
        monthPages = []
        selectedDaySessions = initialSelectedDate.map {
            mapper.mapSessions(
                on: $0,
                history: historyContext
            )
        } ?? []
        rebuildMonthPages()
    }

    // MARK: - Month Navigation

    func showPreviousMonth() {
        guard displayedMonthIndex != nil else { return }

        if displayedMonthIndex == monthPages.startIndex {
            prependPreviousMonth()
        }

        guard let currentIndex = displayedMonthIndex,
              currentIndex > monthPages.startIndex else {
            return
        }
        showMonth(startingAt: monthPages[currentIndex - 1].startDate)
    }

    func showNextMonth() {
        guard let currentIndex = displayedMonthIndex,
              currentIndex < monthPages.index(before: monthPages.endIndex) else {
            return
        }

        showMonth(startingAt: monthPages[currentIndex + 1].startDate)
    }

    func showMonth(startingAt date: Date) {
        guard let page = monthPages.first(where: {
            $0.startDate == date
        }) else {
            return
        }

        let wasFirstPage = page.startDate == monthPages.first?.startDate
        displayedMonthStart = page.startDate

        if let selectedDate,
           dateService.month(containing: selectedDate).startDate != page.startDate {
            self.selectedDate = nil
        }

        rebuildMonthPages()

        if wasFirstPage {
            prependPreviousMonth()
        }
    }

    // MARK: - Date Selection

    func selectDate(_ date: Date) {
        let selectedMonthStart = dateService.month(
            containing: date
        ).startDate

        guard selectedMonthStart == displayedMonthStart else { return }

        selectedDate = date
        rebuildMonthPages()
    }

    // MARK: - Presentation Mapping

    private var currentMonthStart: Date {
        dateService.month(containing: now()).startDate
    }

    private var displayedMonthIndex: Int? {
        monthPages.firstIndex {
            $0.startDate == displayedMonthStart
        }
    }

    private func rebuildMonthPages() {
        let currentDate = now()
        let currentMonth = dateService.month(containing: currentDate)
        let defaultFirstMonthStart = dateService.addingMonths(
            -1,
            to: displayedMonthStart
        )
        let firstMonthStart = monthPages.first?.startDate
            ?? defaultFirstMonthStart
        let pageStarts = makeMonthStarts(
            from: firstMonthStart,
            through: currentMonth.startDate
        )

        monthPages = pageStarts.map { startDate in
            mapMonth(startingAt: startDate, today: currentDate)
        }

        let selectedPage = monthPages.first {
            $0.startDate == displayedMonthStart
        } ?? monthPages.last

        displayedMonthStart = selectedPage?.startDate ?? currentMonth.startDate
        monthViewData = selectedPage
            ?? mapMonth(startingAt: currentMonth.startDate, today: currentDate)

        guard let selectedDate else {
            selectedDaySessions = []
            return
        }

        selectedDaySessions = mapper.mapSessions(
            on: selectedDate,
            history: historyContext
        )
    }

    private func prependPreviousMonth() {
        guard let firstPage = monthPages.first else { return }

        let previousStart = dateService.addingMonths(
            -1,
            to: firstPage.startDate
        )
        guard previousStart < firstPage.startDate else { return }

        let page = mapMonth(startingAt: previousStart, today: now())
        monthPages.insert(page, at: monthPages.startIndex)
    }

    private func mapMonth(
        startingAt date: Date,
        today: Date
    ) -> ProgressMonthViewData {
        mapper.mapMonth(
            dateService.month(containing: date),
            history: historyContext,
            selectedDate: selectedDate,
            today: today
        )
    }

    private func makeMonthStarts(
        from firstMonthStart: Date,
        through currentMonthStart: Date
    ) -> [Date] {
        var starts: [Date] = []
        var cursor = firstMonthStart

        while cursor <= currentMonthStart {
            starts.append(cursor)
            let next = dateService.addingMonths(1, to: cursor)
            guard next > cursor else { break }
            cursor = next
        }

        return starts
    }
}
