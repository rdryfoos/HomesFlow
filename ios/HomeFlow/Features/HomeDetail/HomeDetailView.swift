import SwiftUI

// @covers FR-HOME-01, FR-USER-02

enum HomeTab: String, CaseIterable, Identifiable {
    case procedures = "Procedures"
    case contacts = "Contacts"
    case documents = "Documents"
    case people = "People"

    var id: String { rawValue }
}

struct HomeDetailView: View {
    let home: HomeSummary
    @Environment(\.appEnvironment) private var appEnvironment
    @State private var selectedTab: HomeTab = .procedures
    @State private var showEditHome = false
    @State private var displayedHome: HomeSummary

    init(home: HomeSummary) {
        self.home = home
        _displayedHome = State(initialValue: home)
    }

    var body: some View {
        VStack(spacing: 0) {
            homeHeader
            Picker("Section", selection: $selectedTab) {
                ForEach(HomeTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditHome = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showEditHome) {
            HomeSetupView(existingHome: displayedHome) { updated in
                displayedHome = updated
            }
            .environment(\.appEnvironment, appEnvironment)
        }
    }

    private var homeHeader: some View {
        HomeHeroCard(home: displayedHome, style: .detail)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .procedures:
            ContentUnavailableView("Procedures", systemImage: "checklist", description: Text("Phase 2"))
        case .contacts:
            ContentUnavailableView("Service Providers", systemImage: "phone", description: Text("Phase 2"))
        case .documents:
            ContentUnavailableView("Documents", systemImage: "doc", description: Text("Phase 3"))
        case .people:
            MembersView(home: displayedHome)
                .environment(\.appEnvironment, appEnvironment)
        }
    }
}
