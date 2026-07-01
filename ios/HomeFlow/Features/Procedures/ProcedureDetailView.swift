import SwiftUI

// @covers FR-PROC-02, AC-PROC-01, AC-PROC-02, AC-GUEST-04

struct ProcedureDetailView: View {
    let home: HomeSummary
    let procedureId: UUID
    @Environment(\.appEnvironment) private var appEnvironment
    @StateObject private var viewModel = ProcedureDetailViewModel()

    var body: some View {
        List {
            if let detail = viewModel.detail {
                if let description = detail.description, !description.isEmpty {
                    Section {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Steps") {
                    ForEach(detail.steps) { step in
                        ProcedureStepRow(
                            step: step,
                            canEdit: viewModel.canEdit,
                            onStatusChange: { status in
                                Task {
                                    await viewModel.updateStatus(
                                        homeId: home.id,
                                        procedureId: procedureId,
                                        stepId: step.id,
                                        status: status,
                                        userRole: home.currentUserRole ?? .guest,
                                        using: appEnvironment?.procedureRepository
                                    )
                                }
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle(viewModel.detail?.title ?? "Procedure")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading && viewModel.detail == nil {
                ProgressView("Loading…")
            }
        }
        .refreshable {
            await reload()
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
            procedureId: procedureId,
            homeId: home.id,
            userRole: home.currentUserRole ?? .guest,
            using: repo
        )
    }
}

private struct ProcedureStepRow: View {
    let step: ProcedureStepSummary
    let canEdit: Bool
    let onStatusChange: (StepStatus) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StepStatusIcon(status: step.status)
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.body)
                if let notes = step.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if canEdit {
                Menu {
                    ForEach(StepStatus.allCases, id: \.self) { status in
                        Button {
                            onStatusChange(status)
                        } label: {
                            if step.status == status {
                                Label(statusLabel(status), systemImage: "checkmark")
                            } else {
                                Text(statusLabel(status))
                            }
                        }
                    }
                } label: {
                    Text(statusLabel(step.status))
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            } else {
                Text(statusLabel(step.status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func statusLabel(_ status: StepStatus) -> String {
        switch status {
        case .notStarted: "Not started"
        case .inProgress: "In progress"
        case .complete: "Complete"
        case .na: "N/A"
        }
    }
}

private struct StepStatusIcon: View {
    let status: StepStatus

    var body: some View {
        Image(systemName: iconName)
            .foregroundStyle(iconColor)
            .frame(width: 22)
    }

    private var iconName: String {
        switch status {
        case .notStarted: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .complete: "checkmark.circle.fill"
        case .na: "minus.circle"
        }
    }

    private var iconColor: Color {
        switch status {
        case .notStarted: .secondary
        case .inProgress: .orange
        case .complete: .green
        case .na: .gray
        }
    }
}

@MainActor
final class ProcedureDetailViewModel: ObservableObject {
    @Published var detail: ProcedureDetail?
    @Published var canEdit = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(
        procedureId: UUID,
        homeId: UUID,
        userRole: HomeRole,
        using repository: ProcedureRepository
    ) async {
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await repository.fetchProcedureDetail(
                procedureId: procedureId,
                homeId: homeId,
                userRole: userRole
            )
            if let detail {
                canEdit = repository.canUpdateSteps(for: detail, userRole: userRole)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateStatus(
        homeId: UUID,
        procedureId: UUID,
        stepId: UUID,
        status: StepStatus,
        userRole: HomeRole,
        using repository: ProcedureRepository?
    ) async {
        guard let repository else { return }
        do {
            try await repository.updateStepStatus(
                homeId: homeId,
                procedureId: procedureId,
                stepId: stepId,
                status: status,
                userRole: userRole
            )
            detail = try await repository.fetchProcedureDetail(
                procedureId: procedureId,
                homeId: homeId,
                userRole: userRole
            )
            if let detail {
                canEdit = repository.canUpdateSteps(for: detail, userRole: userRole)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
