import AuthenticationServices
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
                    SignInWithAppleButton(.signIn) { request in
                        viewModel.configureAppleSignInRequest(request)
                    } onCompletion: { result in
                        Task { await viewModel.handleAppleSignIn(result) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 44)
                    .disabled(viewModel.isLoading)
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
    private var appleSignInNonce: String?

    var canSubmit: Bool {
        email.contains("@") && password.count >= 6
    }

    func configureAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        appleSignInNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleSignInPolicy.hashedNonce(for: nonce)
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            await completeAppleSignIn(authorization)
        case .failure(let error):
            guard !isUserCanceled(error) else { return }
            errorMessage = friendlyAppleSignInError(error)
        }
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

    private func completeAppleSignIn(_ authorization: ASAuthorization) async {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Apple Sign-In did not return a valid credential."
            return
        }
        guard let rawNonce = appleSignInNonce else {
            errorMessage = "Apple Sign-In session expired. Try again."
            return
        }

        isLoading = true
        defer {
            isLoading = false
            appleSignInNonce = nil
        }

        do {
            let idToken = try AppleSignInPolicy.identityTokenString(from: credential.identityToken)
            try await auth.signInWithApple(idToken: idToken, nonce: rawNonce)
            errorMessage = nil
        } catch {
            errorMessage = friendlyAppleSignInError(error)
        }
    }

    private func isAlreadyRegistered(_ error: Error) -> Bool {
        let message = error.localizedDescription
        return message.localizedCaseInsensitiveContains("already registered")
            || message.localizedCaseInsensitiveContains("already exists")
    }

    private func isUserCanceled(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == ASAuthorizationError.errorDomain
            && nsError.code == ASAuthorizationError.canceled.rawValue
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

    private func friendlyAppleSignInError(_ error: Error) -> String {
        if let policyError = error as? AppleSignInPolicy.Error, policyError == .missingIdentityToken {
            return "Apple Sign-In did not return an identity token. Try again or use email and password."
        }

        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("provider")
            || message.localizedCaseInsensitiveContains("apple")
            || message.localizedCaseInsensitiveContains("id_token")
            || message.localizedCaseInsensitiveContains("unsupported") {
            return """
            Apple Sign-In is not enabled for this Supabase project. Enable the Apple provider in Supabase Dashboard → Authentication → Providers, then try again. Local Docker dev uses email/password only.
            """
        }
        return friendlyAuthError(error)
    }

    /// Random nonce for Sign in with Apple → Supabase OIDC verification.
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)

        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
            }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }
}
