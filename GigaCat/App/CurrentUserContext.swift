import Foundation

/// Holds only the user identity shared between authentication and local repositories.
actor CurrentUserContext: CurrentUserIDStoring {
    private var userID: UUID?

    init(userID: UUID? = nil) {
        self.userID = userID
    }

    func currentUserID() -> UUID? {
        userID
    }

    func setCurrentUserID(_ userID: UUID) {
        self.userID = userID
    }

    func clearCurrentUserID() {
        userID = nil
    }
}
