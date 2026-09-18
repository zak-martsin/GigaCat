import Foundation
import Supabase
import Testing
@testable import GigaCat

struct SupabaseSyncErrorClassifierTests {
    @Test
    func networkAndRateLimitErrorsAreTransient() throws {
        let networkResult = SupabaseSyncErrorClassifier.classify(
            URLError(.notConnectedToInternet)
        )
        let url = try #require(URL(string: "https://example.com"))
        let response = try #require(
            HTTPURLResponse(
                url: url,
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            )
        )
        let rateLimitResult = SupabaseSyncErrorClassifier.classify(
            HTTPError(data: Data(), response: response)
        )

        guard case .transient = networkResult else {
            Issue.record("Expected the network error to be transient")
            return
        }
        guard case .transient = rateLimitResult else {
            Issue.record("Expected HTTP 429 to be transient")
            return
        }
    }

    @Test
    func invalidJWTRequiresAuthentication() {
        let result = SupabaseSyncErrorClassifier.classify(
            PostgrestError(code: "PGRST301", message: "Invalid JWT")
        )

        guard case .authenticationRequired = result else {
            Issue.record("Expected an authentication failure")
            return
        }
    }

    @Test
    func constraintViolationIsPermanent() {
        let result = SupabaseSyncErrorClassifier.classify(
            PostgrestError(
                code: "23514",
                message: "Selected program must be active"
            )
        )

        guard case .permanent = result else {
            Issue.record("Expected a permanent failure")
            return
        }
    }

    @Test
    func customRateLimitCodeIsTransient() {
        let result = SupabaseSyncErrorClassifier.classify(
            PostgrestError(code: "PT429", message: "Too many requests")
        )

        guard case .transient = result else {
            Issue.record("Expected custom HTTP 429 to be transient")
            return
        }
    }
}
