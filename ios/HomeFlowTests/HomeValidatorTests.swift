import XCTest
@testable import HomeFlow

final class HomeValidatorTests: XCTestCase {
    func test_AC_HOME_01_valid_home_passes_validation() {
        let result = HomeValidator.validate(name: "Rockport Cottage", streetAddress: "14 Granite Cove Rd")
        XCTAssertTrue(result.isSuccess)
    }

    func test_AC_HOME_02_empty_name_rejected() {
        let result = HomeValidator.validate(name: "  ", streetAddress: "14 Granite Cove Rd")
        guard case .failure(.nameRequired) = result else {
            return XCTFail("Expected nameRequired, got \(result)")
        }
    }

    func test_AC_HOME_02_empty_address_rejected() {
        let result = HomeValidator.validate(name: "Rockport Cottage", streetAddress: "")
        guard case .failure(.addressRequired) = result else {
            return XCTFail("Expected addressRequired, got \(result)")
        }
    }
}

private extension Result where Success == Void, Failure == HomeValidationError {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
