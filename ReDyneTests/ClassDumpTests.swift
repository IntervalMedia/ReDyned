import XCTest
@testable import ReDyne

final class ClassDumpTests: XCTestCase {
    func testFixturesExist() throws {
        // Derive project root deterministically relative to this test file.
        let testFileURL = URL(fileURLWithPath: #file)
        // ReDyneTests directory is expected at repo root level: repoRoot/ReDyneTests/...
        let repoRoot = testFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let fixturePath = repoRoot.appendingPathComponent("Tests/Fixtures/sample_arm64.placeholder")

        XCTAssertTrue(FileManager.default.fileExists(atPath: fixturePath.path),
                      "Fixture missing: \(fixturePath.path)")
    }
}
