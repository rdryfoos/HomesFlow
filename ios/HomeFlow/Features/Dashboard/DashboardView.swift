import SwiftUI

// @covers FR-HOME-01, US-ADMIN-01

struct DashboardView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appEnvironment) private var appEnvironment
    @EnvironmentObject private var syncEngine: SyncEngine

    @StateObject private var viewModel = DashboardViewModel()
    @State private var showAddHome = false
    @State private var showJoinInvite = false
    @State private var selectedHomeId: UUID?
    @State private var showSyncAlert = false

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .task { await reload() }
        .sheet(isPresented: $showAddHome) {
            HomeSetupView { home in
                Task { await reload() }
                selectedHomeId = home.id
            }
            .environment(\.appEnvironment, appEnvironment)
        }
        .sheet(isPresented: $showJoinInvite) {
            NavigationStack {
                Form {
                    AcceptInviteView {
                        Task { await reload() }
                        showJoinInvite = false
                    }
                }
                .navigationTitle("Join Home")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showJoinInvite = false }
                    }
                }
            }
            .environment(\.appEnvironment, appEnvironment)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Sync Issue", isPresented: $showSyncAlert) {
            Button("OK", role: .cancel) {
                syncEngine.clearNotification()
            }
        } message: {
            Text(syncEngine.lastNotification?.message ?? "")
        }
        .onChange(of: syncEngine.lastNotification?.id) { _, _ in
            showSyncAlert = syncEngine.lastNotification != nil
        }
    }

    private var iPhoneLayout: some View {
        NavigationStack {
            homeList
                .navigationTitle("My Homes")
                .toolbar { toolbarContent }
                .navigationDestination(for: UUID.self) { homeId in
                    if let home = viewModel.homes.first(where: { $0.id == homeId }) {
                        HomeDetailView(home: home)
                    }
                }
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            homeList
                .navigationTitle("My Homes")
                .toolbar { toolbarContent }
        } detail: {
            if let home = viewModel.homes.first(where: { $0.id == selectedHomeId }) {
                HomeDetailView(home: home)
            } else {
                ContentUnavailableView(
                    "Select a home",
                    systemImage: "house",
                    description: Text("Choose a home from the sidebar")
                )
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button {
                    showAddHome = true
                } label: {
                    Label("Add Home", systemImage: "plus")
                }
                Button {
                    showJoinInvite = true
                } label: {
                    Label("Join with Invite", systemImage: "person.crop.circle.badge.plus")
                }
            } label: {
                Label("Home actions", systemImage: "plus")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Sign Out") {
                Task { try? await SupabaseClientProvider.shared.signOut() }
            }
        }
    }

    private var homeList: some View {
        List(selection: $selectedHomeId) {
            if let message = syncEngine.lastNotification?.message {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                }
            }

            if viewModel.homes.contains(where: \.isPendingSync) {
                Section {
                    Label(
                        "Some homes haven't synced to Supabase yet. Pull to refresh after confirming `supabase status` is running.",
                        systemImage: "icloud.and.arrow.up"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(viewModel.homes) { home in
                    NavigationLink(value: home.id) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(home.name).font(.headline)
                                Text(home.streetAddress)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if home.isPendingSync {
                                Image(systemName: "icloud.and.arrow.up")
                                    .foregroundStyle(.orange)
                                    .accessibilityLabel("Not synced")
                            }
                        }
                    }
                    .tag(home.id)
                }
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.homes.isEmpty {
                ProgressView("Loading homes…")
            } else if viewModel.homes.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No homes yet",
                    systemImage: "house",
                    description: Text("Tap Add Home to create your first second home.")
                )
            }
        }
        .refreshable { await reload() }
    }

    private func reload() async {
        guard let repo = appEnvironment?.homeRepository else { return }
        await viewModel.load(using: repo)
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var homes: [HomeSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(using repository: HomeRepository) async {
        isLoading = true
        defer { isLoading = false }
        do {
            homes = try await repository.fetchHomes()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
