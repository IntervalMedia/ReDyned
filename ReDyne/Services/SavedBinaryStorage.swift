import Foundation
import CommonCrypto

/// Metadata associated with a saved binary file
struct BinaryMetadata: Codable {
    let originalPath: String
    let importDate: Date
    let fileSize: Int64
    let fileHash: String?
    var lastAccessDate: Date
    var accessCount: Int
    
    init(originalPath: String, fileSize: Int64, fileHash: String? = nil) {
        self.originalPath = originalPath
        self.importDate = Date()
        self.fileSize = fileSize
        self.fileHash = fileHash
        self.lastAccessDate = Date()
        self.accessCount = 0
    }
}

/// Service for managing saved binary files with metadata tracking
final class SavedBinaryStorage {
    static let shared = SavedBinaryStorage()
    
    private let fileManager = FileManager.default
    private let metadataFileName = ".metadata.json"
    private var metadataCache: [String: BinaryMetadata] = [:]
    
    private init() {
        try? createStorageDirectoryIfNeeded()
        loadMetadata()
    }
    
    // MARK: - Public API
    
    /// Returns the URL of the storage directory for saved binaries
    /// - Throws: Error if directory cannot be accessed
    /// - Returns: URL of the storage directory
    func storageDirectoryURL() throws -> URL {
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return documentsURL.appendingPathComponent(Constants.File.savedBinariesDirectoryName, isDirectory: true)
    }
    
    /// Imports a binary file into storage with metadata tracking
    /// - Parameters:
    ///   - sourceURL: URL of the file to import
    ///   - preferredName: Optional preferred name for the file
    /// - Throws: Error if import fails
    /// - Returns: URL of the imported file in storage
    @discardableResult
    func importBinary(from sourceURL: URL, preferredName: String? = nil) throws -> URL {
        try createStorageDirectoryIfNeeded()
        
        let storageURL = try storageDirectoryURL()
        let standardizedSource = sourceURL.standardizedFileURL
        
        if isFileInStorage(standardizedSource) {
            // Update access metadata
            updateAccessMetadata(for: standardizedSource)
            return standardizedSource
        }
        
        let fileName = sanitizeFileName(preferredName ?? standardizedSource.lastPathComponent)
        var destinationURL = storageURL.appendingPathComponent(fileName)
        destinationURL = makeUniqueURL(for: destinationURL)
        
        try fileManager.copyItem(at: standardizedSource, to: destinationURL)
        try excludeFromBackup(destinationURL)
        
        // Create metadata
        let fileSize = try fileManager.attributesOfItem(atPath: standardizedSource.path)[.size] as? Int64 ?? 0
        let fileHash = try? computeFileHash(at: standardizedSource)
        var metadata = BinaryMetadata(originalPath: sourceURL.path, fileSize: fileSize, fileHash: fileHash)
        metadata.accessCount = 1
        saveMetadata(metadata, for: destinationURL)
        
        cleanupTemporaryCopyIfNeeded(at: standardizedSource)
        
        return destinationURL
    }
    
    /// Deletes a binary file from storage
    /// - Parameter url: URL of the file to delete
    /// - Throws: Error if deletion fails
    func deleteBinary(at url: URL) throws {
        guard isFileInStorage(url) else { return }
        
        // Remove metadata
        removeMetadata(for: url)
        
        try fileManager.removeItem(at: url)
    }
    
    /// Lists all saved binaries sorted by modification date
    /// - Returns: Array of URLs for saved binaries
    func listSavedBinaries() -> [URL] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: (try? storageDirectoryURL()) ?? URL(fileURLWithPath: "/"),
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }
        
        return urls.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }
    }
    
    /// Gets metadata for a saved binary
    /// - Parameter url: URL of the binary file
    /// - Returns: Metadata if available, nil otherwise
    func getMetadata(for url: URL) -> BinaryMetadata? {
        let key = url.lastPathComponent
        return metadataCache[key]
    }
    
    /// Checks if a file is located in the storage directory
    /// - Parameter url: URL to check
    /// - Returns: true if file is in storage, false otherwise
    func isFileInStorage(_ url: URL) -> Bool {
        guard let storageURL = try? storageDirectoryURL() else { return false }
        let standardizedStoragePath = storageURL.standardizedFileURL.path
        let standardizedPath = url.standardizedFileURL.path
        return standardizedPath.hasPrefix(standardizedStoragePath)
    }
    
    /// Computes total size of all saved binaries
    /// - Returns: Total size in bytes
    func totalStorageSize() -> Int64 {
        let urls = listSavedBinaries()
        return urls.reduce(0) { total, url in
            guard let size = try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64 else {
                return total
            }
            return total + size
        }
    }
    
    /// Gets the number of saved binaries
    /// - Returns: Count of saved files
    func savedBinaryCount() -> Int {
        return listSavedBinaries().count
    }
    
    // MARK: - Private Helpers
    
    private func createStorageDirectoryIfNeeded() throws {
        let storageURL = try storageDirectoryURL()
        if !fileManager.fileExists(atPath: storageURL.path) {
            try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
        }
    }
    
    private func makeUniqueURL(for url: URL) -> URL {
        var candidateURL = url
        let pathExtension = candidateURL.pathExtension
        let baseName = candidateURL.deletingPathExtension().lastPathComponent
        var attempt = 1
        
        while fileManager.fileExists(atPath: candidateURL.path) {
            let newName: String
            if pathExtension.isEmpty {
                newName = "\(baseName)-\(attempt)"
            } else {
                newName = "\(baseName)-\(attempt).\(pathExtension)"
            }
            candidateURL = candidateURL.deletingLastPathComponent().appendingPathComponent(newName)
            attempt += 1
        }
        
        return candidateURL
    }
    
    private func sanitizeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let sanitized = name.components(separatedBy: invalidCharacters).joined(separator: "_")
        if sanitized.isEmpty {
            return "binary.dylib"
        }
        return sanitized
    }
    
    private func excludeFromBackup(_ url: URL) throws {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(resourceValues)
    }
    
    private func cleanupTemporaryCopyIfNeeded(at url: URL) {
        let path = url.standardizedFileURL.path
        guard path.contains("-Inbox/") || path.contains("/tmp/") else { return }
        try? fileManager.removeItem(at: url)
    }
    
    // MARK: - Metadata Management
    
    private func metadataFileURL() throws -> URL {
        return try storageDirectoryURL().appendingPathComponent(metadataFileName)
    }
    
    private func loadMetadata() {
        guard let metadataURL = try? metadataFileURL(),
              fileManager.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL) else {
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        metadataCache = (try? decoder.decode([String: BinaryMetadata].self, from: data)) ?? [:]
    }
    
    private func saveAllMetadata() {
        guard let metadataURL = try? metadataFileURL() else { return }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let data = try? encoder.encode(metadataCache) else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }
    
    private func saveMetadata(_ metadata: BinaryMetadata, for url: URL) {
        let key = url.lastPathComponent
        metadataCache[key] = metadata
        saveAllMetadata()
    }
    
    private func removeMetadata(for url: URL) {
        let key = url.lastPathComponent
        metadataCache.removeValue(forKey: key)
        saveAllMetadata()
    }
    
    private func updateAccessMetadata(for url: URL) {
        let key = url.lastPathComponent
        guard var metadata = metadataCache[key] else { return }
        
        metadata.lastAccessDate = Date()
        metadata.accessCount += 1
        metadataCache[key] = metadata
        saveAllMetadata()
    }
    
    private func computeFileHash(at url: URL) throws -> String {
        // Use a streaming approach to avoid loading entire file into memory
        guard let inputStream = InputStream(url: url) else {
            throw NSError(domain: "SavedBinaryStorage", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Cannot open file for hashing"
            ])
        }
        
        inputStream.open()
        defer { inputStream.close() }
        
        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)
        
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(buffer, maxLength: bufferSize)
            if bytesRead < 0 {
                throw inputStream.streamError ?? NSError(domain: "SavedBinaryStorage", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Error reading file for hashing"
                ])
            }
            if bytesRead > 0 {
                CC_SHA256_Update(&context, buffer, CC_LONG(bytesRead))
            }
        }
        
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&digest, &context)
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
