import CryptoKit
import Foundation

// @covers FR-AUTH-01

enum AppleSignInPolicy {
    enum Error: Swift.Error, Equatable {
        case missingIdentityToken
    }

    static func hashedNonce(for rawNonce: String) -> String {
        let digest = SHA256.hash(data: Data(rawNonce.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func identityTokenString(from data: Data?) throws -> String {
        guard let data, !data.isEmpty,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            throw Error.missingIdentityToken
        }
        return token
    }
}
