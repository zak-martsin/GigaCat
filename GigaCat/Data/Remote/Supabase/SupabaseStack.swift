import Supabase

/// Owns the single Supabase client shared by remote data sources and auth services.
final class SupabaseStack {
    let client: SupabaseClient

    init(configuration: SupabaseConfiguration) {
        client = SupabaseClient(
            supabaseURL: configuration.projectURL,
            supabaseKey: configuration.publishableKey
        )
    }
}
