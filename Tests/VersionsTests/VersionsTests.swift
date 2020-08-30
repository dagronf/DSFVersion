import XCTest
@testable import Versions

final class VersionsTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Versions().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
