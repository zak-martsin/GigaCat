import Testing
@testable import GigaCat

struct DataLoadTrackerTests {

    @Test
    func invalidationDuringLoadKeepsOlderResultStale() {
        var tracker = DataLoadTracker()
        let loadingRevision = tracker.currentRevision

        tracker.invalidate()
        tracker.markLoaded(revision: loadingRevision)

        #expect(tracker.needsLoading)
    }

    @Test
    func resultForCurrentRevisionMakesCacheFresh() {
        var tracker = DataLoadTracker()
        tracker.invalidate()

        tracker.markLoaded(revision: tracker.currentRevision)

        #expect(!tracker.needsLoading)
    }
}
