import Foundation

/// Broadcasts committed remote profile changes; observers are scoped to the authenticated app shell.
@MainActor
final class ProfileChangeSource {
    private var observers: [UUID: AsyncStream<UUID>.Continuation] = [:]

    nonisolated init() {}

    func changes() -> AsyncStream<UUID> {
        let id = UUID()
        return AsyncStream { continuation in
            observers[id] = continuation
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in self.observers.removeValue(forKey: id) }
            }
        }
    }

    func publish(userID: UUID) {
        for observer in observers.values { observer.yield(userID) }
    }
}
