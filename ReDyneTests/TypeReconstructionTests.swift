import XCTest
@testable import ReDyne

final class TypeReconstructionTests: XCTestCase {
    func testFixturesExist() throws {
        let testFileURL = URL(fileURLWithPath: #file)
        let repoRoot = testFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let fixturePath = repoRoot.appendingPathComponent("Tests/Fixtures/sample_objc.placeholder")

        XCTAssertTrue(FileManager.default.fileExists(atPath: fixturePath.path),
                      "Fixture missing: \(fixturePath.path)")
    }
}
