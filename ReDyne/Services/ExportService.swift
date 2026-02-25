import Foundation
import UIKit

/// Supported export formats for decompiled binary analysis
enum ExportFormat {
    case text
    case json
    case html
    case pdf
    
    var fileExtension: String {
        switch self {
        case .text: return "txt"
        case .json: return "json"
        case .html: return "html"
        case .pdf: return "pdf"
        }
    }
    
    var mimeType: String {
        switch self {
        case .text: return "text/plain"
        case .json: return "application/json"
        case .html: return "text/html"
        case .pdf: return "application/pdf"
        }
    }
    
    var displayName: String {
        switch self {
        case .text: return "Plain Text"
        case .json: return "JSON"
        case .html: return "HTML Report"
        case .pdf: return "PDF Document"
        }
    }
}

/// Service for exporting decompiled output in various formats
/// Supports text, JSON, HTML, and PDF export formats
class ExportService {
    
    // MARK: - Public Export Methods
    
    /// Exports decompiled output in the specified format
    /// - Parameters:
    ///   - output: The decompiled binary output to export
    ///   - format: The desired export format
    /// - Returns: Data containing the exported content, or nil if export fails
    static func export(_ output: DecompiledOutput, format: ExportFormat) -> Data? {
        switch format {
        case .text:
            return exportAsText(output)
        case .json:
            return exportAsJSON(output)
        case .html:
            return exportAsHTML(output)
        case .pdf:
            return exportAsPDF(output)
        }
    }
    
    /// Generates a unique filename for exported output
    /// - Parameters:
    ///   - output: The decompiled output
    ///   - format: The export format
    /// - Returns: A timestamped filename with appropriate extension
    static func generateFilename(for output: DecompiledOutput, format: ExportFormat) -> String {
        let baseName = (output.fileName as NSString).deletingPathExtension
        let timestamp = DateFormatter.filenameDateFormatter.string(from: Date())
        return "\(baseName)_analysis_\(timestamp).\(format.fileExtension)"
    }
    
    /// Validates that the output is suitable for export
    /// - Parameter output: The decompiled output to validate
    /// - Returns: true if output can be exported, false otherwise
    static func canExport(_ output: DecompiledOutput) -> Bool {
        // Basic validation
        guard !output.fileName.isEmpty && output.fileSize > 0 else {
            return false
        }
        
        // Validate that header exists with required fields
        guard !output.header.cpuType.isEmpty else {
            return false
        }
        
        return true
    }
    
    // MARK: - Text Export
    
    private static func exportAsText(_ output: DecompiledOutput) -> Data? {
        var text = ""
        
        text += "═══════════════════════════════════════════════════════════════\n"
        text += "  ReDyne Decompilation Report\n"
        text += "═══════════════════════════════════════════════════════════════\n\n"
        
        text += "File: \(output.fileName)\n"
        text += "Size: \(Constants.formatBytes(Int64(output.fileSize)))\n"
        text += "Analyzed: \(DateFormatter.reportDateFormatter.string(from: output.processingDate))\n"
        text += "Processing Time: \(Constants.formatDuration(output.processingTime))\n\n"
        
        text += "───────────────────────────────────────────────────────────────\n"
        text += "MACH-O HEADER\n"
        text += "───────────────────────────────────────────────────────────────\n\n"
        text += "CPU Type: \(output.header.cpuType)\n"
        text += "File Type: \(output.header.fileType)\n"
        text += "Architecture: \(output.header.is64Bit ? "64-bit" : "32-bit")\n"
        text += "Load Commands: \(output.header.ncmds)\n"
        text += "Flags: 0x\(String(format: "%X", output.header.flags))\n"
        if let uuid = output.header.uuid {
            text += "UUID: \(uuid)\n"
        }
        text += "Encrypted: \(output.header.isEncrypted ? "Yes" : "No")\n\n"
        
        text += "───────────────────────────────────────────────────────────────\n"
        text += "SEGMENTS (\(output.segments.count))\n"
        text += "───────────────────────────────────────────────────────────────\n\n"
        for segment in output.segments {
            let paddedName = segment.name.padding(toLength: 16, withPad: " ", startingAt: 0)
            text += "\(paddedName) VM: \(Constants.formatAddress(segment.vmAddress))-\(Constants.formatAddress(segment.vmAddress + segment.vmSize))"
            text += "  File: 0x\(String(format: "%llX", segment.fileOffset))-0x\(String(format: "%llX", segment.fileOffset + segment.fileSize))"
            text += "  [\(segment.protection)]\n"
        }
        text += "\n"
        
        text += "───────────────────────────────────────────────────────────────\n"
        text += "STATISTICS\n"
        text += "───────────────────────────────────────────────────────────────\n\n"
        text += "Total Symbols: \(output.totalSymbols)\n"
        text += "  - Defined: \(output.definedSymbols)\n"
        text += "  - Undefined: \(output.undefinedSymbols)\n"
        text += "Total Strings: \(output.totalStrings)\n"
        text += "Total Instructions: \(output.totalInstructions)\n"
        text += "Total Functions: \(output.totalFunctions)\n\n"

        if let classDumpHeader = output.classDumpHeader, !classDumpHeader.isEmpty {
            text += "───────────────────────────────────────────────────────────────\n"
            text += "CLASS DUMP (First 200 lines)\n"
            text += "───────────────────────────────────────────────────────────────\n\n"
            let lines = classDumpHeader.split(separator: "\n", omittingEmptySubsequences: false)
            for (index, line) in lines.prefix(200).enumerated() {
                text += String(line)
                text += "\n"
                if index == 199 && lines.count > 200 {
                    text += "... and \(lines.count - 200) more lines\n"
                }
            }
            text += "\n"
        }

        if let typeResult = output.typeReconstructionAnalysis as? TypeReconstructionResultsObject,
           !typeResult.types.isEmpty {
            text += "───────────────────────────────────────────────────────────────\n"
            text += "TYPE RECONSTRUCTION (First 200)\n"
            text += "───────────────────────────────────────────────────────────────\n\n"
            for (index, type) in typeResult.types.prefix(200).enumerated() {
                let confidence = String(format: "%.2f", type.confidence)
                text += "\(type.name)  [\(type.category)]  size=\(type.size)  conf=\(confidence)\n"
                if index == 199 && typeResult.types.count > 200 {
                    text += "... and \(typeResult.types.count - 200) more types\n"
                }
            }
            text += "\n"
        }
        
        if !output.strings.isEmpty {
            text += "───────────────────────────────────────────────────────────────\n"
            text += "STRINGS (First 100 of \(output.strings.count))\n"
            text += "───────────────────────────────────────────────────────────────\n\n"
            for (index, string) in output.strings.prefix(100).enumerated() {
                text += "\(Constants.formatAddress(string.address))  [\(string.section)]  \(string.content.prefix(80))\n"
                if index >= 99 && output.strings.count > 100 {
                    text += "... and \(output.strings.count - 100) more strings\n"
                }
            }
            text += "\n"
        }
        
        if !output.symbols.isEmpty {
            text += "───────────────────────────────────────────────────────────────\n"
            text += "SYMBOLS (First 100 of \(output.symbols.count))\n"
            text += "───────────────────────────────────────────────────────────────\n\n"
            let sortedSymbols = output.symbols.sortedByAddress()
            for (index, symbol) in sortedSymbols.prefix(100).enumerated() {
                let typeStr = symbol.type.padding(toLength: 10, withPad: " ", startingAt: 0)
                text += "\(Constants.formatAddress(symbol.address))  \(typeStr)  \(symbol.name)\n"
                if index >= 99 && sortedSymbols.count > 100 {
                    text += "... and \(sortedSymbols.count - 100) more symbols\n"
                }
            }
            text += "\n"
        }
        
        text += "═══════════════════════════════════════════════════════════════\n"
        text += "End of Report - Generated by \(Constants.App.generatorLabel)\n"
        text += "═══════════════════════════════════════════════════════════════\n"
        
        return text.data(using: .utf8)
    }
    
    // MARK: - JSON Export
    
    private static func exportAsJSON(_ output: DecompiledOutput) -> Data? {
        var json: [String: Any] = [:]
        
        json["metadata"] = [
            "generator": Constants.App.generatorLabel,
            "generated_at": ISO8601DateFormatter().string(from: output.processingDate),
            "processing_time_seconds": output.processingTime
        ]
        
        json["file"] = [
            "name": output.fileName,
            "path": output.filePath,
            "size_bytes": output.fileSize
        ]
        
        json["header"] = [
            "cpu_type": output.header.cpuType,
            "file_type": output.header.fileType,
            "architecture": output.header.is64Bit ? "64-bit" : "32-bit",
            "is_64bit": output.header.is64Bit,
            "load_commands_count": output.header.ncmds,
            "flags": String(format: "0x%X", output.header.flags),
            "uuid": output.header.uuid ?? "",
            "is_encrypted": output.header.isEncrypted
        ]
        
        json["segments"] = output.segments.map { segment in
            return [
                "name": segment.name,
                "vm_address": String(format: "0x%llX", segment.vmAddress),
                "vm_size": segment.vmSize,
                "file_offset": segment.fileOffset,
                "file_size": segment.fileSize,
                "protection": segment.protection
            ]
        }
        
        json["statistics"] = [
            "total_symbols": output.totalSymbols,
            "defined_symbols": output.definedSymbols,
            "undefined_symbols": output.undefinedSymbols,
            "total_strings": output.totalStrings,
            "total_instructions": output.totalInstructions,
            "total_functions": output.totalFunctions,
            "total_reconstructed_types": output.totalReconstructedTypes
        ]
        
        json["strings"] = output.strings.map { string in
            return [
                "address": String(format: "0x%llX", string.address),
                "offset": string.offset,
                "length": string.length,
                "section": string.section,
                "is_cstring": string.isCString,
                "content": string.content
            ]
        }
        
        json["symbols"] = output.symbols.map { symbol in
            return [
                "name": symbol.name,
                "address": String(format: "0x%llX", symbol.address),
                "size": symbol.size,
                "type": symbol.type,
                "scope": symbol.scope,
                "is_defined": symbol.isDefined,
                "is_external": symbol.isExternal,
                "is_function": symbol.isFunction
            ]
        }
        
        if !output.functions.isEmpty {
            json["functions"] = output.functions.map { function in
                return [
                    "name": function.name,
                    "start_address": String(format: "0x%llX", function.startAddress),
                    "end_address": String(format: "0x%llX", function.endAddress),
                    "instruction_count": function.instructionCount
                ]
            }
        }

        if let classDumpHeader = output.classDumpHeader, !classDumpHeader.isEmpty {
            json["class_dump"] = [
                "header": classDumpHeader
            ]
        }

        if let typeResult = output.typeReconstructionAnalysis as? TypeReconstructionResultsObject,
           !typeResult.types.isEmpty {
            json["type_reconstruction"] = [
                "types": typeResult.types.map { type in
                    return [
                        "name": type.name,
                        "category": type.category,
                        "size": type.size,
                        "address": String(format: "0x%llX", type.address),
                        "confidence": type.confidence
                    ]
                }
            ]
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            return jsonData
        } catch {
            print("JSON export error: \(error)")
            return nil
        }
    }
    
    // MARK: - HTML Export
    
    private static func exportAsHTML(_ output: DecompiledOutput) -> Data? {
        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(output.fileName) - ReDyne Analysis</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    padding: 20px;
                    color: #333;
                }
                .container {
                    max-width: 1200px;
                    margin: 0 auto;
                    background: white;
                    border-radius: 16px;
                    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                    overflow: hidden;
                }
                .header {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 40px;
                    text-align: center;
                }
                .header h1 {
                    font-size: 36px;
                    font-weight: 700;
                    margin-bottom: 10px;
                    text-shadow: 0 2px 4px rgba(0,0,0,0.2);
                }
                .header p {
                    font-size: 14px;
                    opacity: 0.9;
                }
                .content {
                    padding: 40px;
                }
                .section {
                    margin-bottom: 40px;
                }
                .section-title {
                    font-size: 24px;
                    font-weight: 600;
                    color: #667eea;
                    margin-bottom: 20px;
                    padding-bottom: 10px;
                    border-bottom: 3px solid #667eea;
                }
                .info-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
                    gap: 15px;
                    margin-bottom: 20px;
                }
                .info-item {
                    background: #f8f9fa;
                    padding: 15px;
                    border-radius: 8px;
                    border-left: 4px solid #667eea;
                }
                .info-label {
                    font-size: 12px;
                    color: #666;
                    text-transform: uppercase;
                    font-weight: 600;
                    letter-spacing: 0.5px;
                    margin-bottom: 5px;
                }
                .info-value {
                    font-size: 16px;
                    color: #333;
                    font-weight: 500;
                    font-family: 'SF Mono', 'Monaco', monospace;
                }
                .table-container {
                    overflow-x: auto;
                    border-radius: 8px;
                    border: 1px solid #e0e0e0;
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    font-size: 13px;
                }
                thead {
                    background: #667eea;
                    color: white;
                }
                th {
                    padding: 12px 15px;
                    text-align: left;
                    font-weight: 600;
                    text-transform: uppercase;
                    font-size: 11px;
                    letter-spacing: 0.5px;
                }
                td {
                    padding: 10px 15px;
                    border-bottom: 1px solid #f0f0f0;
                }
                tbody tr:hover {
                    background: #f8f9fa;
                }
                .mono {
                    font-family: 'SF Mono', 'Monaco', 'Courier New', monospace;
                    font-size: 12px;
                    background: #f8f9fa;
                    padding: 2px 6px;
                    border-radius: 4px;
                }
                .badge {
                    display: inline-block;
                    padding: 4px 12px;
                    border-radius: 12px;
                    font-size: 11px;
                    font-weight: 600;
                    text-transform: uppercase;
                }
                .badge-success { background: #d4edda; color: #155724; }
                .badge-warning { background: #fff3cd; color: #856404; }
                .badge-info { background: #d1ecf1; color: #0c5460; }
                .stats-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
                    gap: 20px;
                }
                .stat-card {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 20px;
                    border-radius: 12px;
                    text-align: center;
                    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
                }
                .stat-value {
                    font-size: 32px;
                    font-weight: 700;
                    margin-bottom: 5px;
                }
                .stat-label {
                    font-size: 12px;
                    opacity: 0.9;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                }
                .footer {
                    background: #f8f9fa;
                    padding: 20px;
                    text-align: center;
                    color: #666;
                    font-size: 13px;
                    border-top: 1px solid #e0e0e0;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>⚙️ ReDyne Analysis Report</h1>
                    <p>\(output.fileName)</p>
                </div>
                
                <div class="content">
                    <div class="section">
                        <h2 class="section-title">📄 File Information</h2>
                        <div class="info-grid">
                            <div class="info-item">
                                <div class="info-label">Filename</div>
                                <div class="info-value">\(output.fileName)</div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">File Size</div>
                                <div class="info-value">\(Constants.formatBytes(Int64(output.fileSize)))</div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">Analysis Date</div>
                                <div class="info-value">\(DateFormatter.reportDateFormatter.string(from: output.processingDate))</div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">Processing Time</div>
                                <div class="info-value">\(Constants.formatDuration(output.processingTime))</div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="section">
                        <h2 class="section-title">🔧 Mach-O Header</h2>
                        <div class="info-grid">
                            <div class="info-item">
                                <div class="info-label">CPU Type</div>
                                <div class="info-value">\(output.header.cpuType)</div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">File Type</div>
                                <div class="info-value">\(output.header.fileType)</div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">Architecture</div>
                                <div class="info-value">\(output.header.is64Bit ? "64-bit" : "32-bit")</div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">Load Commands</div>
                                <div class="info-value">\(output.header.ncmds)</div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">Flags</div>
                                <div class="info-value">0x\(String(format: "%X", output.header.flags))</div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">Encrypted</div>
                                <div class="info-value">\(output.header.isEncrypted ? "🔒 Yes" : "🔓 No")</div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="section">
                        <h2 class="section-title">📊 Statistics</h2>
                        <div class="stats-grid">
                            <div class="stat-card">
                                <div class="stat-value">\(output.totalSymbols)</div>
                                <div class="stat-label">Symbols</div>
                            </div>
                            <div class="stat-card">
                                <div class="stat-value">\(output.totalStrings)</div>
                                <div class="stat-label">Strings</div>
                            </div>
                            <div class="stat-card">
                                <div class="stat-value">\(output.totalInstructions)</div>
                                <div class="stat-label">Instructions</div>
                            </div>
                            <div class="stat-card">
                                <div class="stat-value">\(output.totalFunctions)</div>
                                <div class="stat-label">Functions</div>
                            </div>
                            <div class="stat-card">
                                <div class="stat-value">\(output.segments.count)</div>
                                <div class="stat-label">Segments</div>
                            </div>
                            <div class="stat-card">
                                <div class="stat-value">\(output.sections.count)</div>
                                <div class="stat-label">Sections</div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="section">
                        <h2 class="section-title">📦 Segments (\(output.segments.count))</h2>
                        <div class="table-container">
                            <table>
                                <thead>
                                    <tr>
                                        <th>Name</th>
                                        <th>VM Address</th>
                                        <th>VM Size</th>
                                        <th>File Offset</th>
                                        <th>Protection</th>
                                    </tr>
                                </thead>
                                <tbody>
        """
        
        for segment in output.segments {
            html += """
                                    <tr>
                                        <td><strong>\(segment.name)</strong></td>
                                        <td><span class="mono">\(Constants.formatAddress(segment.vmAddress))</span></td>
                                        <td>\(Constants.formatBytes(Int64(segment.vmSize)))</td>
                                        <td><span class="mono">0x\(String(format: "%llX", segment.fileOffset))</span></td>
                                        <td><span class="badge badge-info">\(segment.protection)</span></td>
                                    </tr>
            """
        }
        
        html += """
                                </tbody>
                            </table>
                        </div>
                    </div>
                    
                    <div class="section">
                        <h2 class="section-title">🔤 Strings (First 50 of \(output.totalStrings))</h2>
                        <div class="table-container">
                            <table>
                                <thead>
                                    <tr>
                                        <th>Address</th>
                                        <th>Section</th>
                                        <th>Content</th>
                                    </tr>
                                </thead>
                                <tbody>
        """
        
        for string in output.strings.prefix(50) {
            let escapedContent = string.content
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .prefix(100)
            html += """
                                    <tr>
                                        <td><span class="mono">\(Constants.formatAddress(string.address))</span></td>
                                        <td><span class="badge badge-success">\(string.section)</span></td>
                                        <td>\(escapedContent)</td>
                                    </tr>
            """
        }
        
        html += """
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
                
                <div class="footer">
                    Generated by <strong>\(Constants.App.generatorLabel)</strong> • Epic Mach-O Decompiler
                </div>
            </div>
        </body>
        </html>
        """
        
        return html.data(using: .utf8)
    }
    
    // MARK: - PDF Export
    
    /// Exports the decompiled output as a formatted PDF document
    /// - Parameter output: The decompiled output to export
    /// - Returns: PDF data or nil if generation fails
    private static func exportAsPDF(_ output: DecompiledOutput) -> Data? {
        // Create PDF with standard page size
        let pageSize = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let pdfMetadata = [
            kCGPDFContextTitle: "\(output.fileName) - ReDyne Analysis",
            kCGPDFContextAuthor: Constants.App.generatorLabel,
            kCGPDFContextCreator: "ReDyne Binary Analyzer \(Constants.App.versionSummary)"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetadata as [String: Any]
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageSize, format: format)
        
        let pdfData = renderer.pdfData { context in
            // Page 1: Title and File Info
            context.beginPage()
            drawPDFTitlePage(output, in: context.cgContext, pageSize: pageSize)
            
            // Page 2: Header and Statistics
            context.beginPage()
            drawPDFHeaderPage(output, in: context.cgContext, pageSize: pageSize)
            
            // Page 3: Segments
            context.beginPage()
            drawPDFSegmentsPage(output, in: context.cgContext, pageSize: pageSize)
            
            // Page 4+: Symbols (if any)
            if !output.symbols.isEmpty {
                context.beginPage()
                drawPDFSymbolsPage(output, in: context.cgContext, pageSize: pageSize)
            }
            
            // Additional pages for strings if needed
            if !output.strings.isEmpty {
                context.beginPage()
                drawPDFStringsPage(output, in: context.cgContext, pageSize: pageSize)
            }
        }
        
        return pdfData
    }
    
    // MARK: - PDF Drawing Helpers
    
    private static func drawPDFTitlePage(_ output: DecompiledOutput, in context: CGContext, pageSize: CGRect) {
        let margin: CGFloat = 50
        var yPosition: CGFloat = margin
        
        // Draw title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 32),
            .foregroundColor: UIColor.systemBlue
        ]
        let title = "ReDyne Analysis Report"
        let titleSize = title.size(withAttributes: titleAttributes)
        let titlePoint = CGPoint(x: (pageSize.width - titleSize.width) / 2, y: yPosition)
        title.draw(at: titlePoint, withAttributes: titleAttributes)
        yPosition += titleSize.height + 40
        
        // Draw filename
        let filenameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20),
            .foregroundColor: UIColor.darkGray
        ]
        let filename = output.fileName
        let filenameSize = filename.size(withAttributes: filenameAttributes)
        let filenamePoint = CGPoint(x: (pageSize.width - filenameSize.width) / 2, y: yPosition)
        filename.draw(at: filenamePoint, withAttributes: filenameAttributes)
        yPosition += filenameSize.height + 60
        
        // Draw file info
        let infoAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        let infoItems = [
            "File Size: \(Constants.formatBytes(Int64(output.fileSize)))",
            "Architecture: \(output.header.cpuType)",
            "File Type: \(output.header.fileType)",
            "Analysis Date: \(DateFormatter.reportDateFormatter.string(from: output.processingDate))",
            "Processing Time: \(Constants.formatDuration(output.processingTime))"
        ]
        
        for info in infoItems {
            info.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: infoAttributes)
            yPosition += 25
        }
    }
    
    private static func drawPDFHeaderPage(_ output: DecompiledOutput, in context: CGContext, pageSize: CGRect) {
        let margin: CGFloat = 50
        var yPosition: CGFloat = margin
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.systemBlue
        ]
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        // Mach-O Header Section
        "Mach-O Header".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
        yPosition += 35
        
        let headerInfo = [
            "CPU Type: \(output.header.cpuType)",
            "File Type: \(output.header.fileType)",
            "Architecture: \(output.header.is64Bit ? "64-bit" : "32-bit")",
            "Load Commands: \(output.header.ncmds)",
            "Flags: 0x\(String(format: "%X", output.header.flags))",
            "Encrypted: \(output.header.isEncrypted ? "Yes" : "No")"
        ]
        
        for info in headerInfo {
            info.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: textAttributes)
            yPosition += 20
        }
        
        yPosition += 20
        
        // Statistics Section
        "Statistics".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
        yPosition += 35
        
        let statsInfo = [
            "Total Symbols: \(output.totalSymbols)",
            "  - Defined: \(output.definedSymbols)",
            "  - Undefined: \(output.undefinedSymbols)",
            "Total Strings: \(output.totalStrings)",
            "Total Instructions: \(output.totalInstructions)",
            "Total Functions: \(output.totalFunctions)",
            "Segments: \(output.segments.count)",
            "Sections: \(output.sections.count)"
        ]
        
        for info in statsInfo {
            info.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: textAttributes)
            yPosition += 20
        }
    }
    
    private static func drawPDFSegmentsPage(_ output: DecompiledOutput, in context: CGContext, pageSize: CGRect) {
        let margin: CGFloat = 50
        var yPosition: CGFloat = margin
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.systemBlue
        ]
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        
        "Segments (\(output.segments.count))".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
        yPosition += 35
        
        for segment in output.segments.prefix(20) {
            let segmentLine = String(format: "%-16s  VM: %@-%@  File: 0x%llX-0x%llX  [%@]",
                                   segment.name,
                                   Constants.formatAddress(segment.vmAddress),
                                   Constants.formatAddress(segment.vmAddress + segment.vmSize),
                                   segment.fileOffset,
                                   segment.fileOffset + segment.fileSize,
                                   segment.protection)
            
            segmentLine.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: textAttributes)
            yPosition += 15
            
            if yPosition > pageSize.height - margin {
                break
            }
        }
    }
    
    private static func drawPDFSymbolsPage(_ output: DecompiledOutput, in context: CGContext, pageSize: CGRect) {
        let margin: CGFloat = 50
        var yPosition: CGFloat = margin
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.systemBlue
        ]
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        
        "Symbols (First 50 of \(output.symbols.count))".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
        yPosition += 35
        
        let sortedSymbols = output.symbols.sortedByAddress()
        for symbol in sortedSymbols.prefix(50) {
            let symbolLine = String(format: "%@  %-12s  %@",
                                  Constants.formatAddress(symbol.address),
                                  symbol.type,
                                  String(symbol.name.prefix(60)))
            
            symbolLine.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: textAttributes)
            yPosition += 12
            
            if yPosition > pageSize.height - margin {
                break
            }
        }
    }
    
    private static func drawPDFStringsPage(_ output: DecompiledOutput, in context: CGContext, pageSize: CGRect) {
        let margin: CGFloat = 50
        var yPosition: CGFloat = margin
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.systemBlue
        ]
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        
        "Strings (First 50 of \(output.strings.count))".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
        yPosition += 35
        
        for string in output.strings.prefix(50) {
            let stringLine = String(format: "%@  [%-12s]  %@",
                                  Constants.formatAddress(string.address),
                                  string.section,
                                  String(string.content.prefix(50)))
            
            stringLine.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: textAttributes)
            yPosition += 12
            
            if yPosition > pageSize.height - margin {
                break
            }
        }
    }
}

// MARK: - Date Formatter Extensions

extension DateFormatter {
    static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
    
    static let reportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

