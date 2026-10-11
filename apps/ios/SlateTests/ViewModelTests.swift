import XCTest
@testable import Slate

@MainActor
final class ViewModelTests: XCTestCase {
    func testAuthenticationValidatesBeforeContactingServer() {
        XCTAssertNotNil(AuthenticationViewModel.validation(email: "invalid", password: "SlateDemo2026!", displayName: nil))
        XCTAssertNotNil(AuthenticationViewModel.validation(email: "alex@example.test", password: "short", displayName: nil))
        XCTAssertNotNil(AuthenticationViewModel.validation(email: "alex@example.test", password: "SlateDemo2026!", displayName: ""))
        XCTAssertNil(AuthenticationViewModel.validation(email: "demo@slate.local", password: "SlateDemo2026!", displayName: nil))
    }
}
