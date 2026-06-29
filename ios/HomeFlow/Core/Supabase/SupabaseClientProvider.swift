import Foundation
import Supabase

// @covers FR-AUTH-01

@MainActor
final class SupabaseClientProvider: ObservableObject {
    static let shared = SupabaseClientProvider()

    let client: SupabaseClient

    @Published private(set) var session: Session?
    @Published private(set) var isAuthenticated = false

    private var authStateTask: Task<Void, Never>?

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
        authStateTask = Task { await listenForAuthChanges() }
    }

    deinit {
        authStateTask?.cancel()
    }

    func refreshSession() async {
        if let current = client.auth.currentSession, !current.isExpired {
            applySession(current)
            return
        }

        do {
            applySession(try await client.auth.session)
        } catch {
            applySession(nil)
        }
    }

    func signUp(email: String, password: String) async throws {
        let response = try await client.auth.signUp(email: email, password: password)
        if let session = response.session {
            applySession(session)
            return
        }

        // Local Supabase: if signup didn't return a session, sign in immediately.
        try await signIn(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        applySession(session)
    }

    func signOut() async throws {
        try await client.auth.signOut()
        applySession(nil)
    }

    private func listenForAuthChanges() async {
        await refreshSession()

        for await (_, session) in client.auth.authStateChanges {
            applySession(session)
        }
    }

    private func applySession(_ session: Session?) {
        self.session = session
        isAuthenticated = session != nil
    }
}
