import Foundation

/// Calendar dates needed to render one complete week.
struct ProgressWeek: Equatable, Sendable {
    let startDate: Date
    let days: [Date]
}

/// Calendar dates and leading placeholders needed to render one month grid.
struct ProgressMonth: Equatable, Sendable {
    let startDate: Date
    let days: [Date]
    let leadingEmptyDayCount: Int
}
