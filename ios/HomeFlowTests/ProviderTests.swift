import XCTest
@testable import HomeFlow

// @covers AC-HOME-04, AC-HOME-05, FR-HOME-02

final class ProviderConflictTests: XCTestCase {
    // T055 — AC-HOME-04: a provider edit saved on one device propagates to
    // other members: a clean local cache always accepts the server row, and a
    // newer server edit wins over an older pending local edit.
    func test_AC_HOME_04_provider_edit_propagates() {
        XCTAssertTrue(
            ProviderConflictResolver.shouldApplyServer(
                localPending: false,
                localUpdatedAt: Date(timeIntervalSince1970: 100),
                serverUpdatedAt: Date(timeIntervalSince1970: 50)
            ),
            "Members without local edits always receive propagated changes"
        )
        XCTAssertTrue(
            ProviderConflictResolver.shouldApplyServer(
                localPending: true,
                localUpdatedAt: Date(timeIntervalSince1970: 100),
                serverUpdatedAt: Date(timeIntervalSince1970: 200)
            ),
            "A newer server edit overwrites an older pending local edit"
        )
    }

    func test_AC_HOME_04_local_newer_edit_is_kept() {
        XCTAssertFalse(
            ProviderConflictResolver.shouldApplyServer(
                localPending: true,
                localUpdatedAt: Date(timeIntervalSince1970: 300),
                serverUpdatedAt: Date(timeIntervalSince1970: 200)
            ),
            "A pending local edit newer than the server row is kept for push"
        )
    }

    // T056 — AC-HOME-05: when a provider was deleted on the server while a
    // local edit is pending, the delete wins and the editor is notified.
    func test_AC_HOME_05_delete_wins_over_edit() {
        XCTAssertEqual(
            ProviderConflictResolver.resolveMissingFromServer(
                localPending: true,
                everSynced: true
            ),
            .deleteWinsNotify
        )
    }

    func test_AC_HOME_05_synced_row_removed_silently() {
        XCTAssertEqual(
            ProviderConflictResolver.resolveMissingFromServer(
                localPending: false,
                everSynced: true
            ),
            .removeSilently
        )
    }

    func test_AC_HOME_05_local_only_insert_survives_pull() {
        XCTAssertEqual(
            ProviderConflictResolver.resolveMissingFromServer(
                localPending: true,
                everSynced: false
            ),
            .keepPendingInsert
        )
    }
}

final class ProviderContactLinkTests: XCTestCase {
    // T054 — tapping a phone number dials via a tel: URL.
    func test_phone_number_formats_as_tel_url() {
        XCTAssertEqual(
            makeProvider(phone: "(603) 555-0114").telURL,
            URL(string: "tel:6035550114")
        )
        XCTAssertEqual(
            makeProvider(phone: "+1 603-555-0114").telURL,
            URL(string: "tel:+16035550114")
        )
        XCTAssertNil(makeProvider(phone: nil).telURL)
        XCTAssertNil(makeProvider(phone: "call the office").telURL)
    }

    func test_website_normalizes_to_https_url() {
        XCTAssertEqual(
            makeProvider(website: "example.com").websiteURL,
            URL(string: "https://example.com")
        )
        XCTAssertEqual(
            makeProvider(website: "http://example.com").websiteURL,
            URL(string: "http://example.com")
        )
        XCTAssertNil(makeProvider(website: nil).websiteURL)
    }

    private func makeProvider(
        phone: String? = nil,
        website: String? = nil
    ) -> ServiceProviderSummary {
        ServiceProviderSummary(
            id: UUID(),
            homeId: UUID(),
            companyName: "Granite State Electric",
            serviceType: "electric",
            accountNumber: nil,
            phone: phone,
            website: website,
            hours: nil,
            notes: nil,
            visibility: .manager
        )
    }
}
