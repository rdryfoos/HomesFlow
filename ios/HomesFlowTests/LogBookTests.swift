import XCTest
@testable import HomesFlow

// @covers AC-LOG-01, AC-LOG-02, AC-LOG-03, AC-LOG-04, AC-LOG-05, AC-LOG-06, FR-LOG-02

final class LogBookTests: XCTestCase {
    private let permissions = PermissionService()

    func test_AC_LOG_01_household_entry_appears_in_log() {
        let entry = LogBookEntrySummary(
            id: UUID(),
            homeId: UUID(),
            procedureId: nil,
            authorId: UUID(),
            authorLabel: "Owner",
            body: "Plumber scheduled for Tuesday.",
            createdAt: Date(timeIntervalSince1970: 100),
            receivedAt: Date(timeIntervalSince1970: 200),
            editedAt: nil,
            procedureTitle: nil
        )

        XCTAssertNil(entry.procedureId)
        XCTAssertEqual(entry.scopeLabel, "Household")
        XCTAssertTrue(LogBookScopeFilter.household.matches(procedureId: entry.procedureId))
    }

    func test_AC_LOG_02_procedure_entry_attached_and_in_log() {
        let procedureId = UUID()
        let entry = LogBookEntrySummary(
            id: UUID(),
            homeId: UUID(),
            procedureId: procedureId,
            authorId: UUID(),
            authorLabel: "Manager",
            body: "Winterizing started early.",
            createdAt: Date(timeIntervalSince1970: 300),
            receivedAt: Date(timeIntervalSince1970: 400),
            editedAt: nil,
            procedureTitle: "Winterize"
        )

        XCTAssertEqual(entry.procedureId, procedureId)
        XCTAssertEqual(entry.scopeLabel, "Winterize")
        XCTAssertTrue(LogBookScopeFilter.procedure.matches(procedureId: entry.procedureId))

        let unified = LogBookEntryOrganizer.chronological([entry, householdEntry(at: 100)])
        XCTAssertEqual(unified.first?.procedureId, procedureId)
    }

    func test_AC_LOG_03_offline_entry_syncs_append_only() {
        XCTAssertEqual(EntityType.logBookEntry.rawValue, "log_book_entries")
        XCTAssertTrue(permissions.can(.create, entity: .logBook, role: .owner))
        // Append-only: no delete operation expected in conflict semantics.
        XCTAssertFalse(permissions.can(.delete, entity: .logBook, role: .owner))
    }

    func test_AC_LOG_04_edit_only_within_grace_window() {
        let received = Date(timeIntervalSince1970: 1_000)
        let inside = received.addingTimeInterval(5 * 60)
        let outside = received.addingTimeInterval(11 * 60)

        XCTAssertTrue(
            LogBookGraceWindowPolicy.canEdit(isAuthor: true, receivedAt: received, now: inside)
        )
        XCTAssertFalse(
            LogBookGraceWindowPolicy.canEdit(isAuthor: true, receivedAt: received, now: outside)
        )
        XCTAssertTrue(
            LogBookGraceWindowPolicy.canEdit(isAuthor: true, receivedAt: nil)
        )
        XCTAssertFalse(
            LogBookGraceWindowPolicy.canEdit(isAuthor: false, receivedAt: received, now: inside)
        )
    }

    func test_AC_LOG_05_unified_log_chronological_and_filterable() {
        let household = householdEntry(at: 100)
        let procedure = LogBookEntrySummary(
            id: UUID(),
            homeId: UUID(),
            procedureId: UUID(),
            authorId: UUID(),
            authorLabel: "Manager",
            body: "Procedure note",
            createdAt: Date(timeIntervalSince1970: 500),
            receivedAt: nil,
            editedAt: nil,
            procedureTitle: "Arrival"
        )

        let all = LogBookEntryOrganizer.chronological([household, procedure])
        XCTAssertEqual(all.map(\.createdAt), [
            Date(timeIntervalSince1970: 500),
            Date(timeIntervalSince1970: 100)
        ])

        let householdOnly = LogBookEntryOrganizer.filtered(all, scope: .household)
        XCTAssertEqual(householdOnly.count, 1)
        XCTAssertNil(householdOnly.first?.procedureId)

        let procedureOnly = LogBookEntryOrganizer.filtered(all, scope: .procedure)
        XCTAssertEqual(procedureOnly.count, 1)
        XCTAssertNotNil(procedureOnly.first?.procedureId)
    }

    func test_AC_LOG_06_guest_denied_log_access() {
        XCTAssertFalse(permissions.can(.read, entity: .logBook, role: .guest))
        XCTAssertFalse(permissions.can(.create, entity: .logBook, role: .guest))
        XCTAssertFalse(LogBookAccessPolicy.canRead(userRole: .guest))
        XCTAssertTrue(LogBookAccessPolicy.canRead(userRole: .owner))
        XCTAssertTrue(LogBookAccessPolicy.canRead(userRole: .manager))
    }

    private func householdEntry(at timestamp: TimeInterval) -> LogBookEntrySummary {
        LogBookEntrySummary(
            id: UUID(),
            homeId: UUID(),
            procedureId: nil,
            authorId: UUID(),
            authorLabel: "Owner",
            body: "Household note",
            createdAt: Date(timeIntervalSince1970: timestamp),
            receivedAt: nil,
            editedAt: nil,
            procedureTitle: nil
        )
    }
}
