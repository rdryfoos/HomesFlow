import SwiftUI

// @covers FR-USER-02, AC-USER-01, AC-USER-02, AC-USER-04…06, FR-NAV-01, AC-HOME-12, AC-SYNC-07

struct MembersView: View {
    let home: HomeSummary
    @Environment(\.appEnvironment) private var appEnvironment
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var network: NetworkMonitor

    @StateObject private var viewModel = MembersViewModel()
    @State private var showInviteSheet = false
    @State private var selectedMemberId: UUID?
    @State private var memberPendingRemoval: MemberSummary?

    private var canManageMembersOnline: Bool {
        viewModel.snapshot.currentUserRole == .owner
            && StructuralActionPolicy.canPerformStructuralActions(isConnected: network.isConnected)
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    membersList(useSelection: true)
                } detail: {
                    memberDetailPanel
                }
            } else {
                membersList(useSelection: false)
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
            // AC-HOME-12: parallel add construction across sections.
            if viewModel.snapshot.currentUserRole == .owner {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showInviteSheet = true
                    } label: {
                        Label(SectionAddAction.people.label, systemImage: SectionAddAction.people.systemImage)
                    }
                    .disabled(!network.isConnected)
                    .accessibilityLabel(SectionAddAction.people.accessibilityLabel)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.snapshot.currentUserRole == .owner && !network.isConnected {
                Text(StructuralActionPolicy.offlineMessage(for: .members))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteMemberView(home: home) {
                Task { await reload() }
            }
            .environment(\.appEnvironment, appEnvironment)
        }
        .task { await reload() }
        .onChange(of: viewModel.snapshot.members.map(\.id)) { _, ids in
            guard sizeClass == .regular else { return }
            if let selectedMemberId, ids.contains(selectedMemberId) { return }
            selectedMemberId = ids.first
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        // FR-USER-02: owner removes member; access lost on next sync.
        .confirmationDialog(
            "Remove \(memberPendingRemoval?.displayName ?? "member")?",
            isPresented: Binding(
                get: { memberPendingRemoval != nil },
                set: { if !$0 { memberPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove from home", role: .destructive) {
                guard let member = memberPendingRemoval else { return }
                memberPendingRemoval = nil
                Task {
                    await viewModel.remove(
                        homeId: home.id,
                        membershipId: member.id,
                        using: appEnvironment?.memberRepository
                    )
                }
            }
        } message: {
            Text("They will lose access to this home on their next sync.")
        }
    }

    @ViewBuilder
    private var memberDetailPanel: some View {
        if let member = selectedMember {
            MemberDetailPanel(
                member: member,
                canManage: canManageMembersOnline,
                canRemove: canManageMembersOnline && MemberRemovalPolicy.canRemove(
                    currentUserRole: viewModel.snapshot.currentUserRole,
                    memberRole: member.role
                ),
                onRoleChange: { role in
                    Task {
                        await viewModel.updateRole(
                            homeId: home.id,
                            membershipId: member.id,
                            role: role,
                            using: appEnvironment?.memberRepository
                        )
                    }
                },
                onRemove: { memberPendingRemoval = member }
            )
        } else if viewModel.isLoading {
            ProgressView("Loading members…")
        } else {
            ContentUnavailableView(
                "Select a member",
                systemImage: "person.2",
                description: Text("Choose someone from the list to view their details.")
            )
        }
    }

    private var selectedMember: MemberSummary? {
        if let selectedMemberId,
           let member = viewModel.snapshot.members.first(where: { $0.id == selectedMemberId }) {
            return member
        }
        return viewModel.snapshot.members.first
    }

    @ViewBuilder
    private func membersList(useSelection: Bool) -> some View {
        if useSelection && !viewModel.snapshot.members.isEmpty {
            List(selection: $selectedMemberId) {
                membersSections(showRolePicker: false)
            }
        } else {
            List {
                membersSections(showRolePicker: canManageMembersOnline)
            }
        }
    }

    @ViewBuilder
    private func membersSections(showRolePicker: Bool) -> some View {
        Section("Members") {
            if viewModel.snapshot.members.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No members yet",
                    systemImage: "person.2",
                    description: Text("People with access to this home will appear here.")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.snapshot.members) { member in
                    MemberRow(
                        member: member,
                        canManage: showRolePicker,
                        onRoleChange: { role in
                            Task {
                                await viewModel.updateRole(
                                    homeId: home.id,
                                    membershipId: member.id,
                                    role: role,
                                    using: appEnvironment?.memberRepository
                                )
                            }
                        }
                    )
                    .tag(member.id)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if canManageMembersOnline && MemberRemovalPolicy.canRemove(
                            currentUserRole: viewModel.snapshot.currentUserRole,
                            memberRole: member.role
                        ) {
                            Button("Remove", role: .destructive) {
                                memberPendingRemoval = member
                            }
                            .accessibilityLabel("Remove \(member.displayName)")
                        }
                    }
                }
            }
        }

        if !viewModel.snapshot.pendingInvites.isEmpty {
            Section("Pending invites") {
                ForEach(viewModel.snapshot.pendingInvites) { invite in
                    InviteRow(
                        invite: invite,
                        canRevoke: canManageMembersOnline,
                        onRevoke: {
                            Task {
                                await viewModel.revoke(
                                    homeId: home.id,
                                    inviteId: invite.id,
                                    using: appEnvironment?.memberRepository
                                )
                            }
                        }
                    )
                }
            }
        }
    }

    private func reload() async {
        guard let repo = appEnvironment?.memberRepository else { return }
        await viewModel.load(homeId: home.id, using: repo)
    }
}

private struct MemberDetailPanel: View {
    let member: MemberSummary
    let canManage: Bool
    let canRemove: Bool
    let onRoleChange: (HomeRole) -> Void
    let onRemove: () -> Void

    var body: some View {
        List {
            Section {
                LabeledContent("Name", value: member.displayName)
                LabeledContent("Email", value: member.email)
                if canManage && member.role != .owner {
                    Picker("Role", selection: Binding(
                        get: { member.role },
                        set: { onRoleChange($0) }
                    )) {
                        Text(HomeRole.manager.displayName).tag(HomeRole.manager)
                        Text(HomeRole.guest.displayName).tag(HomeRole.guest)
                    }
                } else {
                    LabeledContent("Role", value: member.role.displayName)
                }
            }

            if canRemove {
                Section {
                    Button("Remove from home", role: .destructive, action: onRemove)
                        .accessibilityLabel("Remove \(member.displayName) from home")
                }
            }
        }
        .navigationTitle(member.displayName)
        .navigationBarTitleDisplayMode(.inline)
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
            if canManage && member.role != .owner {
                Picker("Role", selection: Binding(
                    get: { member.role },
                    set: { onRoleChange($0) }
                )) {
                    Text(HomeRole.manager.displayName).tag(HomeRole.manager)
                    Text(HomeRole.guest.displayName).tag(HomeRole.guest)
                }
                .pickerStyle(.menu)
            } else {
                Text(member.role.displayName)
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
                    Text("\(invite.role.displayName) · Pending")
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

    func remove(homeId: UUID, membershipId: UUID, using repository: MemberRepository?) async {
        guard let repository else { return }
        do {
            try await repository.removeMember(homeId: homeId, membershipId: membershipId)
            snapshot = try await repository.fetchHomeMembers(homeId: homeId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
