import SwiftUI

// @covers FR-PROC-01, FR-PROC-02

struct ProceduresView: View {
    let home: HomeSummary
    @Environment(\.appEnvironment) private var appEnvironment
    @StateObject private var viewModel = ProceduresViewModel()

    var body: some View {
        Group {
            if viewModel.procedures.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No procedures",
                    systemImage: "checklist",
                    description: Text("Procedures for this home will appear here.")
                )
            } else {
                List(viewModel.procedures) { procedure in
                    NavigationLink(value: procedure) {
                        ProcedureRow(procedure: procedure)
                    }
                }
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
        .navigationDestination(for: ProcedureSummary.self) { procedure in
            ProcedureDetailView(home: home, procedureId: procedure.id)
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
        guard let repo = appEnvironment?.procedureRepository else { return }
        await viewModel.load(
            homeId: home.id,
            userRole: home.currentUserRole ?? .guest,
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
