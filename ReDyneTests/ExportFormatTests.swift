import XCTest
@testable import ReDyne

final class ExportFormatTests: XCTestCase {
    func testExportIncludesClassDumpAndTypeReconstruction() throws {
        let output = makeOutputWithTypeData()

        guard let textData = ExportService.export(output, format: .text),
              let text = String(data: textData, encoding: .utf8) else {
            XCTFail("Expected text export")
            return
        }

        XCTAssertTrue(text.contains("CLASS DUMP"), "Text export should include class dump section")
        XCTAssertTrue(text.contains("@interface SampleClass"), "Text export should include class dump header content")
        XCTAssertTrue(text.contains("TYPE RECONSTRUCTION"), "Text export should include type reconstruction section")
        XCTAssertTrue(text.contains("SampleType"), "Text export should include reconstructed types")

        guard let jsonData = ExportService.export(output, format: .json) else {
            XCTFail("Expected JSON export")
            return
        }

        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
        guard let json = jsonObject as? [String: Any] else {
            XCTFail("Expected JSON dictionary")
            return
        }

        let classDump = json["class_dump"] as? [String: Any]
        XCTAssertEqual(classDump?["header"] as? String, output.classDumpHeader)

        let typeReconstruction = json["type_reconstruction"] as? [String: Any]
        let types = typeReconstruction?["types"] as? [[String: Any]]
        XCTAssertEqual(types?.first?["name"] as? String, "SampleType")

        let stats = json["statistics"] as? [String: Any]
        XCTAssertEqual(stats?["total_reconstructed_types"] as? UInt, output.totalReconstructedTypes)
    }

    private func makeOutputWithTypeData() -> DecompiledOutput {
        let output = DecompiledOutput()
        output.fileName = "sample.bin"
        output.filePath = "/tmp/sample.bin"
        output.fileSize = 1024

        let header = MachOHeaderModel()
        header.cpuType = "ARM64"
        header.fileType = "MH_EXECUTE"
        header.is64Bit = true
        header.ncmds = 1
        header.flags = 0
        header.isEncrypted = false
        output.header = header

        output.segments = []
        output.sections = []
        output.symbols = []
        output.strings = []
        output.instructions = []
        output.functions = []

        output.classDumpHeader = "@interface SampleClass : NSObject\n@end\n"

        let type = TypeReconstructedTypeObject(
            name: "SampleType",
            category: "class",
            size: 64,
            address: 0x1000,
            confidence: 0.9
        )
        let results = TypeReconstructionResultsObject(types: [type])
        output.typeReconstructionAnalysis = results
        output.totalReconstructedTypes = UInt(results.types.count)

        return output
    }
}
