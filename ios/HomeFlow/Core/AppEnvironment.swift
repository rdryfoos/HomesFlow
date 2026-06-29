import SwiftUI
import SwiftData

@MainActor
final class AppEnvironment: ObservableObject {
    let auth: SupabaseClientProvider
    let syncEngine: SyncEngine
    let activityLog: ActivityLogService
    let homePhotoService: HomePhotoService
    let homeRepository: HomeRepository
    let memberRepository: MemberRepository

    init(modelContext: ModelContext) {
        auth = SupabaseClientProvider.shared
        activityLog = ActivityLogService(modelContext: modelContext)
        syncEngine = SyncEngine(
            modelContext: modelContext,
            client: auth.client,
            activityLog: activityLog
        )
        homePhotoService = HomePhotoService(client: auth.client)
        homeRepository = HomeRepository(
            modelContext: modelContext,
            auth: auth,
            syncEngine: syncEngine,
            activityLog: activityLog,
            homePhotoService: homePhotoService
        )
        memberRepository = MemberRepository(
            modelContext: modelContext,
            auth: auth,
            activityLog: activityLog
        )
    }
}

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment? = nil
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment? {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
