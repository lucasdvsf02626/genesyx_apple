import Foundation

/// Resolves the remote backend at startup. Returns `nil` for the local-only v1 (Supabase package
/// not linked). Once `supabase-swift` is added and credentials are set (see docs/SUPABASE.md),
/// this returns a configured `SupabaseBackend` and every repository transparently goes online-first.
enum AppBackend {
    static func make() -> GenesyxBackend? {
        #if canImport(Supabase)
        return SupabaseBackend()   // failable init returns nil unless RemoteConfig.isConfigured
        #else
        return nil
        #endif
    }
}
