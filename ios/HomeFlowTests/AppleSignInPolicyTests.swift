import XCTest
@testable import HomeFlow

// @covers FR-AUTH-01

final class AppleSignInPolicyTests: XCTestCase {
    func test_FR_AUTH_01_hashed_nonce_is_stable_sha256_hex() {
        let raw = "test-nonce-value"
        let hashed = AppleSignInPolicy.hashedNonce(for: raw)
        XCTAssertEqual(hashed.count, 64)
        XCTAssertEqual(hashed, AppleSignInPolicy.hashedNonce(for: raw))
        XCTAssertNotEqual(hashed, raw)
    }

    func test_FR_AUTH_01_identity_token_extracted_from_data() throws {
        let token = "eyJhbG.test.token"
        let data = Data(token.utf8)
        XCTAssertEqual(try AppleSignInPolicy.identityTokenString(from: data), token)
    }

    func test_FR_AUTH_01_missing_identity_token_rejected() {
        XCTAssertThrowsError(try AppleSignInPolicy.identityTokenString(from: nil)) { error in
            XCTAssertEqual(error as? AppleSignInPolicy.Error, .missingIdentityToken)
        }
        XCTAssertThrowsError(try AppleSignInPolicy.identityTokenString(from: Data())) { error in
            XCTAssertEqual(error as? AppleSignInPolicy.Error, .missingIdentityToken)
        }
    }
}
