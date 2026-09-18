import Foundation

/// Exposes the active application user without revealing how authentication is implemented.
protocol CurrentUserIDProviding: Sendable {
    func currentUserID() async -> UUID?
}

/// Lets the authentication boundary update the active application user.
protocol CurrentUserIDStoring: CurrentUserIDProviding {
    func setCurrentUserID(_ userID: UUID) async
    func clearCurrentUserID() async
}
