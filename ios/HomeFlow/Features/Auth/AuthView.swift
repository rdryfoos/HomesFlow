import SwiftUI

// @covers FR-AUTH-01

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    var onAuthenticated: () -> Void

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
                    Button("Sign In") {
                        Task {
                            await viewModel.signIn()
                            if viewModel.isAuthenticated { onAuthenticated() }
                        }
                    }
                    .disabled(viewModel.isLoading || !viewModel.canSubmit)
                }

                Section {
                    Button("Create Account") {
                        Task {
                            await viewModel.signUp()
                            if viewModel.isAuthenticated { onAuthenticated() }
                        }
                    }
                    .disabled(viewModel.isLoading || !viewModel.canSubmit)
                } header: {
                    Text("New account")
                } footer: {
                    Text("Password must be at least 6 characters.")
                }

                Section {
                    Button("Sign in with Apple") {
                        viewModel.errorMessage = "Apple Sign-In wiring in Phase 1 — use email for local dev."
                    }
                } footer: {
                    Text("Apple Sign-In + email/password per FR-AUTH-01")
                }
            }
            .navigationTitle("HomeFlow")
        }
    }
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isAuthenticated = false

    private let auth = SupabaseClientProvider.shared

    var canSubmit: Bool {
        email.contains("@") && password.count >= 6
    }

    func signIn() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.signIn(email: email, password: password)
            isAuthenticated = auth.isAuthenticated
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.signUp(email: email, password: password)
            isAuthenticated = auth.isAuthenticated
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
