import SwiftUI

// @covers FR-HOME-03, FR-NAV-01, AC-HOME-11

struct FilesView: View {
    let home: HomeSummary
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedPlaceholderId: UUID?

    private let placeholderItems: [FilePlaceholder] = []

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    filesList(useSelection: true)
                } detail: {
                    fileDetail(for: selectedPlaceholderId ?? placeholderItems.first?.id)
                }
            } else {
                filesList(useSelection: false)
            }
        }
    }

    @ViewBuilder
    private func filesList(useSelection: Bool) -> some View {
        if placeholderItems.isEmpty {
            List {
                Section {
                    ContentUnavailableView(
                        "No files yet",
                        systemImage: "folder",
                        description: Text("House documents and files will appear here.")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
        } else if useSelection {
            List(placeholderItems, selection: $selectedPlaceholderId) { item in
                FilePlaceholderRow(item: item)
                    .tag(item.id)
            }
        } else {
            List(placeholderItems) { item in
                FilePlaceholderRow(item: item)
            }
        }
    }

    @ViewBuilder
    private func fileDetail(for id: UUID?) -> some View {
        if id != nil {
            ContentUnavailableView(
                "File preview",
                systemImage: "doc",
                description: Text("File preview will appear here.")
            )
        } else {
            ContentUnavailableView(
                "Select a file",
                systemImage: "folder",
                description: Text("Choose a file from the list.")
            )
        }
    }
}

private struct FilePlaceholder: Identifiable, Hashable {
    let id: UUID
    let name: String
}

private struct FilePlaceholderRow: View {
    let item: FilePlaceholder

    var body: some View {
        Label(item.name, systemImage: "doc")
            .font(.headline)
    }
}
