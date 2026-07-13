import XCTest
@testable import HomesFlow

// @covers AC-HOME-06, AC-HOME-07, AC-HOME-08

final class HomePhotoTests: XCTestCase {

    // MARK: - AC-HOME-06 (T024a)

    func test_AC_HOME_06_upload_resizes_before_storage() throws {
        let original = Self.solidImage(width: 4000, height: 3000)
        let originalData = try XCTUnwrap(original.pngData())

        let jpeg = try HomePhotoProcessor.jpegData(from: originalData, maxPixelSize: 1280)
        let uploaded = try XCTUnwrap(UIImage(data: jpeg))

        let longest = max(uploaded.size.width, uploaded.size.height) * uploaded.scale
        XCTAssertLessThanOrEqual(longest, 1280, "Upload must be bounded to the max pixel dimension")
        XCTAssertLessThan(jpeg.count, originalData.count, "Optimized JPEG should be smaller than the original")

        // JPEG magic bytes — confirms Storage receives a JPEG, not the raw camera format.
        XCTAssertEqual(Array(jpeg.prefix(2)), [0xFF, 0xD8])
    }

    func test_AC_HOME_06_small_image_not_upscaled() throws {
        let original = Self.solidImage(width: 800, height: 600)
        let resized = try XCTUnwrap(HomePhotoProcessor.resizedImage(original, maxPixelSize: 1280))

        XCTAssertEqual(resized.size.width, original.size.width)
        XCTAssertEqual(resized.size.height, original.size.height)
    }

    func test_AC_HOME_06_invalid_image_data_rejected() {
        XCTAssertThrowsError(
            try HomePhotoProcessor.jpegData(from: Data("not an image".utf8), maxPixelSize: 1280)
        ) { error in
            guard case HomePhotoError.invalidImage = error else {
                return XCTFail("Expected invalidImage, got \(error)")
            }
        }
    }

    // MARK: - AC-HOME-07 (T024b)

    @MainActor
    func test_AC_HOME_07_hero_renders_from_local_cache() throws {
        let directoryName = "HomePhotosTests-\(UUID().uuidString)"
        defer { Self.removeCacheDirectory(named: directoryName) }

        let storagePath = "home-1/hero.jpg"
        let jpeg = try XCTUnwrap(Self.solidImage(width: 64, height: 64).jpegData(compressionQuality: 0.9))

        let cache = HomePhotoCache(directoryName: directoryName)
        XCTAssertNil(cache.image(for: storagePath), "Cache should miss before store")

        try cache.store(jpeg, for: storagePath)
        XCTAssertNotNil(cache.image(for: storagePath), "Cache should hit after store")

        // Fresh instance = empty memory cache; a hit proves the disk layer
        // serves the hero without re-downloading from Storage.
        let rehydrated = HomePhotoCache(directoryName: directoryName)
        XCTAssertNotNil(rehydrated.image(for: storagePath), "Disk cache should survive relaunch")
    }

    @MainActor
    func test_AC_HOME_07_removed_photo_no_longer_cached() throws {
        let directoryName = "HomePhotosTests-\(UUID().uuidString)"
        defer { Self.removeCacheDirectory(named: directoryName) }

        let storagePath = "home-1/hero.jpg"
        let jpeg = try XCTUnwrap(Self.solidImage(width: 32, height: 32).jpegData(compressionQuality: 0.9))

        let cache = HomePhotoCache(directoryName: directoryName)
        try cache.store(jpeg, for: storagePath)
        cache.remove(for: storagePath)

        XCTAssertNil(cache.image(for: storagePath))
        XCTAssertNil(HomePhotoCache(directoryName: directoryName).image(for: storagePath))
    }

    // MARK: - AC-HOME-08 (T024c)

    func test_AC_HOME_08_photo_blocked_until_home_synced() {
        // Offline + photo pending → blocked with actionable offline guidance.
        XCTAssertThrowsError(
            try HomePhotoSyncGate.preSync(isConnected: false, requiredForPhoto: true)
        ) { error in
            guard case HomeSyncError.offline = error else {
                return XCTFail("Expected offline, got \(error)")
            }
        }

        // Synced check failed after sync ran → blocked with sync-first guidance.
        XCTAssertThrowsError(
            try HomePhotoSyncGate.postSync(isHomeSynced: false)
        ) { error in
            guard case HomeSyncError.notSynced = error else {
                return XCTFail("Expected notSynced, got \(error)")
            }
        }
    }

    func test_AC_HOME_08_offline_edit_without_photo_defers_sync() throws {
        XCTAssertEqual(
            try HomePhotoSyncGate.preSync(isConnected: false, requiredForPhoto: false),
            .deferSync
        )
    }

    func test_AC_HOME_08_connected_upload_runs_sync_then_passes_when_synced() throws {
        XCTAssertEqual(
            try HomePhotoSyncGate.preSync(isConnected: true, requiredForPhoto: true),
            .runSync
        )
        XCTAssertNoThrow(try HomePhotoSyncGate.postSync(isHomeSynced: true))
    }

    func test_AC_HOME_08_blocked_errors_carry_actionable_guidance() {
        XCTAssertNotNil(HomeSyncError.offline.errorDescription)
        XCTAssertNotNil(HomeSyncError.notSynced.errorDescription)
    }

    // MARK: - Helpers

    private static func solidImage(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: format
        ).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private static func removeCacheDirectory(named directoryName: String) {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        try? FileManager.default.removeItem(at: base.appendingPathComponent(directoryName, isDirectory: true))
    }
}
