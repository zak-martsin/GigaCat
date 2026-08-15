import Foundation

/// Identity and contact information for the account owning the active auth session.
struct AuthenticatedAccount: Equatable, Sendable {
    let id: UUID
    let email: String?
}
