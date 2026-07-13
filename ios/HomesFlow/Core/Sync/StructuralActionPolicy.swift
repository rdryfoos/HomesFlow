import Foundation

// @covers AC-SYNC-07, NFR-OFFL-01

/// AC-SYNC-07: structural actions (step/procedure/provider CRUD, membership
/// changes) require connectivity. Step status, home fields, and notes remain
/// offline-capable.
enum StructuralActionPolicy {

    enum Context: Equatable, Sendable {
        case general
        case steps
        case contacts
        case members
    }

    static func assertConnectivity(isConnected: Bool, context: Context = .general) throws {
        guard isConnected else {
            throw StructuralActionError.requiresConnectivity(context: context)
        }
    }

    static func canPerformStructuralActions(isConnected: Bool) -> Bool {
        isConnected
    }

    static func offlineMessage(for context: Context) -> String {
        switch context {
        case .general:
            "Connect to the internet before making this change."
        case .steps:
            "Connect to the internet to add, edit, reorder, or delete steps."
        case .contacts:
            "Connect to the internet to add, edit, or delete contacts."
        case .members:
            "Connect to the internet to manage members."
        }
    }
}

enum StructuralActionError: LocalizedError, Equatable {
    case requiresConnectivity(context: StructuralActionPolicy.Context)

    var errorDescription: String? {
        switch self {
        case .requiresConnectivity(let context):
            StructuralActionPolicy.offlineMessage(for: context)
        }
    }
}
