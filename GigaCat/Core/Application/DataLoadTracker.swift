/// Tracks whether cached feature data matches the latest invalidation revision.
struct DataLoadTracker {
    private(set) var currentRevision = 0
    private var loadedRevision: Int?

    var needsLoading: Bool {
        loadedRevision != currentRevision
    }

    mutating func invalidate() {
        currentRevision &+= 1
    }

    /// Records the revision captured before loading, preserving newer invalidations.
    mutating func markLoaded(revision: Int) {
        loadedRevision = revision
    }
}
