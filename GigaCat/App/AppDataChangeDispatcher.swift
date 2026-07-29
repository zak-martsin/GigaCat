import Foundation

/// Connects feature mutation callbacks to the app-level coordinator after the object graph is built.
@MainActor
final class AppDataChangeDispatcher {
    private var handler: AppDataChangeHandler?

    func install(handler: @escaping AppDataChangeHandler) {
        self.handler = handler
    }

    func send(_ change: AppDataChange) async {
        await handler?(change)
    }
}
