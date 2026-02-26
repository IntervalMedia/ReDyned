import Foundation
import CommonCrypto

/// Cache metadata for decompiled binaries
struct CacheMetadata: Codable {
    let binaryPath: String
    let fileHash: String
    let fileSize: Int64
    let cacheDate: Date
    let appVersion: String
    
    var isValid: Bool {
        // Cache is valid for 30 days
        return Date().timeIntervalSince(cacheDate) < (30 * 24 * 60 * 60)
    }
}

/// Service for caching decompilation results to avoid re-processing
final class DecompilationCache {
    static let shared = DecompilationCache()
    
    private let fileManager = FileManager.default
    private let cacheDirectoryName = "DecompilationCache"
    private let metadataFileName = "metadata.json"
    private let cacheFileName = "cache.dat"
    
    private init() {
        try? createCacheDirectoryIfNeeded()
    }
    
    // MARK: - Public API
    
    /// Check if a cached decompilation result exists and is valid
    /// - Parameters:
    ///   - fileURL: URL of the binary file
    ///   - fileHash: Optional pre-computed hash (will compute if nil)
    /// - Returns: true if valid cache exists
    func hasCachedResult(for fileURL: URL, fileHash: String? = nil) -> Bool {
        do {
            let hash = try fileHash ?? computeFileHash(at: fileURL)
            let cacheDir = try cacheDirectory(for: hash)
            let metadataURL = cacheDir.appendingPathComponent(metadataFileName)
            let cacheFileURL = cacheDir.appendingPathComponent(cacheFileName)
            
            guard fileManager.fileExists(atPath: metadataURL.path),
                  fileManager.fileExists(atPath: cacheFileURL.path) else {
                return false
            }
            
            let metadata = try loadMetadata(from: metadataURL)
            
            // Verify metadata matches current file
            let currentFileSize = try fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 ?? 0
            guard metadata.fileSize == currentFileSize,
                  metadata.fileHash == hash,
                  metadata.isValid else {
                return false
            }
            
            return true
        } catch {
            return false
        }
    }
    
    /// Retrieve cached decompilation result
    /// - Parameters:
    ///   - fileURL: URL of the binary file
    ///   - fileHash: Optional pre-computed hash (will compute if nil)
    /// - Returns: Cached DecompiledOutput if available and valid
    func getCachedResult(for fileURL: URL, fileHash: String? = nil) -> DecompiledOutput? {
        do {
            let hash = try fileHash ?? computeFileHash(at: fileURL)
            let cacheDir = try cacheDirectory(for: hash)
            let cacheFileURL = cacheDir.appendingPathComponent(cacheFileName)
            
            guard hasCachedResult(for: fileURL, fileHash: hash) else {
                return nil
            }
            
            let data = try Data(contentsOf: cacheFileURL)
            
            // Use NSKeyedUnarchiver to decode
            if #available(iOS 12.0, *) {
                return try NSKeyedUnarchiver.unarchivedObject(ofClass: DecompiledOutput.self, from: data)
            } else {
                return NSKeyedUnarchiver.unarchiveObject(with: data) as? DecompiledOutput
            }
        } catch {
            print("DecompilationCache: Failed to load cache: \(error)")
            return nil
        }
    }
    
    /// Save decompilation result to cache
    /// - Parameters:
    ///   - output: The decompilation result to cache
    ///   - fileURL: URL of the source binary file
    ///   - fileHash: Optional pre-computed hash (will compute if nil)
    func saveCachedResult(_ output: DecompiledOutput, for fileURL: URL, fileHash: String? = nil) {
        do {
            let hash = try fileHash ?? computeFileHash(at: fileURL)
            let cacheDir = try cacheDirectory(for: hash, create: true)
            
            // Save metadata
            let fileSize = try fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 ?? 0
            let metadata = CacheMetadata(
                binaryPath: fileURL.path,
                fileHash: hash,
                fileSize: fileSize,
                cacheDate: Date(),
                appVersion: Constants.App.versionString
            )
            
            let metadataURL = cacheDir.appendingPathComponent(metadataFileName)
            let metadataData = try JSONEncoder().encode(metadata)
            try metadataData.write(to: metadataURL, options: .atomicWrite)
            
            // Save cache data using NSKeyedArchiver
            let cacheFileURL = cacheDir.appendingPathComponent(cacheFileName)
            let cacheData: Data
            if #available(iOS 12.0, *) {
                cacheData = try NSKeyedArchiver.archivedData(withRootObject: output, requiringSecureCoding: false)
            } else {
                cacheData = NSKeyedArchiver.archivedData(withRootObject: output)
            }
            try cacheData.write(to: cacheFileURL, options: .atomic)
            
            print("DecompilationCache: Saved cache for \(fileURL.lastPathComponent) (hash: \(hash.prefix(8))...)")
        } catch {
            print("DecompilationCache: Failed to save cache: \(error)")
        }
    }
    
    /// Clear cache for a specific binary
    /// - Parameters:
    ///   - fileURL: URL of the binary file
    ///   - fileHash: Optional pre-computed hash (will compute if nil)
    func clearCache(for fileURL: URL, fileHash: String? = nil) {
        do {
            let hash = try fileHash ?? computeFileHash(at: fileURL)
            let cacheDir = try cacheDirectory(for: hash)
            
            if fileManager.fileExists(atPath: cacheDir.path) {
                try fileManager.removeItem(at: cacheDir)
                print("DecompilationCache: Cleared cache for \(fileURL.lastPathComponent)")
            }
        } catch {
            print("DecompilationCache: Failed to clear cache: \(error)")
        }
    }
    
    /// Clear all cached decompilation results
    func clearAllCaches() {
        do {
            let cacheRoot = try cacheRootDirectory()
            if fileManager.fileExists(atPath: cacheRoot.path) {
                try fileManager.removeItem(at: cacheRoot)
                try createCacheDirectoryIfNeeded()
                print("DecompilationCache: Cleared all caches")
            }
        } catch {
            print("DecompilationCache: Failed to clear all caches: \(error)")
        }
    }
    
    /// Get total size of all cached data
    /// - Returns: Total size in bytes
    func totalCacheSize() -> Int64 {
        guard let cacheRoot = try? cacheRootDirectory(),
              let enumerator = fileManager.enumerator(at: cacheRoot, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        
        return totalSize
    }
    
    /// Get count of cached binaries
    /// - Returns: Number of cached items
    func cachedBinaryCount() -> Int {
        guard let cacheRoot = try? cacheRootDirectory(),
              let subdirs = try? fileManager.contentsOfDirectory(
                at: cacheRoot,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
              ) else {
            return 0
        }
        
        return subdirs.count
    }
    
    /// Remove old/stale caches
    /// - Parameter olderThan: TimeInterval in seconds (default: 30 days)
    func removeOldCaches(olderThan interval: TimeInterval = 30 * 24 * 60 * 60) {
        guard let cacheRoot = try? cacheRootDirectory(),
              let subdirs = try? fileManager.contentsOfDirectory(
                at: cacheRoot,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
              ) else {
            return
        }
        
        let cutoffDate = Date(timeIntervalSinceNow: -interval)
        var removedCount = 0
        
        for subdir in subdirs {
            let metadataURL = subdir.appendingPathComponent(metadataFileName)
            
            if let metadata = try? loadMetadata(from: metadataURL),
               metadata.cacheDate < cutoffDate {
                try? fileManager.removeItem(at: subdir)
                removedCount += 1
            }
        }
        
        if removedCount > 0 {
            print("DecompilationCache: Removed \(removedCount) old cache(s)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func cacheRootDirectory() throws -> URL {
        let cachesURL = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return cachesURL.appendingPathComponent(cacheDirectoryName, isDirectory: true)
    }
    
    private func cacheDirectory(for fileHash: String, create: Bool = false) throws -> URL {
        let root = try cacheRootDirectory()
        let hashDir = root.appendingPathComponent(fileHash, isDirectory: true)
        
        if create && !fileManager.fileExists(atPath: hashDir.path) {
            try fileManager.createDirectory(at: hashDir, withIntermediateDirectories: true)
        }
        
        return hashDir
    }
    
    private func createCacheDirectoryIfNeeded() throws {
        let cacheRoot = try cacheRootDirectory()
        if !fileManager.fileExists(atPath: cacheRoot.path) {
            try fileManager.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
        }
    }
    
    private func loadMetadata(from url: URL) throws -> CacheMetadata {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CacheMetadata.self, from: data)
    }
    
    private func computeFileHash(at url: URL) throws -> String {
        // Use a streaming approach for large files
        guard let inputStream = InputStream(url: url) else {
            throw NSError(domain: "DecompilationCache", code: 1, userInfo: [
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
                throw inputStream.streamError ?? NSError(domain: "DecompilationCache", code: 2, userInfo: [
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
