import Foundation

// @covers AC-HOME-12

/// Shared toolbar add-action contract for Contacts, Files, and People sections.
enum SectionAddAction {
    struct Spec: Equatable, Sendable {
        let section: HomeManageableSection
        let label: String
        let systemImage: String

        var accessibilityLabel: String { label }

        /// AC-HOME-12: plus icon with accessible label naming the action.
        var usesParallelConstruction: Bool {
            systemImage == "plus" && !label.isEmpty && accessibilityLabel == label
        }
    }

    static let contacts = Spec(section: .contacts, label: "Add contact", systemImage: "plus")
    static let files = Spec(section: .files, label: "Add file", systemImage: "plus")
    static let people = Spec(section: .people, label: "Invite member", systemImage: "plus")

    static let permittedSectionSpecs: [Spec] = [contacts, files, people]

    /// Whether the section list should expose an add toolbar action for `role`.
    static func showsAddAction(for section: HomeManageableSection, role: HomeRole) -> Bool {
        let permissions = PermissionService()
        switch section {
        case .contacts:
            return permissions.can(
                .create,
                entity: .serviceProvider(visibility: .manager),
                role: role
            )
        case .files:
            return permissions.can(
                .create,
                entity: .document(visibility: .manager),
                role: role
            )
        case .people:
            return role == .owner
        }
    }
}

enum HomeManageableSection: String, CaseIterable, Sendable {
    case contacts
    case files
    case people
}
