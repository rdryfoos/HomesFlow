import SwiftUI

// @covers FR-AUTH-01

@MainActor
final class AppRouter: ObservableObject {
    enum Route: Equatable {
        case auth
        case dashboard
    }

    @Published var route: Route = .auth

    private let auth: SupabaseClientProvider

    init(auth: SupabaseClientProvider = .shared) {
        self.auth = auth
        route = auth.isAuthenticated ? .dashboard : .auth
    }

    func refreshRoute() {
        route = auth.isAuthenticated ? .dashboard : .auth
    }
}

struct RootView: View {
    @ObservedObject var router: AppRouter
    @ObservedObject private var network = NetworkMonitor.shared
    @Environment(\.modelContext) private var modelContext
    @StateObject private var auth = SupabaseClientProvider.shared
    @State private var syncEngine: SyncEngine?

    var body: some View {
        Group {
            switch router.route {
            case .auth:
                AuthView(onAuthenticated: { router.refreshRoute() })
            case .dashboard:
                DashboardView()
            }
        }
        .onAppear {
            if syncEngine == nil {
                syncEngine = SyncEngine(
                    modelContext: modelContext,
                    client: auth.client,
                    activityLog: ActivityLogService(modelContext: modelContext)
                )
            }
        }
        .onChange(of: network.isConnected) { _, connected in
            if connected {
                Task { await syncEngine?.run() }
            }
        }
        .onChange(of: auth.isAuthenticated) { _, _ in
            router.refreshRoute()
        }
    }
}
