import SwiftUI

// @covers FR-USER-02, AC-USER-01, AC-USER-02, AC-USER-04…06, FR-NAV-01, AC-HOME-12, AC-SYNC-07
//
// People tab layout:
// - iPad (regular): NavigationSplitView + `PeopleSelection` tagged list → detail column.
// - iPhone (compact): no list selection; pending invites use `inviteDetailSheet` (do not
//   forget the sheet when changing iPad selection plumbing).

struct MembersView: View {
    let home: HomeSummary
    @Environment(\.appEnvironment) private var appEnvironment
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var network: NetworkMonitor

    @StateObject private var viewModel = MembersViewModel()
    @State private var showInviteSheet = false
    @State private var selectedPeople: PeopleSelection?
    @State private var memberPendingRemoval: MemberSummary?
    @State private var invitePendingRevoke: InviteSummary?
    /// iPhone only — compact width has no split detail column.
    @State private var inviteDetailSheet: InviteSummary?

    private var canManageMembersOnline: Bool {
        viewModel.snapshot.currentUserRole == .owner
            && StructuralActionPolicy.canPerformStructuralActions(isConnected: network.isConnected)
    }

    var body: some View {
        content
            .overlay { loadingOverlay }
            .refreshable { await reload() }
            .toolbar { inviteToolbar }
            .safeAreaInset(edge: .bottom) { offlineMembersHint }
            .sheet(isPresented: $showInviteSheet) { createInviteSheet }
            .sheet(item: $inviteDetailSheet) { invite in
                compactInviteDetailSheet(invite)
            }
            .task { await reload() }
            .onChange(of: viewModel.snapshot.members.map(\.id)) { _, _ in
                repairSelectionIfNeeded()
            }
            .onChange(of: viewModel.snapshot.pendingInvites.map(\.id)) { _, _ in
                repairSelectionIfNeeded()
            }
            .alert("Error", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .confirmationDialog(
                "Remove \(memberPendingRemoval?.displayName ?? "member")?",
                isPresented: memberRemovalDialogBinding,
                titleVisibility: .visible
            ) {
                Button("Remove from home", role: .destructive) {
                    confirmMemberRemoval()
                }
            } message: {
                Text("They will lose access to this home on their next sync.")
            }
            .confirmationDialog(
                "Revoke invite for \(invitePendingRevoke?.email ?? "invitee")?",
                isPresented: inviteRevokeDialogBinding,
                titleVisibility: .visible
            ) {
                Button("Revoke invite", role: .destructive) {
                    confirmInviteRevoke()
                }
            } message: {
                if let email = invitePendingRevoke?.email {
                    Text(InvitePolicy.revokeConfirmationMessage(email: email))
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if sizeClass == .regular {
            NavigationSplitView {
                membersList(useSelection: true)
            } detail: {
                peopleDetailPanel
            }
        } else {
            membersList(useSelection: false)
        }
    }

    @ViewBuilder
    private var loadingOverlay: some View {
        if viewModel.isLoading && viewModel.snapshot.members.isEmpty {
            ProgressView("Loading members…")
        }
    }

    @ToolbarContentBuilder
    private var inviteToolbar: some ToolbarContent {
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

    @ViewBuilder
    private var offlineMembersHint: some View {
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

    private var createInviteSheet: some View {
        InviteMemberView(home: home) {
            Task { await reload() }
        }
        .environment(\.appEnvironment, appEnvironment)
    }

    private func compactInviteDetailSheet(_ invite: InviteSummary) -> some View {
        NavigationStack {
            PendingInviteDetailView(
                invite: invite,
                canRevoke: canManageMembersOnline,
                onRevoke: { invitePendingRevoke = invite }
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { inviteDetailSheet = nil }
                }
            }
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var memberRemovalDialogBinding: Binding<Bool> {
        Binding(
            get: { memberPendingRemoval != nil },
            set: { if !$0 { memberPendingRemoval = nil } }
        )
    }

    private var inviteRevokeDialogBinding: Binding<Bool> {
        Binding(
            get: { invitePendingRevoke != nil },
            set: { if !$0 { invitePendingRevoke = nil } }
        )
    }

    private func confirmMemberRemoval() {
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

    private func confirmInviteRevoke() {
        guard let invite = invitePendingRevoke else { return }
        invitePendingRevoke = nil
        inviteDetailSheet = nil
        Task {
            await viewModel.revoke(
                homeId: home.id,
                inviteId: invite.id,
                using: appEnvironment?.memberRepository
            )
            repairSelectionIfNeeded()
        }
    }

    @ViewBuilder
    private var peopleDetailPanel: some View {
        switch selectedPeople {
        case .member(let memberId):
            if let member = viewModel.snapshot.members.first(where: { $0.id == memberId }) {
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
            } else {
                peoplePlaceholder
            }
        case .invite(let inviteId):
            if let invite = viewModel.snapshot.pendingInvites.first(where: { $0.id == inviteId }) {
                PendingInviteDetailView(
                    invite: invite,
                    canRevoke: canManageMembersOnline,
                    onRevoke: { invitePendingRevoke = invite }
                )
            } else {
                peoplePlaceholder
            }
        case nil:
            peoplePlaceholder
        }
    }

    @ViewBuilder
    private var peoplePlaceholder: some View {
        if viewModel.isLoading {
            ProgressView("Loading members…")
        } else {
            ContentUnavailableView(
                "Select a person or invite",
                systemImage: "person.2",
                description: Text("Choose a member or pending invite to view details.")
            )
        }
    }

    @ViewBuilder
    private func membersList(useSelection: Bool) -> some View {
        if useSelection && hasSelectableRows {
            List(selection: $selectedPeople) {
                membersSections(showRolePicker: false, useSelection: true)
            }
        } else {
            List {
                membersSections(showRolePicker: canManageMembersOnline, useSelection: false)
            }
        }
    }

    private var hasSelectableRows: Bool {
        !viewModel.snapshot.members.isEmpty || !viewModel.snapshot.pendingInvites.isEmpty
    }

    @ViewBuilder
    private func membersSections(showRolePicker: Bool, useSelection: Bool) -> some View {
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
                    .tag(PeopleSelection.member(member.id))
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
                    pendingInviteRow(invite: invite, useSelection: useSelection)
                }
            }
        }
    }

    @ViewBuilder
    private func pendingInviteRow(invite: InviteSummary, useSelection: Bool) -> some View {
        if useSelection {
            InviteRow(invite: invite)
                .tag(PeopleSelection.invite(invite.id))
        } else {
            Button {
                inviteDetailSheet = invite
            } label: {
                InviteRow(invite: invite)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens invite details and share link")
        }
    }

    private func repairSelectionIfNeeded() {
        guard sizeClass == .regular else { return }
        selectedPeople = PeopleSelectionRepair.repair(
            current: selectedPeople,
            memberIds: viewModel.snapshot.members.map(\.id),
            inviteIds: viewModel.snapshot.pendingInvites.map(\.id)
        )
    }

    private func reload() async {
        guard let repo = appEnvironment?.memberRepository else { return }
        await viewModel.load(homeId: home.id, using: repo)
        repairSelectionIfNeeded()
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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(invite.email).font(.headline)
            Text("\(invite.role.displayName) · Pending")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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
