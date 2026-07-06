import SwiftUI

// @covers AC-USER-02, AC-USER-07, FR-GUEST-02

/// Shared invite detail for iPad trailing column and iPhone sheet — keep in sync.
struct PendingInviteDetailView: View {
    let invite: InviteSummary
    let canRevoke: Bool
    let onRevoke: () -> Void

    var body: some View {
        List {
            Section {
                LabeledContent("Email", value: invite.email)
                LabeledContent("Role", value: invite.role.displayName)
                LabeledContent("Status", value: "Pending")
            }

            Section("Invite link") {
                ShareLink(item: InvitePolicy.inviteLink(token: invite.token)) {
                    Label("Share invite link", systemImage: "square.and.arrow.up")
                }
                Text("The invitee must sign in with \(invite.email) to accept.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if canRevoke {
                Section {
                    Button("Revoke invite", role: .destructive, action: onRevoke)
                        .accessibilityLabel("Revoke invite for \(invite.email)")
                } footer: {
                    Text("Revoking invalidates this link immediately.")
                }
            }
        }
        .navigationTitle("Pending invite")
        .navigationBarTitleDisplayMode(.inline)
    }
}
