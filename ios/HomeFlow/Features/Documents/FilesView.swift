import SwiftUI
import UniformTypeIdentifiers

// @covers FR-HOME-03, FR-NAV-01, AC-HOME-11, AC-GUEST-01

struct FilesView: View {
    let home: HomeSummary
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appEnvironment) private var appEnvironment
    @StateObject private var viewModel = FilesViewModel()
    @State private var selectedDocumentId: UUID?
    @State private var showUploadSheet = false

    private var userRole: HomeRole {
        home.currentUserRole ?? .guest
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    filesList(useSelection: true)
                } detail: {
                    documentDetailPanel
                }
            } else {
                filesList(useSelection: false)
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.documents.isEmpty {
                ProgressView("Loading files…")
            }
        }
        .task { await reload() }
        .refreshable { await reload() }
        .sheet(isPresented: $showUploadSheet) {
            DocumentUploadSheet { draft, data, fileName in
                Task {
                    await upload(draft: draft, data: data, fileName: fileName)
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
    }

    @ViewBuilder
    private var documentDetailPanel: some View {
        if let documentId = selectedDocumentId ?? viewModel.documents.first?.id,
           let repo = appEnvironment?.documentRepository {
            switch repo.documentAccessState(documentId: documentId, userRole: userRole) {
            case .accessDenied:
                GuestAccessDeniedView(
                    message: "This file is not shared with guest accounts."
                )
            case .notFound:
                ContentUnavailableView(
                    "File not found",
                    systemImage: "doc",
                    description: Text("This file may have been removed.")
                )
            case .allowed:
                if let document = viewModel.documents.first(where: { $0.id == documentId }) {
                    DocumentDetailView(
                        document: document,
                        canManage: viewModel.canManage,
                        shareURL: viewModel.shareURLs[document.id],
                        onOpen: { await loadShareURL(for: document) },
                        onDelete: { deleteDocument(document) }
                    )
                } else {
                    ContentUnavailableView(
                        "Select a file",
                        systemImage: "folder",
                        description: Text("Choose a file from the list.")
                    )
                }
            }
        } else {
            ContentUnavailableView(
                "Select a file",
                systemImage: "folder",
                description: Text("Choose a file from the list.")
            )
        }
    }

    @ViewBuilder
    private func filesList(useSelection: Bool) -> some View {
        Group {
            if viewModel.documents.isEmpty && !viewModel.isLoading {
                List {
                    Section {
                        ContentUnavailableView(
                            "No files yet",
                            systemImage: "folder",
                            description: Text(
                                viewModel.canManage
                                    ? "Upload house documents like manuals, warranties, or insurance."
                                    : "Files shared with you will appear here."
                            )
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            } else if useSelection {
                List(viewModel.documents, selection: $selectedDocumentId) { document in
                    DocumentRow(document: document)
                        .tag(document.id)
                }
            } else {
                List(viewModel.documents) { document in
                    NavigationLink {
                        if appEnvironment?.documentRepository.documentAccessState(
                            documentId: document.id,
                            userRole: userRole
                        ) == .allowed {
                            DocumentDetailView(
                                document: document,
                                canManage: viewModel.canManage,
                                shareURL: viewModel.shareURLs[document.id],
                                onOpen: { await loadShareURL(for: document) },
                                onDelete: { deleteDocument(document) }
                            )
                        } else {
                            GuestAccessDeniedView(
                                message: "This file is not shared with guest accounts."
                            )
                        }
                    } label: {
                        DocumentRow(document: document)
                    }
                }
            }
        }
        .toolbar {
            if viewModel.canManage {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showUploadSheet = true
                    } label: {
                        Label("Upload", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private func reload() async {
        guard let repo = appEnvironment?.documentRepository else { return }
        await viewModel.load(homeId: home.id, userRole: userRole, using: repo)
    }

    private func upload(draft: DocumentDraft, data: Data, fileName: String) async {
        guard let repo = appEnvironment?.documentRepository else { return }
        await viewModel.upload(
            homeId: home.id,
            draft: draft,
            fileData: data,
            fileName: fileName,
            userRole: userRole,
            using: repo
        )
    }

    private func deleteDocument(_ document: DocumentSummary) {
        guard let repo = appEnvironment?.documentRepository else { return }
        Task {
            await viewModel.delete(
                homeId: home.id,
                documentId: document.id,
                userRole: userRole,
                using: repo
            )
        }
    }

    private func loadShareURL(for document: DocumentSummary) async {
        guard let repo = appEnvironment?.documentRepository else { return }
        await viewModel.loadShareURL(
            documentId: document.id,
            userRole: userRole,
            using: repo
        )
    }
}

private struct DocumentRow: View {
    let document: DocumentSummary

    var body: some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(document.title)
                    .font(.headline)
                HStack(spacing: 8) {
                    if let category = document.category {
                        Text(category)
                    }
                    if let ext = document.fileExtension {
                        Text(ext)
                    }
                    Text(document.visibility.displayName)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct DocumentDetailView: View {
    let document: DocumentSummary
    let canManage: Bool
    let shareURL: URL?
    let onOpen: () async -> Void
    let onDelete: () -> Void

    @State private var isLoadingLink = false

    var body: some View {
        List {
            Section {
                LabeledContent("Title", value: document.title)
                if let category = document.category {
                    LabeledContent("Category", value: category)
                }
                LabeledContent("Visibility", value: document.visibility.displayName)
                if let ext = document.fileExtension {
                    LabeledContent("Type", value: ext)
                }
            }

            Section {
                if let shareURL {
                    ShareLink(item: shareURL) {
                        Label("Open / Share", systemImage: "arrow.up.forward.app")
                    }
                } else {
                    Button {
                        Task {
                            isLoadingLink = true
                            await onOpen()
                            isLoadingLink = false
                        }
                    } label: {
                        if isLoadingLink {
                            ProgressView()
                        } else {
                            Label("Prepare download link", systemImage: "link")
                        }
                    }
                }
            }

            if canManage {
                Section {
                    Button("Delete file", role: .destructive, action: onDelete)
                }
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if shareURL == nil {
                await onOpen()
            }
        }
    }
}

private struct DocumentUploadSheet: View {
    let onUpload: (DocumentDraft, Data, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = DocumentDraft()
    @State private var pickedFileName: String?
    @State private var pickedFileData: Data?
    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $draft.title)
                    TextField("Category (optional)", text: $draft.category)
                    Picker("Visibility", selection: $draft.visibility) {
                        ForEach(Visibility.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                }

                Section("File") {
                    Button {
                        showImporter = true
                    } label: {
                        Label(
                            pickedFileName ?? "Choose file",
                            systemImage: "doc.badge.plus"
                        )
                    }
                }
            }
            .navigationTitle("Upload File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Upload") {
                        guard let data = pickedFileData, let name = pickedFileName else { return }
                        onUpload(draft, data, name)
                        dismiss()
                    }
                    .disabled(!draft.isValid || pickedFileData == nil)
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.pdf, .image, .plainText, .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    pickedFileName = url.lastPathComponent
                    pickedFileData = try? Data(contentsOf: url)
                    if draft.title.isEmpty {
                        draft.title = url.deletingPathExtension().lastPathComponent
                    }
                case .failure:
                    break
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

@MainActor
final class FilesViewModel: ObservableObject {
    @Published var documents: [DocumentSummary] = []
    @Published var canManage = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var shareURLs: [UUID: URL] = [:]

    func load(homeId: UUID, userRole: HomeRole, using repository: DocumentRepository) async {
        isLoading = true
        defer { isLoading = false }
        do {
            documents = try await repository.fetchDocuments(homeId: homeId, userRole: userRole)
            canManage = repository.canManageDocuments(userRole: userRole)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func upload(
        homeId: UUID,
        draft: DocumentDraft,
        fileData: Data,
        fileName: String,
        userRole: HomeRole,
        using repository: DocumentRepository
    ) async {
        do {
            try await repository.createDocument(
                homeId: homeId,
                draft: draft,
                fileData: fileData,
                fileName: fileName,
                userRole: userRole
            )
            documents = try await repository.fetchDocuments(homeId: homeId, userRole: userRole)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(
        homeId: UUID,
        documentId: UUID,
        userRole: HomeRole,
        using repository: DocumentRepository
    ) async {
        do {
            try await repository.deleteDocument(
                homeId: homeId,
                documentId: documentId,
                userRole: userRole
            )
            documents = try await repository.fetchDocuments(homeId: homeId, userRole: userRole)
            shareURLs.removeValue(forKey: documentId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadShareURL(
        documentId: UUID,
        userRole: HomeRole,
        using repository: DocumentRepository
    ) async {
        do {
            let url = try await repository.signedURL(for: documentId, userRole: userRole)
            shareURLs[documentId] = url
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
