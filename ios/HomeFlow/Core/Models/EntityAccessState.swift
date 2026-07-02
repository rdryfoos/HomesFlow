import Foundation

// @covers AC-GUEST-02

enum EntityAccessState: Equatable, Sendable {
    case allowed
    case accessDenied
    case notFound
}
