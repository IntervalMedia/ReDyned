import XCTest
@testable import ReDyne

final class FunctionNameImportTests: XCTestCase {
    func testParseAndApplyOverrides() throws {
        let json = """
        {
            "Functions": [
                { "Address": 100, "Name": "UpdatedName" },
                { "Address": 200, "Name": "NewFunction" }
            ]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let entries = try FunctionNameImportService.parse(data: data)
        XCTAssertEqual(entries.count, 2)

        let existing = FunctionModel()
        existing.name = "Original"
        existing.startAddress = 100
        existing.endAddress = 120
        existing.instructionCount = 5

        let updated = FunctionNameImportService.apply(entries: entries, to: [existing])
        let updatedByAddress = Dictionary(uniqueKeysWithValues: updated.map { ($0.startAddress, $0) })

        XCTAssertEqual(updatedByAddress[100]?.name, "UpdatedName")
        XCTAssertEqual(updatedByAddress[200]?.name, "NewFunction")
    }

    func testParseRejectsMissingFunctionsArray() throws {
        let json = "{ \"NotFunctions\": [] }"
        let data = try XCTUnwrap(json.data(using: .utf8))

        XCTAssertThrowsError(try FunctionNameImportService.parse(data: data))
    }
}
