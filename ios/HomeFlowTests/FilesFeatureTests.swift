import XCTest
@testable import HomeFlow

// @covers AC-HOME-12, AC-HOME-13, AC-HOME-14

final class FilesFeatureTests: XCTestCase {
    private let permissions = PermissionService()

    // MARK: - AC-HOME-12

    func test_AC_HOME_12_section_add_actions_use_parallel_construction() {
        for spec in SectionAddAction.permittedSectionSpecs {
            XCTAssertTrue(
                spec.usesParallelConstruction,
                "\(spec.section) should use plus icon and matching accessibility label"
            )
        }
    }

    func test_AC_HOME_12_contacts_and_files_add_for_owner_and_manager() {
        for role in [HomeRole.owner, .manager] {
            XCTAssertTrue(
                SectionAddAction.showsAddAction(for: .contacts, role: role),
                "Contacts add should show for \(role)"
            )
            XCTAssertTrue(
                SectionAddAction.showsAddAction(for: .files, role: role),
                "Files add should show for \(role)"
            )
        }
    }

    func test_AC_HOME_12_people_add_owner_only() {
        XCTAssertTrue(SectionAddAction.showsAddAction(for: .people, role: .owner))
        XCTAssertFalse(SectionAddAction.showsAddAction(for: .people, role: .manager))
        XCTAssertFalse(SectionAddAction.showsAddAction(for: .people, role: .guest))
    }

    func test_AC_HOME_12_guest_has_no_section_add_actions() {
        for section in HomeManageableSection.allCases {
            XCTAssertFalse(
                SectionAddAction.showsAddAction(for: section, role: .guest),
                "Guest should not see add action on \(section)"
            )
        }
    }

    func test_AC_HOME_12_matches_repository_manage_flags() {
        XCTAssertEqual(
            SectionAddAction.showsAddAction(for: .files, role: .owner),
            permissions.can(.create, entity: .document(visibility: .manager), role: .owner)
        )
        XCTAssertEqual(
            SectionAddAction.showsAddAction(for: .contacts, role: .manager),
            permissions.can(.create, entity: .serviceProvider(visibility: .manager), role: .manager)
        )
    }

    // MARK: - AC-HOME-13

    func test_AC_HOME_13_preview_icon_maps_by_extension() {
        XCTAssertEqual(DocumentPreviewIcon.symbol(for: "PDF"), "doc.richtext")
        XCTAssertEqual(DocumentPreviewIcon.symbol(for: "jpg"), "photo")
        XCTAssertEqual(DocumentPreviewIcon.symbol(for: "mp4"), "film")
        XCTAssertEqual(DocumentPreviewIcon.symbol(for: "mp3"), "waveform")
        XCTAssertEqual(DocumentPreviewIcon.symbol(for: "txt"), "doc.text")
        XCTAssertEqual(DocumentPreviewIcon.symbol(for: "xyz"), "doc.fill")
    }

    func test_AC_HOME_13_local_file_name_uses_storage_path() {
        let document = DocumentSummary(
            id: UUID(),
            homeId: UUID(),
            title: "Manual",
            category: nil,
            storagePath: "home-id/docs/warranty.pdf",
            visibility: .manager
        )
        XCTAssertEqual(
            DocumentPreviewLoader.localFileName(for: document),
            "warranty.pdf"
        )
    }

    func test_AC_HOME_13_local_file_name_falls_back_to_id_and_extension() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let document = DocumentSummary(
            id: id,
            homeId: UUID(),
            title: "Manual",
            category: nil,
            storagePath: nil,
            visibility: .manager
        )
        XCTAssertEqual(
            DocumentPreviewLoader.localFileName(for: document),
            "\(id.uuidString).dat"
        )
    }

    func test_AC_HOME_13_streams_download_to_preview_directory() async throws {
        let payload = Data("homesflow-preview".utf8)
        let document = DocumentSummary(
            id: UUID(),
            homeId: UUID(),
            title: "Test",
            category: nil,
            storagePath: "home/docs/readme.txt",
            visibility: .manager
        )
        let remote = URL(string: "https://example.test/readme.txt")!

        let localURL = try await DocumentPreviewLoader.prepareLocalFile(
            document: document,
            remoteURL: remote
        ) { _ in
            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try payload.write(to: temp)
            let response = HTTPURLResponse(
                url: remote,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (temp, response)
        }

        defer { try? FileManager.default.removeItem(at: localURL) }

        XCTAssertTrue(localURL.path.contains("document-previews"))
        XCTAssertEqual(localURL.lastPathComponent, "readme.txt")
        XCTAssertEqual(try Data(contentsOf: localURL), payload)
    }

    func test_AC_HOME_13_non_success_download_throws() async {
        let document = DocumentSummary(
            id: UUID(),
            homeId: UUID(),
            title: "Missing",
            category: nil,
            storagePath: "home/docs/missing.pdf",
            visibility: .manager
        )
        let remote = URL(string: "https://example.test/missing.pdf")!

        do {
            _ = try await DocumentPreviewLoader.prepareLocalFile(
                document: document,
                remoteURL: remote
            ) { _ in
                let temp = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                try Data().write(to: temp)
                let response = HTTPURLResponse(
                    url: remote,
                    statusCode: 404,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (temp, response)
            }
            XCTFail("Expected missingFile error")
        } catch DocumentError.missingFile {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - AC-HOME-14

    func test_AC_HOME_14_offers_library_and_file_browser_sources() {
        let sources = DocumentUploadFlow.offeredSources(cameraAvailable: false)
        XCTAssertEqual(sources, [.photoLibrary, .fileBrowser])
    }

    func test_AC_HOME_14_includes_camera_when_available() {
        let sources = DocumentUploadFlow.offeredSources(cameraAvailable: true)
        XCTAssertEqual(sources, [.camera, .photoLibrary, .fileBrowser])
    }

    func test_AC_HOME_14_apply_pick_fills_title_from_file_name() {
        var draft = DocumentDraft()
        let pick = DocumentUploadFlow.applyPick(
            to: &draft,
            data: Data([0x01]),
            fileName: "Insurance Policy.pdf"
        )

        XCTAssertNotNil(pick)
        XCTAssertEqual(draft.title, "Insurance Policy")
        XCTAssertEqual(pick?.fileName, "Insurance Policy.pdf")
    }

    func test_AC_HOME_14_apply_pick_preserves_existing_title() {
        var draft = DocumentDraft(title: "Custom title")
        _ = DocumentUploadFlow.applyPick(
            to: &draft,
            data: Data([0x01]),
            fileName: "scan.jpg"
        )

        XCTAssertEqual(draft.title, "Custom title")
    }

    func test_AC_HOME_14_upload_requires_valid_draft_and_file_data() {
        var emptyDraft = DocumentDraft()
        XCTAssertFalse(emptyDraft.isValid)

        var draft = DocumentDraft(title: "Manual")
        XCTAssertTrue(draft.isValid)
        XCTAssertNil(DocumentUploadFlow.applyPick(to: &draft, data: nil, fileName: "manual.pdf"))
        XCTAssertNil(DocumentUploadFlow.applyPick(to: &draft, data: Data(), fileName: "manual.pdf"))
    }

    func test_AC_HOME_14_camera_file_name_is_dated_jpeg() {
        let date = Date(timeIntervalSince1970: 1_735_689_600) // 2025-01-01 UTC
        XCTAssertEqual(
            DocumentUploadFlow.cameraFileName(date: date),
            "Photo 2025-01-01.jpg"
        )
    }
}
