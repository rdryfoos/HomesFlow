import SwiftUI

// @covers FR-LOG-02, AC-LOG-01, AC-LOG-02, AC-LOG-05, AC-LOG-06

struct CommunicationsLogView: View {
    let home: HomeSummary
    var initialScope: LogBookScopeFilter = .all
    var procedureId: UUID?
    var procedureTitle: String?

    @Environment(\.appEnvironment) private var appEnvironment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CommunicationsLogViewModel()
    @State private var scopeFilter: LogBookScopeFilter
    @State private var editorMode: LogEntryEditorMode?

    private var userRole: HomeRole {
        home.currentUserRole ?? .guest
    }

    init(
        home: HomeSummary,
        initialScope: LogBookScopeFilter = .all,
        procedureId: UUID? = nil,
        procedureTitle: String? = nil
    ) {
        self.home = home
        self.initialScope = initialScope
        self.procedureId = procedureId
        self.procedureTitle = procedureTitle
        _scopeFilter = State(initialValue: initialScope)
    }

    var body: some View {
        Group {
            if !viewModel.canAccess {
                GuestAccessDeniedView(
                    title: "Communications Log unavailable",
                    message: "Guest accounts cannot view the Communications Log."
                )
            } else {
                logContent
            }
        }
        .navigationTitle("Communications Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            if viewModel.canAccess {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorMode = .create
                    } label: {
                        Label("Add entry", systemImage: "square.and.pencil")
                    }
                    .accessibilityLabel("Add log entry")
                }
            }
        }
        .sheet(item: $editorMode) { mode in
            LogEntryEditorSheet(mode: mode) { body in
                Task {
                    switch mode {
                    case .create:
                        await viewModel.create(
                            homeId: home.id,
                            procedureId: procedureId,
                            procedureTitle: procedureTitle,
                            body: body,
                            userRole: userRole,
                            using: appEnvironment?.logBookRepository
                        )
                    case .edit(let entry):
                        await viewModel.update(
                            homeId: home.id,
                            entryId: entry.id,
                            body: body,
                            userRole: userRole,
                            using: appEnvironment?.logBookRepository
                        )
                    }
                }
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
        .task { await reload() }
        .refreshable { await reload() }
        .onAppear {
            viewModel.canAccess = LogBookAccessPolicy.canRead(userRole: userRole)
        }
    }

    @ViewBuilder
    private var logContent: some View {
        VStack(spacing: 0) {
            if procedureId == nil {
                Picker("Scope", selection: $scopeFilter) {
                    ForEach(LogBookScopeFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
            }

            if viewModel.entries.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No entries yet",
                    systemImage: "text.book.closed",
                    description: Text("Record notes about this home or a procedure for other owners and managers.")
                )
            } else {
                List(viewModel.entries) { entry in
                    LogBookEntryRow(
                        entry: entry,
                        currentUserId: appEnvironment?.auth.session?.user.id,
                        onEdit: {
                            editorMode = .edit(entry)
                        }
                    )
                }
                .listStyle(.plain)
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.entries.isEmpty {
                ProgressView("Loading…")
            }
        }
        .onChange(of: scopeFilter) { _, _ in
            Task { await reload() }
        }
    }

    private func reload() async {
        guard let repo = appEnvironment?.logBookRepository else { return }
        await viewModel.load(
            homeId: home.id,
            userRole: userRole,
            scope: scopeFilter,
            procedureId: procedureId,
            using: repo
        )
    }
}

enum LogEntryEditorMode: Identifiable {
    case create
    case edit(LogBookEntrySummary)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let entry): entry.id.uuidString
        }
    }
}

private struct LogBookEntryRow: View {
    let entry: LogBookEntrySummary
    let currentUserId: UUID?
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.authorLabel)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(entry.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(entry.scopeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.body)
                .font(.body)
            if entry.editedAt != nil {
                Text("Edited")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if LogBookGraceWindowPolicy.canEdit(
                isAuthor: currentUserId == entry.authorId,
                receivedAt: entry.receivedAt
            ) {
                Button("Edit", action: onEdit)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
final class CommunicationsLogViewModel: ObservableObject {
    @Published var entries: [LogBookEntrySummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var canAccess = false

    func load(
        homeId: UUID,
        userRole: HomeRole,
        scope: LogBookScopeFilter,
        procedureId: UUID?,
        using repository: LogBookRepository
    ) async {
        isLoading = true
        defer { isLoading = false }
        do {
            entries = try await repository.fetchEntries(
                homeId: homeId,
                userRole: userRole,
                scope: scope,
                procedureId: procedureId
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(
        homeId: UUID,
        procedureId: UUID?,
        procedureTitle: String?,
        body: String,
        userRole: HomeRole,
        using repository: LogBookRepository?
    ) async {
        guard let repository else { return }
        do {
            _ = try await repository.createEntry(
                homeId: homeId,
                procedureId: procedureId,
                procedureTitle: procedureTitle,
                body: body,
                userRole: userRole
            )
            entries = try await repository.fetchEntries(
                homeId: homeId,
                userRole: userRole,
                scope: procedureId == nil ? .all : .procedure,
                procedureId: procedureId
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(
        homeId: UUID,
        entryId: UUID,
        body: String,
        userRole: HomeRole,
        using repository: LogBookRepository?
    ) async {
        guard let repository else { return }
        do {
            try await repository.updateEntry(
                homeId: homeId,
                entryId: entryId,
                body: body,
                userRole: userRole
            )
            entries = try await repository.fetchEntries(
                homeId: homeId,
                userRole: userRole
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum LogBookAccessPolicy {
    static func canRead(userRole: HomeRole) -> Bool {
        PermissionService().can(.read, entity: .logBook, role: userRole)
    }
}
