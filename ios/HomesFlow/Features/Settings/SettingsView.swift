import SwiftUI

// @covers FR-NOTIF-01, FR-AUTH-01

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var supabase = SupabaseClientProvider.shared

    @State private var isSigningOut = false
    @State private var showSignOutConfirmation = false
    @State private var errorMessage: String?

    // FR-NOTIF-01: push notifications are out of MVP scope; the toggle ships
    // disabled so the setting is discoverable before the capability exists.
    private let notificationsEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                notificationsSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Sign out of HomesFlow?",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task { await signOut() }
                }
            } message: {
                Text("Homes stored on this device are removed when you sign out.")
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var accountSection: some View {
        Section {
            LabeledContent("Email", value: supabase.session?.user.email ?? "Unknown")

            Button(role: .destructive) {
                showSignOutConfirmation = true
            } label: {
                if isSigningOut {
                    HStack {
                        Text("Signing Out…")
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Text("Sign Out")
                }
            }
            .disabled(isSigningOut)
        } header: {
            Text("Account")
        }
    }

    private var notificationsSection: some View {
        Section {
            Toggle("Status change alerts", isOn: .constant(notificationsEnabled))
                .disabled(true)
        } header: {
            Text("Notifications")
        } footer: {
            Text("Coming soon — push notifications for changed statuses and new assignments.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build { return "\(version) (\(build))" }
        return version
    }

    private func signOut() async {
        isSigningOut = true
        defer { isSigningOut = false }
        do {
            try await SupabaseClientProvider.shared.signOut()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
