import Foundation

/// User-facing authentication failures independent of the remote auth provider.
enum AuthenticationError: LocalizedError, Equatable, Sendable {
    case invalidCredentials
    case emailNotConfirmed
    case accountAlreadyExists
    case weakPassword
    case tooManyRequests
    case serviceUnavailable
    case unexpected(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "The email or password is incorrect."
        case .emailNotConfirmed:
            return "Confirm your email address before signing in."
        case .accountAlreadyExists:
            return "An account with this email already exists."
        case .weakPassword:
            return "Choose a stronger password."
        case .tooManyRequests:
            return "Too many attempts. Try again later."
        case .serviceUnavailable:
            return "Authentication is temporarily unavailable."
        case .unexpected(let message):
            return message
        }
    }
}
