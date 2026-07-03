import SwiftUI
import SwiftData

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
    @ObservedObject private var auth = SupabaseClientProvider.shared
    @Environment(\.modelContext) private var modelContext
    @State private var appEnvironment: AppEnvironment?

    var body: some View {
        Group {
            switch router.route {
            case .auth:
                AuthView()
            case .dashboard:
                if let appEnvironment {
                    DashboardView()
                        .environment(\.appEnvironment, appEnvironment)
                        .environmentObject(appEnvironment.syncEngine)
                        .environmentObject(network)
                } else {
                    ProgressView()
                }
            }
        }
        .onAppear {
            if appEnvironment == nil {
                appEnvironment = AppEnvironment(modelContext: modelContext)
            }
        }
        .onChange(of: network.isConnected) { _, connected in
            if connected {
                Task { await appEnvironment?.syncEngine.run() }
            }
        }
        .onChange(of: auth.isAuthenticated) { _, _ in
            router.refreshRoute()
        }
    }
}
