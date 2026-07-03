import SwiftUI

// @covers FR-HOME-02, FR-NAV-01, AC-HOME-04, AC-HOME-12

struct ContactsView: View {
    let home: HomeSummary
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appEnvironment) private var appEnvironment
    @StateObject private var viewModel = ContactsViewModel()
    @State private var selectedProviderId: UUID?
    @State private var searchText = ""
    @State private var formMode: ProviderFormMode?

    private var userRole: HomeRole {
        home.currentUserRole ?? .guest
    }

    private var filteredProviders: [ServiceProviderSummary] {
        guard !searchText.isEmpty else { return viewModel.providers }
        return viewModel.providers.filter {
            $0.companyName.localizedCaseInsensitiveContains(searchText)
                || $0.serviceType.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    contactsList(useSelection: true)
                } detail: {
                    providerDetailPanel
                }
            } else {
                contactsList(useSelection: false)
            }
        }
        .task { await reload() }
        .refreshable { await reload() }
        .sheet(item: $formMode) { mode in
            ProviderFormView(mode: mode) { draft in
                Task {
                    await save(mode: mode, draft: draft)
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
    private var providerDetailPanel: some View {
        if let providerId = selectedProviderId ?? filteredProviders.first?.id,
           let repo = appEnvironment?.providerRepository {
            switch repo.providerAccessState(providerId: providerId, userRole: userRole) {
            case .accessDenied:
                GuestAccessDeniedView(
                    message: "This contact is not shared with guest accounts."
                )
            case .notFound:
                ContentUnavailableView(
                    "Contact not found",
                    systemImage: "person.crop.circle",
                    description: Text("This contact may have been removed.")
                )
            case .allowed:
                if let provider = filteredProviders.first(where: { $0.id == providerId }) {
                    ProviderDetailView(
                        provider: provider,
                        canEdit: viewModel.canManage,
                        onEdit: { formMode = .edit(provider) },
                        onDelete: { deleteProvider(provider) }
                    )
                } else {
                    ContentUnavailableView(
                        "Select a contact",
                        systemImage: "person.crop.circle",
                        description: Text("Choose a service provider from the list.")
                    )
                }
            }
        } else {
            ContentUnavailableView(
                "Select a contact",
                systemImage: "person.crop.circle",
                description: Text("Choose a service provider from the list.")
            )
        }
    }

    @ViewBuilder
    private func contactsList(useSelection: Bool) -> some View {
        Group {
            if viewModel.providers.isEmpty && !viewModel.isLoading {
                List {
                    Section {
                        ContentUnavailableView(
                            "No contacts yet",
                            systemImage: "person.crop.circle",
                            description: Text(
                                viewModel.canManage
                                    ? "Add service providers like electric, propane, or lawn care."
                                    : "Service providers for this home will appear here."
                            )
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            } else if useSelection {
                List(filteredProviders, selection: $selectedProviderId) { provider in
                    ProviderRow(provider: provider)
                        .tag(provider.id)
                }
                .searchable(text: $searchText, prompt: "Search contacts")
            } else {
                List(filteredProviders) { provider in
                    NavigationLink {
                        ProviderDetailView(
                            provider: provider,
                            canEdit: viewModel.canManage,
                            onEdit: { formMode = .edit(provider) },
                            onDelete: { deleteProvider(provider) }
                        )
                    } label: {
                        ProviderRow(provider: provider)
                    }
                }
                .searchable(text: $searchText, prompt: "Search contacts")
            }
        }
        .toolbar {
            if viewModel.canManage {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        formMode = .create
                    } label: {
                        Label(SectionAddAction.contacts.label, systemImage: SectionAddAction.contacts.systemImage)
                    }
                    .accessibilityLabel(SectionAddAction.contacts.accessibilityLabel)
                }
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.providers.isEmpty {
                ProgressView("Loading…")
            }
        }
    }

    private func reload() async {
        guard let repo = appEnvironment?.providerRepository else { return }
        await viewModel.load(homeId: home.id, userRole: userRole, using: repo)
    }

    private func save(mode: ProviderFormMode, draft: ServiceProviderDraft) async {
        guard let repo = appEnvironment?.providerRepository else { return }
        switch mode {
        case .create:
            await viewModel.create(homeId: home.id, draft: draft, userRole: userRole, using: repo)
        case .edit(let provider):
            await viewModel.update(
                homeId: home.id,
                providerId: provider.id,
                draft: draft,
                userRole: userRole,
                using: repo
            )
        }
    }

    private func deleteProvider(_ provider: ServiceProviderSummary) {
        Task {
            guard let repo = appEnvironment?.providerRepository else { return }
            if selectedProviderId == provider.id {
                selectedProviderId = nil
            }
            await viewModel.delete(
                homeId: home.id,
                providerId: provider.id,
                userRole: userRole,
                using: repo
            )
        }
    }
}

// MARK: - Row

private struct ProviderRow: View {
    let provider: ServiceProviderSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(provider.companyName)
                .font(.headline)
            Text(provider.serviceType.capitalized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Detail

private struct ProviderDetailView: View {
    let provider: ServiceProviderSummary
    let canEdit: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var confirmingDelete = false

    var body: some View {
        List {
            Section {
                LabeledContent("Type", value: provider.serviceType.capitalized)
                if let accountNumber = provider.accountNumber {
                    LabeledContent("Account #", value: accountNumber)
                }
                if let hours = provider.hours {
                    LabeledContent("Hours", value: hours)
                }
            }

            if provider.phone != nil || provider.websiteURL != nil {
                Section("Reach out") {
                    // Tap phone → tel: link (T054, FR-HOME-02)
                    if let phone = provider.phone {
                        if let telURL = provider.telURL {
                            Button {
                                openURL(telURL)
                            } label: {
                                Label(phone, systemImage: "phone.fill")
                            }
                            .accessibilityLabel("Call \(provider.companyName) at \(phone)")
                        } else {
                            LabeledContent("Phone", value: phone)
                        }
                    }
                    if let websiteURL = provider.websiteURL {
                        Link(destination: websiteURL) {
                            Label(provider.website ?? "Website", systemImage: "globe")
                        }
                    }
                }
            }

            if let notes = provider.notes {
                Section("Notes") {
                    Text(notes)
                        .font(.subheadline)
                }
            }

            if canEdit {
                Section {
                    Button("Delete Contact", role: .destructive) {
                        confirmingDelete = true
                    }
                }
            }
        }
        .navigationTitle(provider.companyName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit", action: onEdit)
                }
            }
        }
        .confirmationDialog(
            "Delete \(provider.companyName)?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Contact", role: .destructive, action: onDelete)
        } message: {
            Text("This removes the contact for everyone in this home.")
        }
    }
}

// MARK: - Create/edit form (T052, AC-HOME-04)

enum ProviderFormMode: Identifiable {
    case create
    case edit(ServiceProviderSummary)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let provider): provider.id.uuidString
        }
    }
}

private struct ProviderFormView: View {
    let mode: ProviderFormMode
    let onSave: (ServiceProviderDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: ServiceProviderDraft

    init(mode: ProviderFormMode, onSave: @escaping (ServiceProviderDraft) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .create:
            _draft = State(initialValue: ServiceProviderDraft())
        case .edit(let provider):
            _draft = State(initialValue: ServiceProviderDraft(from: provider))
        }
    }

    private var title: String {
        switch mode {
        case .create: "New Contact"
        case .edit: "Edit Contact"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Company") {
                    TextField("Company name", text: $draft.companyName)
                        .textInputAutocapitalization(.words)
                    TextField("Service type (electric, propane…)", text: $draft.serviceType)
                        .textInputAutocapitalization(.never)
                    TextField("Account number", text: $draft.accountNumber)
                }
                Section("Contact") {
                    TextField("Phone", text: $draft.phone)
                        .keyboardType(.phonePad)
                    TextField("Website", text: $draft.website)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Hours (e.g. Mon–Fri 8–5)", text: $draft.hours)
                }
                Section("Notes") {
                    TextEditor(text: $draft.notes)
                        .frame(minHeight: 100)
                }
                Section {
                    Picker("Visible to", selection: $draft.visibility) {
                        ForEach(Visibility.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                } footer: {
                    Text("Guests only see contacts marked visible to everyone.")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
    }
}

// MARK: - View model

@MainActor
final class ContactsViewModel: ObservableObject {
    @Published var providers: [ServiceProviderSummary] = []
    @Published var canManage = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(homeId: UUID, userRole: HomeRole, using repository: ServiceProviderRepository) async {
        isLoading = true
        defer { isLoading = false }
        do {
            providers = try await repository.fetchProviders(homeId: homeId, userRole: userRole)
            canManage = repository.canManageProviders(userRole: userRole)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(
        homeId: UUID,
        draft: ServiceProviderDraft,
        userRole: HomeRole,
        using repository: ServiceProviderRepository
    ) async {
        do {
            try await repository.createProvider(homeId: homeId, draft: draft, userRole: userRole)
            await load(homeId: homeId, userRole: userRole, using: repository)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(
        homeId: UUID,
        providerId: UUID,
        draft: ServiceProviderDraft,
        userRole: HomeRole,
        using repository: ServiceProviderRepository
    ) async {
        do {
            try await repository.updateProvider(
                homeId: homeId,
                providerId: providerId,
                draft: draft,
                userRole: userRole
            )
            await load(homeId: homeId, userRole: userRole, using: repository)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(
        homeId: UUID,
        providerId: UUID,
        userRole: HomeRole,
        using repository: ServiceProviderRepository
    ) async {
        do {
            try await repository.deleteProvider(
                homeId: homeId,
                providerId: providerId,
                userRole: userRole
            )
            await load(homeId: homeId, userRole: userRole, using: repository)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
