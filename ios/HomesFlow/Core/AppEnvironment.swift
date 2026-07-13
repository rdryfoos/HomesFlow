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
    let procedureRepository: ProcedureRepository
    let providerRepository: ServiceProviderRepository
    let documentRepository: DocumentRepository
    let procedureAttachmentService: ProcedureAttachmentService
    let logBookRepository: LogBookRepository

    init(modelContext: ModelContext) {
        auth = SupabaseClientProvider.shared
        activityLog = ActivityLogService(modelContext: modelContext, client: auth.client)
        syncEngine = SyncEngine(
            modelContext: modelContext,
            client: auth.client,
            activityLog: activityLog
        )
        homePhotoService = HomePhotoService(client: auth.client)
        procedureAttachmentService = ProcedureAttachmentService(client: auth.client)
        let documentStorage = DocumentStorageService(client: auth.client)
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
        procedureRepository = ProcedureRepository(
            modelContext: modelContext,
            auth: auth,
            activityLog: activityLog,
            syncEngine: syncEngine,
            attachmentService: procedureAttachmentService
        )
        providerRepository = ServiceProviderRepository(
            modelContext: modelContext,
            auth: auth,
            activityLog: activityLog,
            syncEngine: syncEngine
        )
        documentRepository = DocumentRepository(
            modelContext: modelContext,
            auth: auth,
            activityLog: activityLog,
            syncEngine: syncEngine,
            storage: documentStorage
        )
        logBookRepository = LogBookRepository(
            modelContext: modelContext,
            auth: auth,
            syncEngine: syncEngine
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
