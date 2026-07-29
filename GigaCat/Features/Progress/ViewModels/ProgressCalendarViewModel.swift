import Foundation
import Observation

@MainActor
@Observable
final class ProgressCalendarViewModel {
    // MARK: - Presentation State

    private(set) var selectedDate: Date?
    private(set) var displayedMonthStart: Date
    private(set) var monthViewData: ProgressMonthViewData
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
        let displayedMonth = dateService.month(
            containing: dateForDisplayedMonth
        )

        self.historyContext = historyContext
        self.dateService = dateService
        self.mapper = mapper
        self.now = now
        self.selectedDate = selectedDate
        displayedMonthStart = displayedMonth.startDate
        monthViewData = mapper.mapMonth(
            displayedMonth,
            history: historyContext,
            selectedDate: selectedDate,
            today: currentDate
        )
        selectedDaySessions = selectedDate.map {
            mapper.mapSessions(
                on: $0,
                history: historyContext
            )
        } ?? []
    }

    // MARK: - Month Navigation

    func showPreviousMonth() {
        moveDisplayedMonth(by: -1)
    }

    func showNextMonth() {
        guard canShowNextMonth else { return }
        moveDisplayedMonth(by: 1)
    }

    // MARK: - Date Selection

    func selectDate(_ date: Date) {
        let selectedMonthStart = dateService.month(
            containing: date
        ).startDate

        guard selectedMonthStart == displayedMonthStart else { return }

        selectedDate = date
        rebuildPresentation()
    }

    // MARK: - Presentation Mapping

    private var currentMonthStart: Date {
        dateService.month(containing: now()).startDate
    }

    private func moveDisplayedMonth(by value: Int) {
        let targetDate = dateService.addingMonths(
            value,
            to: displayedMonthStart
        )
        displayedMonthStart = dateService.month(
            containing: targetDate
        ).startDate
        selectedDate = nil
        rebuildPresentation()
    }

    private func rebuildPresentation() {
        let displayedMonth = dateService.month(
            containing: displayedMonthStart
        )
        monthViewData = mapper.mapMonth(
            displayedMonth,
            history: historyContext,
            selectedDate: selectedDate,
            today: now()
        )

        guard let selectedDate else {
            selectedDaySessions = []
            return
        }

        selectedDaySessions = mapper.mapSessions(
            on: selectedDate,
            history: historyContext
        )
    }
}
