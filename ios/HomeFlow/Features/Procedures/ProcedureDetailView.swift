import SwiftUI

// @covers FR-PROC-02, FR-PROC-03, FR-LOG-01, AC-PROC-01, AC-PROC-02, AC-GUEST-04

struct ProcedureDetailView: View {
    let home: HomeSummary
    let procedureId: UUID
    @Environment(\.appEnvironment) private var appEnvironment
    @StateObject private var viewModel = ProcedureDetailViewModel()
    @State private var notesStep: ProcedureStepSummary?

    private var userRole: HomeRole {
        home.currentUserRole ?? .guest
    }

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
                                        userRole: userRole,
                                        using: appEnvironment?.procedureRepository
                                    )
                                }
                            },
                            onEditNotes: {
                                notesStep = step
                            }
                        )
                    }
                }

                if viewModel.canViewActivity {
                    Section("Recent activity") {
                        if viewModel.activity.isEmpty {
                            Text("Activity will appear here when steps are updated.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.activity) { entry in
                                ActivityLogRow(entry: entry)
                            }
                        }
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
        .sheet(item: $notesStep) { step in
            StepNotesEditor(
                stepTitle: step.title,
                initialNotes: step.notes ?? "",
                onSave: { notes in
                    Task {
                        await viewModel.updateNotes(
                            homeId: home.id,
                            procedureId: procedureId,
                            stepId: step.id,
                            notes: notes,
                            userRole: userRole,
                            using: appEnvironment?.procedureRepository
                        )
                    }
                }
            )
        }
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
            userRole: userRole,
            using: repo
        )
    }
}

private struct ProcedureStepRow: View {
    let step: ProcedureStepSummary
    let canEdit: Bool
    let onStatusChange: (StepStatus) -> Void
    let onEditNotes: () -> Void

    private var isStruckThrough: Bool {
        step.status == .complete || step.status == .na
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StepStatusIcon(status: step.status)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.body)
                    .strikethrough(isStruckThrough, color: .secondary)
                    .foregroundStyle(isStruckThrough ? .secondary : .primary)
                if let notes = step.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .strikethrough(isStruckThrough, color: .secondary)
                } else if canEdit {
                    Text("Add note")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            if canEdit {
                Button(action: onEditNotes) {
                    Image(systemName: step.notes?.isEmpty == false ? "note.text" : "square.and.pencil")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit notes for \(step.title)")

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
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More status options for \(step.title)")
            } else if step.status != .notStarted {
                Text(statusLabel(step.status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard canEdit else { return }
            onStatusChange(toggledStatus)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(canEdit ? .isButton : [])
        .accessibilityHint(canEdit ? "Double tap to mark complete or not started. N/A steps clear to not started." : "")
    }

    private var toggledStatus: StepStatus {
        switch step.status {
        case .complete, .na:
            return .notStarted
        case .notStarted, .inProgress:
            return .complete
        }
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
            .font(.title3)
            .foregroundStyle(iconColor)
            .symbolRenderingMode(.hierarchical)
            .accessibilityHidden(true)
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

private struct ActivityLogRow: View {
    let entry: ActivityLogSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.summary)
                .font(.subheadline)
            Text(entry.createdAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct StepNotesEditor: View {
    let stepTitle: String
    let initialNotes: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var notes: String

    init(stepTitle: String, initialNotes: String, onSave: @escaping (String) -> Void) {
        self.stepTitle = stepTitle
        self.initialNotes = initialNotes
        self.onSave = onSave
        _notes = State(initialValue: initialNotes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 140)
                } header: {
                    Text(stepTitle)
                } footer: {
                    Text("Notes are visible to everyone who can view this procedure.")
                }
            }
            .navigationTitle("Step notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(notes)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

@MainActor
final class ProcedureDetailViewModel: ObservableObject {
    @Published var detail: ProcedureDetail?
    @Published var activity: [ActivityLogSummary] = []
    @Published var canEdit = false
    @Published var canViewActivity = false
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
            canViewActivity = repository.canViewActivityLog(userRole: userRole)
            activity = try await repository.fetchProcedureActivity(
                procedureId: procedureId,
                homeId: homeId,
                userRole: userRole
            )
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
            await refreshAfterMutation(
                procedureId: procedureId,
                homeId: homeId,
                userRole: userRole,
                using: repository
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateNotes(
        homeId: UUID,
        procedureId: UUID,
        stepId: UUID,
        notes: String,
        userRole: HomeRole,
        using repository: ProcedureRepository?
    ) async {
        guard let repository else { return }
        do {
            try await repository.updateStepNotes(
                homeId: homeId,
                procedureId: procedureId,
                stepId: stepId,
                notes: notes,
                userRole: userRole
            )
            await refreshAfterMutation(
                procedureId: procedureId,
                homeId: homeId,
                userRole: userRole,
                using: repository
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshAfterMutation(
        procedureId: UUID,
        homeId: UUID,
        userRole: HomeRole,
        using repository: ProcedureRepository
    ) async {
        detail = try? await repository.fetchProcedureDetail(
            procedureId: procedureId,
            homeId: homeId,
            userRole: userRole
        )
        if let detail {
            canEdit = repository.canUpdateSteps(for: detail, userRole: userRole)
        }
        activity = (try? await repository.fetchProcedureActivity(
            procedureId: procedureId,
            homeId: homeId,
            userRole: userRole
        )) ?? activity
    }
}
