import SwiftUI

// @covers FR-AUTH-01

struct AuthView: View {
    @ObservedObject private var auth = SupabaseClientProvider.shared
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Sign in") {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    SecureField("Password", text: $viewModel.password)
                    if let error = viewModel.errorMessage {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                    Button {
                        Task { await viewModel.signIn() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Sign In")
                        }
                    }
                    .disabled(viewModel.isLoading || !viewModel.canSubmit)
                }

                Section {
                    Button {
                        Task { await viewModel.signUp() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Create Account")
                        }
                    }
                    .disabled(viewModel.isLoading || !viewModel.canSubmit)
                } header: {
                    Text("New account")
                } footer: {
                    Text("Password must be at least 6 characters. Local test user: diane@test.com / homeflow123")
                }

                Section {
                    Button("Sign in with Apple") {
                        viewModel.errorMessage = "Apple Sign-In wiring in Phase 1 — use email for local dev."
                    }
                } footer: {
                    Text("Apple Sign-In + email/password per FR-AUTH-01")
                }
            }
            .navigationTitle("HomesFlow")
        }
        .onChange(of: auth.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                viewModel.errorMessage = nil
            }
        }
    }
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let auth = SupabaseClientProvider.shared

    var canSubmit: Bool {
        email.contains("@") && password.count >= 6
    }

    func signIn() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.signIn(email: email, password: password)
            errorMessage = nil
        } catch {
            errorMessage = friendlyAuthError(error)
        }
    }

    func signUp() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.signUp(email: email, password: password)
            errorMessage = nil
        } catch {
            errorMessage = friendlyAuthError(error)
        }
    }

    private func friendlyAuthError(_ error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("could not connect")
            || message.localizedCaseInsensitiveContains("network")
            || message.localizedCaseInsensitiveContains("offline") {
            let host = SupabaseConfig.url.host ?? "Supabase"
            return """
            Could not reach \(host). On a physical iPhone, use Release scheme with cloud URL in Secrets.Release.xcconfig, confirm the Supabase project is not paused, then Product → Clean Build Folder and run again.
            """
        }
        if message.localizedCaseInsensitiveContains("already registered")
            || message.localizedCaseInsensitiveContains("already exists") {
            return "That email is already registered. Sign in instead, or use a different email."
        }
        if message.localizedCaseInsensitiveContains("invalid login")
            || message.localizedCaseInsensitiveContains("invalid credentials") {
            return "Incorrect email or password. For local dev, try diane@test.com / homeflow123."
        }
        return message
    }
}
