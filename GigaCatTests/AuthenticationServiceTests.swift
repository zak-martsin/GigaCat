import Foundation
import Testing
@testable import GigaCat

struct AuthenticationServiceTests {

    @Test
    func signUpCreatesAuthenticatedSessionWhenConfirmationIsDisabled() async throws {
        let service: any AuthenticationService = MockAuthenticationService()

        let result = try await service.signUp(
            email: "  USER@example.com ",
            password: "password"
        )
        let account = try #require(authenticatedAccount(from: result))

        #expect(account.email == "user@example.com")
        #expect(try await service.currentAccount() == account)
    }

    @Test
    func signUpDoesNotCreateSessionWhenConfirmationIsRequired() async throws {
        let service: any AuthenticationService = MockAuthenticationService(
            requiresEmailConfirmation: true
        )

        let result = try await service.signUp(
            email: "user@example.com",
            password: "password"
        )

        #expect(result == .emailConfirmationRequired)
        #expect(try await service.currentAccount() == nil)
    }

    @Test
    func confirmedAccountCanSignInAndSignOut() async throws {
        let service: any AuthenticationService = MockAuthenticationService(
            requiresEmailConfirmation: true
        )
        _ = try await service.signUp(
            email: "user@example.com",
            password: "password"
        )

        let account = try await service.signIn(
            email: "user@example.com",
            password: "password"
        )
        #expect(try await service.currentAccount() == account)

        try await service.signOut()
        #expect(try await service.currentAccount() == nil)
    }
}

private func authenticatedAccount(
    from result: RegistrationResult
) -> AuthenticatedAccount? {
    guard case .authenticated(let account) = result else {
        return nil
    }
    return account
}
