/// Outcome of creating an account when email confirmation may prevent an immediate session.
enum RegistrationResult: Equatable, Sendable {
    case authenticated(AuthenticatedAccount)
    case emailConfirmationRequired
}
