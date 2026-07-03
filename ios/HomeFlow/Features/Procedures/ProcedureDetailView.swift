import SwiftUI
import PhotosUI

// @covers FR-PROC-02, FR-PROC-03, FR-LOG-01, AC-PROC-01, AC-PROC-02, AC-PROC-04, AC-PROC-05, AC-PROC-07, AC-PROC-08, AC-GUEST-04

struct ProcedureDetailView: View {
    let home: HomeSummary
    let procedureId: UUID
    @Environment(\.appEnvironment) private var appEnvironment
    @StateObject private var viewModel = ProcedureDetailViewModel()
    @State private var editingStep: ProcedureStepSummary?
    @State private var isAddingStep = false
    @State private var newStepTitle = ""
    @State private var deleteTarget: ProcedureStepSummary?
    @State private var photoPreviewStep: ProcedureStepSummary?

    private var userRole: HomeRole {
        home.currentUserRole ?? .guest
    }

    var body: some View {
        Group {
            if viewModel.accessDenied {
                GuestAccessDeniedView(
                    message: "This procedure is not shared with guest accounts."
                )
            } else {
                procedureContent
            }
        }
        .navigationTitle(viewModel.detail?.title ?? "Procedure")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading && viewModel.detail == nil && !viewModel.accessDenied {
                ProgressView("Loading…")
            }
        }
        .refreshable {
            await reload()
        }
        .sheet(item: $photoPreviewStep) { step in
            StepPhotoPreviewSheet(step: step)
        }
        .task { await reload() }
        .sheet(item: $editingStep) { step in
            StepEditorSheet(
                homeId: home.id,
                procedureId: procedureId,
                step: step,
                canEditTitle: viewModel.canManageStructure,
                onSave: { title, notes, photoChange in
                    Task {
                        await viewModel.updateStepDetails(
                            homeId: home.id,
                            procedureId: procedureId,
                            stepId: step.id,
                            title: title,
                            notes: notes,
                            photoChange: photoChange,
                            canEditTitle: viewModel.canManageStructure,
                            userRole: userRole,
                            using: appEnvironment?.procedureRepository
                        )
                    }
                }
            )
            .environment(\.appEnvironment, appEnvironment)
        }
        .alert("Add Step", isPresented: $isAddingStep) {
            TextField("Step title", text: $newStepTitle)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let title = newStepTitle
                Task {
                    await viewModel.createStep(
                        homeId: home.id,
                        procedureId: procedureId,
                        title: title,
                        userRole: userRole,
                        using: appEnvironment?.procedureRepository
                    )
                }
            }
        } message: {
            Text("The new step is added at the end of the list.")
        }
        .confirmationDialog(
            "Delete \"\(deleteTarget?.title ?? "step")\"?",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Step", role: .destructive) {
                guard let step = deleteTarget else { return }
                Task {
                    await viewModel.deleteStep(
                        homeId: home.id,
                        procedureId: procedureId,
                        stepId: step.id,
                        userRole: userRole,
                        using: appEnvironment?.procedureRepository
                    )
                }
            }
        } message: {
            Text("This removes the step for everyone in this home.")
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

    @ViewBuilder
    private var procedureContent: some View {
        List {
            if let detail = viewModel.detail {
                if let description = detail.description, !description.isEmpty {
                    Section {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach(Array(detail.steps.enumerated()), id: \.element.id) { index, step in
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
                            onEditDetails: {
                                editingStep = step
                            },
                            onViewPhoto: {
                                photoPreviewStep = step
                            }
                        )
                        .contextMenu {
                            if viewModel.canManageStructure {
                                Button {
                                    editingStep = step
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button {
                                    moveStep(step, direction: .up)
                                } label: {
                                    Label("Move Up", systemImage: "arrow.up")
                                }
                                .disabled(index == 0)
                                Button {
                                    moveStep(step, direction: .down)
                                } label: {
                                    Label("Move Down", systemImage: "arrow.down")
                                }
                                .disabled(index == detail.steps.count - 1)
                                Divider()
                                Button(role: .destructive) {
                                    deleteTarget = step
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Steps")
                        Spacer()
                        if viewModel.canManageStructure {
                            Button {
                                newStepTitle = ""
                                isAddingStep = true
                            } label: {
                                Label("Add step", systemImage: "plus")
                                    .labelStyle(.iconOnly)
                                    .frame(
                                        width: AccessibilityBaseline.minimumTapTarget,
                                        height: AccessibilityBaseline.minimumTapTarget
                                    )
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Add step")
                        }
                    }
                } footer: {
                    if viewModel.canManageStructure {
                        Text("Touch and hold a step to edit, reorder, or delete it.")
                    } else if !viewModel.canEdit {
                        Text("Step statuses are read-only for guest accounts.")
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
    }

    private func moveStep(_ step: ProcedureStepSummary, direction: StepMoveDirection) {
        Task {
            await viewModel.moveStep(
                homeId: home.id,
                procedureId: procedureId,
                stepId: step.id,
                direction: direction,
                userRole: userRole,
                using: appEnvironment?.procedureRepository
            )
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
    let onEditDetails: () -> Void
    let onViewPhoto: () -> Void

    private var isStruckThrough: Bool {
        StepRowPresentation.isStruckThrough(step.status)
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
                if let notes = step.notes, StepRowPresentation.showsNotes(notes) {
                    StepAttachmentRow(
                        systemImage: "text.alignleft",
                        text: notes,
                        struckThrough: isStruckThrough
                    )
                }
                if StepRowPresentation.showsPhotoIndicator(photoURL: step.photoURL) {
                    Button(action: onViewPhoto) {
                        StepAttachmentRow(
                            systemImage: "photo",
                            text: "Photo attached",
                            struckThrough: isStruckThrough
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View photo for \(step.title)")
                }
            }

            Spacer(minLength: 8)

            if StepRowPresentation.showsEditControls(canEdit: canEdit) {
                // NFR-A11Y-01: 44pt minimum tap targets on row actions.
                Button(action: onEditDetails) {
                    Image(systemName: "pencil")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(
                            width: AccessibilityBaseline.minimumTapTarget,
                            height: AccessibilityBaseline.minimumTapTarget
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit details for \(step.title)")

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
                        .frame(
                            width: AccessibilityBaseline.minimumTapTarget,
                            height: AccessibilityBaseline.minimumTapTarget
                        )
                        .contentShape(Rectangle())
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
        // AC-A11Y-02-adjacent: VoiceOver announces the step's current status.
        .accessibilityValue(AccessibilityBaseline.stepStatusValue(step.status))
        .accessibilityHint(canEdit ? "Double tap to mark complete or not started. N/A steps clear to not started." : "")
    }

    private var toggledStatus: StepStatus {
        StepRowPresentation.toggledStatus(from: step.status)
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

private struct StepAttachmentRow: View {
    let systemImage: String
    let text: String
    var struckThrough = false

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .center)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .strikethrough(struckThrough, color: .secondary)
                .multilineTextAlignment(.leading)
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

private struct StepEditorSheet: View {
    let homeId: UUID
    let procedureId: UUID
    let step: ProcedureStepSummary
    let canEditTitle: Bool
    let onSave: (String?, String?, StepPhotoChange) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var appEnvironment
    @State private var title: String
    @State private var notes: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var removeExistingPhoto = false

    init(
        homeId: UUID,
        procedureId: UUID,
        step: ProcedureStepSummary,
        canEditTitle: Bool,
        onSave: @escaping (String?, String?, StepPhotoChange) -> Void
    ) {
        self.homeId = homeId
        self.procedureId = procedureId
        self.step = step
        self.canEditTitle = canEditTitle
        self.onSave = onSave
        _title = State(initialValue: step.title)
        _notes = State(initialValue: step.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                if canEditTitle {
                    Section("Title") {
                        TextField("Step title", text: $title)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                }

                Section {
                    StepPhotoThumbnail(
                        photoData: selectedPhotoData,
                        storagePath: removeExistingPhoto ? nil : step.photoURL
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Text(hasPhoto ? "Change photo" : "Add photo")
                    }
                    .onChange(of: selectedPhoto) { _, item in
                        Task { await loadPhoto(from: item) }
                    }

                    if hasPhoto {
                        Button("Remove photo", role: .destructive) {
                            selectedPhoto = nil
                            selectedPhotoData = nil
                            removeExistingPhoto = true
                        }
                    }
                } header: {
                    Text("Photo")
                } footer: {
                    Text("Notes and photos are visible to everyone who can view this procedure.")
                }
            }
            .navigationTitle("Edit Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let photoChange: StepPhotoChange
                        if let selectedPhotoData {
                            photoChange = .set(selectedPhotoData)
                        } else if removeExistingPhoto {
                            photoChange = .remove
                        } else {
                            photoChange = .unchanged
                        }
                        onSave(
                            canEditTitle ? title : nil,
                            notes,
                            photoChange
                        )
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var hasPhoto: Bool {
        selectedPhotoData != nil || (step.photoURL != nil && !removeExistingPhoto)
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else {
            selectedPhotoData = nil
            return
        }
        if let data = try? await item.loadTransferable(type: Data.self) {
            selectedPhotoData = data
            removeExistingPhoto = false
        }
    }
}

private struct StepPhotoPreviewSheet: View {
    let step: ProcedureStepSummary

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                StepPhotoThumbnail(
                    photoData: nil,
                    storagePath: step.photoURL,
                    contentMode: .fit
                )
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct StepPhotoThumbnail: View {
    @Environment(\.appEnvironment) private var appEnvironment

    let photoData: Data?
    let storagePath: String?
    var contentMode: ContentMode = .fill

    @State private var loadedImage: UIImage?

    var body: some View {
        Group {
            if let image = displayedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.12))
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task(id: loadKey) {
            await loadPhotoIfNeeded()
        }
    }

    private var loadKey: String {
        "\(storagePath ?? "")|\(photoData?.count ?? 0)"
    }

    private var displayedImage: UIImage? {
        if let photoData, let image = UIImage(data: photoData) {
            return image
        }
        return loadedImage
    }

    private func loadPhotoIfNeeded() async {
        if photoData != nil {
            loadedImage = photoData.flatMap(UIImage.init(data:))
            return
        }

        guard let path = storagePath,
              let repo = appEnvironment?.procedureRepository else {
            loadedImage = nil
            return
        }

        if let cached = repo.cachedStepPhoto(for: path) {
            loadedImage = cached
            return
        }

        loadedImage = try? await repo.loadStepPhoto(storagePath: path)
    }
}

@MainActor
final class ProcedureDetailViewModel: ObservableObject {
    @Published var detail: ProcedureDetail?
    @Published var activity: [ActivityLogSummary] = []
    @Published var canEdit = false
    @Published var canManageStructure = false
    @Published var canViewActivity = false
    @Published var accessDenied = false
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

        switch repository.procedureAccessState(procedureId: procedureId, userRole: userRole) {
        case .accessDenied:
            accessDenied = true
            detail = nil
            activity = []
            canEdit = false
            canManageStructure = false
            canViewActivity = false
            errorMessage = nil
            return
        case .notFound:
            accessDenied = false
            detail = nil
            errorMessage = ProcedureError.notFound.localizedDescription
            return
        case .allowed:
            accessDenied = false
        }

        do {
            detail = try await repository.fetchProcedureDetail(
                procedureId: procedureId,
                homeId: homeId,
                userRole: userRole
            )
            if let detail {
                canEdit = repository.canUpdateSteps(for: detail, userRole: userRole)
                canManageStructure = repository.canManageStepStructure(for: detail, userRole: userRole)
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

    func updateStepDetails(
        homeId: UUID,
        procedureId: UUID,
        stepId: UUID,
        title: String?,
        notes: String?,
        photoChange: StepPhotoChange,
        canEditTitle: Bool,
        userRole: HomeRole,
        using repository: ProcedureRepository?
    ) async {
        guard let repository else { return }
        do {
            try await repository.updateStepDetails(
                homeId: homeId,
                procedureId: procedureId,
                stepId: stepId,
                title: title,
                notes: notes,
                photoChange: photoChange,
                canEditTitle: canEditTitle,
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

    func createStep(
        homeId: UUID,
        procedureId: UUID,
        title: String,
        userRole: HomeRole,
        using repository: ProcedureRepository?
    ) async {
        guard let repository else { return }
        do {
            try await repository.createStep(
                homeId: homeId,
                procedureId: procedureId,
                title: title,
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

    func renameStep(
        homeId: UUID,
        procedureId: UUID,
        stepId: UUID,
        title: String,
        userRole: HomeRole,
        using repository: ProcedureRepository?
    ) async {
        guard let repository else { return }
        do {
            try await repository.renameStep(
                homeId: homeId,
                procedureId: procedureId,
                stepId: stepId,
                title: title,
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

    func deleteStep(
        homeId: UUID,
        procedureId: UUID,
        stepId: UUID,
        userRole: HomeRole,
        using repository: ProcedureRepository?
    ) async {
        guard let repository else { return }
        do {
            try await repository.deleteStep(
                homeId: homeId,
                procedureId: procedureId,
                stepId: stepId,
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

    func moveStep(
        homeId: UUID,
        procedureId: UUID,
        stepId: UUID,
        direction: StepMoveDirection,
        userRole: HomeRole,
        using repository: ProcedureRepository?
    ) async {
        guard let repository else { return }
        do {
            try await repository.moveStep(
                homeId: homeId,
                procedureId: procedureId,
                stepId: stepId,
                direction: direction,
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
            canManageStructure = repository.canManageStepStructure(for: detail, userRole: userRole)
        }
        activity = (try? await repository.fetchProcedureActivity(
            procedureId: procedureId,
            homeId: homeId,
            userRole: userRole
        )) ?? activity
    }
}
