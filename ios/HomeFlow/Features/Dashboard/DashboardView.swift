import SwiftUI

// @covers FR-HOME-01, US-ADMIN-01

struct DashboardView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .task { await viewModel.load() }
        .navigationTitle("My Homes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign Out") {
                    Task {
                        try? await SupabaseClientProvider.shared.signOut()
                    }
                }
            }
        }
    }

    private var iPhoneLayout: some View {
        NavigationStack {
            homeList
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            homeList
        } detail: {
            ContentUnavailableView(
                "Select a home",
                systemImage: "house",
                description: Text("Choose a home from the sidebar")
            )
        }
    }

    private var homeList: some View {
        List {
            if viewModel.homes.isEmpty {
                ContentUnavailableView(
                    "No homes yet",
                    systemImage: "house",
                    description: Text("Add your first second home to get started.")
                )
            } else {
                ForEach(viewModel.homes) { home in
                    NavigationLink(value: home.id) {
                        VStack(alignment: .leading) {
                            Text(home.name).font(.headline)
                            Text(home.streetAddress).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isLoading {
                ProgressView().padding()
            }
        }
    }
}

struct HomeSummary: Identifiable, Sendable {
    let id: UUID
    let name: String
    let streetAddress: String
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var homes: [HomeSummary] = []
    @Published var isLoading = false

    func load() async {
        isLoading = true
        defer { isLoading = false }
        // Phase 1: fetch from Supabase + SwiftData cache
        homes = []
    }
}
