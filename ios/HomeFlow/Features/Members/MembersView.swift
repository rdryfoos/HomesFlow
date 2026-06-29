import SwiftUI

// @covers FR-USER-02, AC-USER-01, AC-USER-02, AC-USER-04…06

struct MembersView: View {
    let home: HomeSummary
    @Environment(\.appEnvironment) private var appEnvironment

    @StateObject private var viewModel = MembersViewModel()
    @State private var showInviteSheet = false

    var body: some View {
        List {
            Section("Members") {
                ForEach(viewModel.snapshot.members) { member in
                    MemberRow(
                        member: member,
                        canManage: viewModel.snapshot.currentUserRole == .admin,
                        onRoleChange: { role in
                            Task { await viewModel.updateRole(homeId: home.id, membershipId: member.id, role: role, using: appEnvironment?.memberRepository) }
                        }
                    )
                }
            }

            if !viewModel.snapshot.pendingInvites.isEmpty {
                Section("Pending invites") {
                    ForEach(viewModel.snapshot.pendingInvites) { invite in
                        InviteRow(
                            invite: invite,
                            canRevoke: viewModel.snapshot.currentUserRole == .admin,
                            onRevoke: {
                                Task { await viewModel.revoke(homeId: home.id, inviteId: invite.id, using: appEnvironment?.memberRepository) }
                            }
                        )
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.snapshot.members.isEmpty {
                ProgressView("Loading members…")
            }
        }
        .refreshable {
            await reload()
        }
        .toolbar {
            if viewModel.snapshot.currentUserRole == .admin {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showInviteSheet = true
                    } label: {
                        Label("Invite", systemImage: "person.badge.plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteMemberView(home: home) {
                Task { await reload() }
            }
            .environment(\.appEnvironment, appEnvironment)
        }
        .task { await reload() }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func reload() async {
        guard let repo = appEnvironment?.memberRepository else { return }
        await viewModel.load(homeId: home.id, using: repo)
    }
}

private struct MemberRow: View {
    let member: MemberSummary
    let canManage: Bool
    let onRoleChange: (HomeRole) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName).font(.headline)
                Text(member.email).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if canManage && member.role != .admin {
                Picker("Role", selection: Binding(
                    get: { member.role },
                    set: { onRoleChange($0) }
                )) {
                    Text("Edit").tag(HomeRole.edit)
                    Text("Guest").tag(HomeRole.guest)
                }
                .pickerStyle(.menu)
            } else {
                Text(member.role.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct InviteRow: View {
    let invite: InviteSummary
    let canRevoke: Bool
    let onRevoke: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(invite.email).font(.headline)
                    Text("\(invite.role.rawValue.capitalized) · Pending")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if canRevoke {
                    Button("Revoke", role: .destructive, action: onRevoke)
                        .font(.caption)
                }
            }
            ShareLink(item: inviteLink(for: invite.token)) {
                Label("Copy invite link", systemImage: "link")
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    private func inviteLink(for token: String) -> URL {
        URL(string: "homeflow://invite?token=\(token)")!
    }
}

@MainActor
final class MembersViewModel: ObservableObject {
    @Published var snapshot = HomeMembersSnapshot(members: [], pendingInvites: [], currentUserRole: nil)
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(homeId: UUID, using repository: MemberRepository) async {
        isLoading = true
        defer { isLoading = false }
        do {
            snapshot = try await repository.fetchHomeMembers(homeId: homeId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateRole(homeId: UUID, membershipId: UUID, role: HomeRole, using repository: MemberRepository?) async {
        guard let repository else { return }
        do {
            try await repository.updateMemberRole(homeId: homeId, membershipId: membershipId, role: role)
            snapshot = try await repository.fetchHomeMembers(homeId: homeId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revoke(homeId: UUID, inviteId: UUID, using repository: MemberRepository?) async {
        guard let repository else { return }
        do {
            try await repository.revokeInvite(homeId: homeId, inviteId: inviteId)
            snapshot = try await repository.fetchHomeMembers(homeId: homeId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
