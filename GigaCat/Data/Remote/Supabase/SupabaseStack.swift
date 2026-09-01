import Supabase
import Foundation

enum SupabaseAuthRedirect {
    static let emailConfirmation = URL(
        string: "com.zakmartsin.gigacat://auth-callback"
    )
    static let passwordRecovery = URL(
        string: "com.zakmartsin.gigacat://password-recovery"
    )
}

/// Owns the single Supabase client shared by remote data sources and auth services.
final class SupabaseStack {
    let client: SupabaseClient

    init(configuration: SupabaseConfiguration) {
        client = SupabaseClient(
            supabaseURL: configuration.projectURL,
            supabaseKey: configuration.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    redirectToURL: SupabaseAuthRedirect.emailConfirmation,
                    flowType: .pkce
                )
            )
        )
    }
}
