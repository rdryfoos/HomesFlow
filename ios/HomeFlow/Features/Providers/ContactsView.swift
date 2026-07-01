import SwiftUI

// @covers FR-HOME-02, FR-NAV-01

struct ContactsView: View {
    let home: HomeSummary
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedPlaceholderId: UUID?

    private let placeholderItems: [ContactPlaceholder] = []

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    contactsList(useSelection: true)
                } detail: {
                    contactDetail(for: selectedPlaceholderId ?? placeholderItems.first?.id)
                }
            } else {
                contactsList(useSelection: false)
            }
        }
    }

    @ViewBuilder
    private func contactsList(useSelection: Bool) -> some View {
        if placeholderItems.isEmpty {
            List {
                Section {
                    ContentUnavailableView(
                        "No contacts yet",
                        systemImage: "person.crop.circle",
                        description: Text("Service providers for this home will appear here.")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
        } else if useSelection {
            List(placeholderItems, selection: $selectedPlaceholderId) { item in
                ContactPlaceholderRow(item: item)
                    .tag(item.id)
            }
        } else {
            List(placeholderItems) { item in
                ContactPlaceholderRow(item: item)
            }
        }
    }

    @ViewBuilder
    private func contactDetail(for id: UUID?) -> some View {
        if id != nil {
            ContentUnavailableView(
                "Contact details",
                systemImage: "person.crop.circle",
                description: Text("Contact details will appear here.")
            )
        } else {
            ContentUnavailableView(
                "Select a contact",
                systemImage: "person.crop.circle",
                description: Text("Choose a service provider from the list.")
            )
        }
    }
}

private struct ContactPlaceholder: Identifiable, Hashable {
    let id: UUID
    let name: String
}

private struct ContactPlaceholderRow: View {
    let item: ContactPlaceholder

    var body: some View {
        Text(item.name)
            .font(.headline)
    }
}
