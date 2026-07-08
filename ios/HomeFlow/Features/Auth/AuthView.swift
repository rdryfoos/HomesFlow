import SwiftUI

// @covers FR-AUTH-01

struct AuthView: View {
    @ObservedObject private var auth = SupabaseClientProvider.shared
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    SecureField("Password", text: $viewModel.password)
                    if let error = viewModel.errorMessage {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }

                Section {
                    Button {
                        Task { await viewModel.continueWithEmail() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Continue")
                        }
                    }
                    .disabled(viewModel.isLoading || !viewModel.canSubmit)
                }

                Section {
                    Button("Sign in with Apple") {
                        viewModel.errorMessage = "Apple Sign-In is not available yet — use email and password."
                    }
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

    func continueWithEmail() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.signUp(email: email, password: password)
            errorMessage = nil
        } catch let signUpError {
            guard isAlreadyRegistered(signUpError) else {
                errorMessage = friendlyAuthError(signUpError)
                return
            }
            do {
                try await auth.signIn(email: email, password: password)
                errorMessage = nil
            } catch {
                errorMessage = friendlyAuthError(error)
            }
        }
    }

    private func isAlreadyRegistered(_ error: Error) -> Bool {
        let message = error.localizedDescription
        return message.localizedCaseInsensitiveContains("already registered")
            || message.localizedCaseInsensitiveContains("already exists")
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
            return "That email is already registered. Check your password and try again."
        }
        if message.localizedCaseInsensitiveContains("invalid login")
            || message.localizedCaseInsensitiveContains("invalid credentials") {
            return "Incorrect email or password. For local dev, try diane@test.com / homeflow123."
        }
        return message
    }
}
