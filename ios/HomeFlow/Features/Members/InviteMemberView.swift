import SwiftUI

// @covers AC-USER-01, FR-GUEST-02

struct InviteMemberView: View {
    let home: HomeSummary
    var onInvited: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var appEnvironment

    @State private var email = ""
    @State private var role: HomeRole = .manager
    @State private var errorMessage: String?
    @State private var createdInvite: InviteSummary?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Invitee") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    Picker("Role", selection: $role) {
                        Text(HomeRole.manager.displayName).tag(HomeRole.manager)
                        Text(HomeRole.guest.displayName).tag(HomeRole.guest)
                    }
                }

                if let createdInvite {
                    Section("Invite link") {
                        ShareLink(item: inviteLink(for: createdInvite.token)) {
                            Label("Share invite link", systemImage: "square.and.arrow.up")
                        }
                        Text("The invitee must sign in with \(createdInvite.email) to accept.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Invite Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task { await sendInvite() }
                    }
                    .disabled(isSaving || email.isEmpty || createdInvite != nil)
                }
            }
        }
    }

    private func sendInvite() async {
        guard let repo = appEnvironment?.memberRepository else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            createdInvite = try await repo.createInvite(homeId: home.id, email: email, role: role)
            onInvited()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func inviteLink(for token: String) -> URL {
        URL(string: "homeflow://invite?token=\(token)")!
    }
}

struct AcceptInviteView: View {
    @Environment(\.appEnvironment) private var appEnvironment

    @State private var token = ""
    @State private var message: String?
    @State private var isError = false
    @State private var isWorking = false
    var onAccepted: () -> Void

    var body: some View {
        Section {
            TextField("Invite code", text: $token)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Accept Invite") {
                Task { await accept() }
            }
            .disabled(isWorking || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(isError ? .red : .green)
            }
        } header: {
            Text("Have an invite?")
        } footer: {
            Text("Paste the code from your invite link (homeflow://invite?token=…). You must be signed in with the invited email.")
        }
    }

    private func accept() async {
        guard let repo = appEnvironment?.memberRepository else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await repo.acceptInvite(token: token.trimmingCharacters(in: .whitespacesAndNewlines))
            message = "Invite accepted — refresh your home list."
            isError = false
            onAccepted()
        } catch {
            message = error.localizedDescription
            isError = true
        }
    }
}
