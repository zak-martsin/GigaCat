import Foundation
import Supabase

/// Converts SDK-specific transport and Data API failures into worker decisions.
enum SupabaseSyncErrorClassifier {
    static func classify(_ error: any Error) -> SyncExecutionError {
        if let urlError = error as? URLError,
           transientURLCodes.contains(urlError.code) {
            return .transient(message: urlError.localizedDescription)
        }

        if let httpError = error as? HTTPError {
            return classifyHTTPStatus(
                httpError.response.statusCode,
                message: httpError.localizedDescription
            )
        }

        if let postgrestError = error as? PostgrestError {
            return classifyPostgrestError(postgrestError)
        }

        if let authError = error as? AuthError {
            return classifyAuthError(authError)
        }

        return .permanent(message: error.localizedDescription)
    }

    private static func classifyHTTPStatus(
        _ status: Int,
        message: String
    ) -> SyncExecutionError {
        switch status {
        case 401:
            .authenticationRequired(message: message)
        case 408, 429, 500...599:
            .transient(message: message)
        default:
            .permanent(message: message)
        }
    }

    private static func classifyPostgrestError(
        _ error: PostgrestError
    ) -> SyncExecutionError {
        let code = error.code ?? ""

        if ["PGRST301", "PGRST302", "PGRST303"].contains(code) {
            return .authenticationRequired(message: error.message)
        }

        if code.hasPrefix("PT"),
           let status = Int(code.dropFirst(2)) {
            return classifyHTTPStatus(status, message: error.message)
        }

        if code == "42501", error.message.localizedCaseInsensitiveContains("jwt") {
            return .authenticationRequired(message: error.message)
        }

        if ["PGRST000", "PGRST001", "PGRST002", "PGRST003", "PGRST300", "PGRSTX00"]
            .contains(code) {
            return .transient(message: error.message)
        }

        if transientPostgresPrefixes.contains(where: code.hasPrefix) {
            return .transient(message: error.message)
        }

        return .permanent(message: error.message)
    }

    private static func classifyAuthError(_ error: AuthError) -> SyncExecutionError {
        switch error {
        case .sessionMissing, .jwtVerificationFailed:
            .authenticationRequired(message: error.localizedDescription)
        case .api(let message, _, _, let response):
            classifyHTTPStatus(response.statusCode, message: message)
        default:
            .permanent(message: error.localizedDescription)
        }
    }

    private static let transientURLCodes: Set<URLError.Code> = [
        .timedOut,
        .cannotFindHost,
        .cannotConnectToHost,
        .networkConnectionLost,
        .dnsLookupFailed,
        .notConnectedToInternet,
        .internationalRoamingOff,
        .callIsActive,
        .dataNotAllowed
    ]

    // Supabase maps these SQLSTATE classes to HTTP 5xx responses.
    private static let transientPostgresPrefixes = [
        "08", "09", "25", "2D", "38", "39", "3B", "40", "53", "54",
        "55", "57", "58", "F0", "HV", "P0", "XX"
    ]
}
