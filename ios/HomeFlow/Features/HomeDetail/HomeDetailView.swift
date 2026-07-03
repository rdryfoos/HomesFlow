import SwiftUI

// @covers FR-HOME-01, FR-NAV-01, FR-USER-02, AC-HOME-09, AC-HOME-10, AC-HOME-11, AC-A11Y-02, AC-A11Y-03, NFR-A11Y-01, AC-GUEST-01, AC-USER-05

enum HomeTab: String, CaseIterable, Identifiable {
    case procedures = "Procedures"
    case contacts = "Contacts"
    case files = "Files"
    case people = "People"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .procedures: "checklist"
        case .contacts: "person.crop.circle"
        case .files: "folder"
        case .people: "person.2"
        }
    }

    /// Tabs visible for the signed-in member's role (AC-USER-05, AC-GUEST-01).
    static func visibleTabs(for role: HomeRole) -> [HomeTab] {
        switch role {
        case .guest:
            return [.procedures, .contacts, .files]
        case .owner, .manager:
            return allCases
        }
    }
}

struct HomeDetailView: View {
    let home: HomeSummary
    @Environment(\.appEnvironment) private var appEnvironment
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: HomeTab = .procedures
    @State private var showEditHome = false
    @State private var displayedHome: HomeSummary

    private var userRole: HomeRole {
        displayedHome.currentUserRole ?? .guest
    }

    private var visibleTabs: [HomeTab] {
        HomeTab.visibleTabs(for: userRole)
    }

    private var canEditHome: Bool {
        userRole == .owner
    }

    private var canAccessCommunicationsLog: Bool {
        LogBookAccessPolicy.canRead(userRole: userRole)
    }

    @State private var showCommunicationsLog = false

    init(home: HomeSummary) {
        self.home = home
        _displayedHome = State(initialValue: home)
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .sheet(isPresented: $showEditHome) {
            HomeSetupView(existingHome: displayedHome) { updated in
                displayedHome = updated
            }
            .environment(\.appEnvironment, appEnvironment)
        }
        .sheet(isPresented: $showCommunicationsLog) {
            NavigationStack {
                CommunicationsLogView(home: displayedHome)
                    .environment(\.appEnvironment, appEnvironment)
            }
        }
        .onChange(of: visibleTabs) { _, tabs in
            if !tabs.contains(selectedTab) {
                selectedTab = tabs.first ?? .procedures
            }
        }
    }

    // MARK: - iPhone

    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            HomeHeroCard(home: displayedHome, style: .detail)

                HomeSectionTabBar(
                    selectedTab: $selectedTab,
                    tabs: visibleTabs,
                    axis: .horizontal,
                    reduceMotion: reduceMotion
                )
            .padding(.horizontal)
            .padding(.vertical, 12)

            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if canAccessCommunicationsLog {
                    Button {
                        showCommunicationsLog = true
                    } label: {
                        Label("Communications Log", systemImage: "text.book.closed")
                    }
                    .accessibilityLabel("Communications Log")
                }
                if canEditHome {
                    editHomeButton
                }
            }
        }
    }

    // MARK: - iPad

    private var iPadLayout: some View {
        NavigationSplitView {
            iPadSidebar
                .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 320)
        } detail: {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if canAccessCommunicationsLog {
                            Button {
                                showCommunicationsLog = true
                            } label: {
                                Label("Communications Log", systemImage: "text.book.closed")
                            }
                            .accessibilityLabel("Communications Log")
                        }
                        if canEditHome {
                            editHomeButton
                        }
                    }
                }
        }
    }

    private var iPadSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HomeHeroCard(home: displayedHome, style: .sidebar)
                    .padding(.horizontal)

                Button {
                    dismiss()
                } label: {
                    Label("All Homes", systemImage: "chevron.left")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .padding(.horizontal)
                .accessibilityLabel("All Homes")
                .accessibilityHint("Return to the home list to switch homes")

                HomeSectionTabBar(
                    selectedTab: $selectedTab,
                    tabs: visibleTabs,
                    axis: .vertical,
                    reduceMotion: reduceMotion
                )
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var editHomeButton: some View {
        Button {
            showEditHome = true
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        .accessibilityLabel("Edit home details")
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .procedures:
            if let appEnvironment {
                ProceduresView(home: displayedHome)
                    .environment(\.appEnvironment, appEnvironment)
                    .environmentObject(appEnvironment.procedureRepository)
            }
        case .contacts:
            ContactsView(home: displayedHome)
                .environment(\.appEnvironment, appEnvironment)
        case .files:
            FilesView(home: displayedHome)
        case .people:
            MembersView(home: displayedHome)
                .environment(\.appEnvironment, appEnvironment)
        }
    }
}

// MARK: - Section tabs

private struct HomeSectionTabBar: View {
    @Binding var selectedTab: HomeTab
    let tabs: [HomeTab]
    let axis: Axis
    let reduceMotion: Bool

    var body: some View {
        Group {
            if axis == .horizontal {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tabs) { tab in
                            tabButton(for: tab)
                        }
                    }
                }
            } else {
                VStack(spacing: 4) {
                    ForEach(tabs) { tab in
                        tabButton(for: tab)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func tabButton(for tab: HomeTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            // AC-A11Y-03: no selection animation when Reduce Motion is on.
            withAnimation(AccessibilityBaseline.animation(reduceMotion: reduceMotion)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.body.weight(.medium))
                    .frame(width: 24)
                    .accessibilityHidden(true)

                Text(tab.rawValue)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if axis == .horizontal {
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.horizontal, axis == .horizontal ? 12 : 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: AccessibilityBaseline.minimumTapTarget)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(axis == .horizontal ? Color.accentColor.opacity(0.15) : Color.accentColor.opacity(0.12))
                }
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(AccessibilityBaseline.sectionTabHint(tab.rawValue))
    }
}
