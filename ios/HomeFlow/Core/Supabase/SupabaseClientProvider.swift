import Foundation
import Supabase

// @covers FR-AUTH-01

@MainActor
final class SupabaseClientProvider: ObservableObject {
    static let shared = SupabaseClientProvider()

    let client: SupabaseClient

    @Published private(set) var session: Session?
    @Published private(set) var isAuthenticated = false

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
        Task { await refreshSession() }
    }

    func refreshSession() async {
        session = try? await client.auth.session
        isAuthenticated = session != nil
    }

    func signUp(email: String, password: String) async throws {
        _ = try await client.auth.signUp(email: email, password: password)
        await refreshSession()
        // Local Supabase: if signup didn't return a session, sign in immediately.
        if session == nil {
            try await client.auth.signIn(email: email, password: password)
            await refreshSession()
        }
    }

    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
        await refreshSession()
    }

    func signOut() async throws {
        try await client.auth.signOut()
        await refreshSession()
    }
}
