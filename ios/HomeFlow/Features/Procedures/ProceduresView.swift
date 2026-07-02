import SwiftUI

// @covers FR-PROC-01, FR-PROC-02, NFR-PERF-01, AC-GUEST-02, AC-GUEST-04

struct ProceduresView: View {
    let home: HomeSummary
    @Environment(\.appEnvironment) private var appEnvironment
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var syncEngine: SyncEngine
    @StateObject private var viewModel = ProceduresViewModel()
    @State private var selectedProcedureId: UUID?
    @State private var showSyncAlert = false

    private var userRole: HomeRole {
        home.currentUserRole ?? .guest
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.procedures.isEmpty {
                ProgressView("Loading procedures…")
            }
        }
        .refreshable {
            await reload()
        }
        .task { await reload() }
        .onChange(of: viewModel.procedures.map(\.id)) { _, ids in
            guard sizeClass == .regular else { return }
            if let selectedProcedureId, ids.contains(selectedProcedureId) { return }
            selectedProcedureId = ids.first
        }
        .onChange(of: selectedProcedureId) { _, newId in
            guard sizeClass == .regular, let newId, let repo = appEnvironment?.procedureRepository else { return }
            if repo.procedureAccessState(procedureId: newId, userRole: userRole) == .accessDenied {
                selectedProcedureId = viewModel.procedures.first?.id
            }
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

    private var iPadLayout: some View {
        NavigationSplitView {
            procedureList(useSelection: true)
        } detail: {
            if let procedureId = selectedProcedureId ?? viewModel.procedures.first?.id,
               let repo = appEnvironment?.procedureRepository {
                switch repo.procedureAccessState(procedureId: procedureId, userRole: userRole) {
                case .accessDenied:
                    GuestAccessDeniedView(
                        message: "This procedure is not shared with guest accounts."
                    )
                case .notFound:
                    ContentUnavailableView(
                        "Procedure not found",
                        systemImage: "checklist",
                        description: Text("This procedure may have been removed.")
                    )
                case .allowed:
                    ProcedureDetailView(home: home, procedureId: procedureId)
                        .environment(\.appEnvironment, appEnvironment)
                }
            } else {
                ContentUnavailableView(
                    "Select a procedure",
                    systemImage: "checklist",
                    description: Text("Choose a procedure from the list.")
                )
            }
        }
    }

    private var iPhoneLayout: some View {
        procedureList(useSelection: false)
            .navigationDestination(for: ProcedureSummary.self) { procedure in
                ProcedureDetailView(home: home, procedureId: procedure.id)
                    .environment(\.appEnvironment, appEnvironment)
            }
    }

    @ViewBuilder
    private func procedureList(useSelection: Bool) -> some View {
        if viewModel.procedures.isEmpty && !viewModel.isLoading {
            ContentUnavailableView(
                "No procedures",
                systemImage: "checklist",
                description: Text("Procedures for this home will appear here.")
            )
        } else if useSelection {
            List(viewModel.procedures, selection: $selectedProcedureId) { procedure in
                ProcedureRow(procedure: procedure)
                    .tag(procedure.id)
            }
        } else {
            List(viewModel.procedures) { procedure in
                NavigationLink(value: procedure) {
                    ProcedureRow(procedure: procedure)
                }
            }
        }
    }

    private func reload() async {
        guard let repo = appEnvironment?.procedureRepository else { return }
        await viewModel.load(
            homeId: home.id,
            userRole: userRole,
            using: repo
        )
    }
}

private struct ProcedureRow: View {
    let procedure: ProcedureSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(procedure.title)
                    .font(.headline)
                if let category = procedure.category, !category.isEmpty {
                    Text(category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                ProcedureStatusBadge(status: procedure.status)
                Text(procedure.progressLabel)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ProcedureStatusBadge: View {
    let status: ProcedureStatus

    var body: some View {
        Text(label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        switch status {
        case .notStarted: "Not started"
        case .inProgress: "In progress"
        case .complete: "Complete"
        case .na: "N/A"
        }
    }

    private var color: Color {
        switch status {
        case .notStarted: .secondary
        case .inProgress: .orange
        case .complete: .green
        case .na: .gray
        }
    }
}

@MainActor
final class ProceduresViewModel: ObservableObject {
    @Published var procedures: [ProcedureSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(homeId: UUID, userRole: HomeRole, using repository: ProcedureRepository) async {
        isLoading = true
        defer { isLoading = false }
        do {
            procedures = try await repository.fetchProcedures(homeId: homeId, userRole: userRole)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
