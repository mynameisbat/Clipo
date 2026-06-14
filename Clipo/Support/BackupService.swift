import Foundation
import AppKit

struct BackupService {
    static func exportBackup(to destinationURL: URL) async throws {
        let sourceURL = try ApplicationPaths.applicationSupportRoot()
        
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var readError: Error?
        
        coordinator.coordinate(readingItemAt: sourceURL, options: .forUploading, error: &coordinationError) { tempZipURL in
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: tempZipURL, to: destinationURL)
            } catch {
                readError = error
            }
        }
        
        if let coordinationError {
            throw coordinationError
        }
        if let readError {
            throw readError
        }
    }
    
    static func importBackup(from zipURL: URL) async throws {
        let destRootURL = try ApplicationPaths.applicationSupportRoot()
        let fileManager = FileManager.default
        
        // Create a temporary directory to unzip into
        let tempDirectoryURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDirectoryURL)
        }
        
        // Unzip the file using macOS built-in unzip tool
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", zipURL.path, "-d", tempDirectoryURL.path]
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "BackupService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Unzip failed"])
        }
        
        // Find database and images folder inside unzipped directory
        var sourceDbURL: URL?
        var sourceImagesURL: URL?
        
        if fileManager.fileExists(atPath: tempDirectoryURL.appendingPathComponent("clipboard.sqlite").path) {
            sourceDbURL = tempDirectoryURL.appendingPathComponent("clipboard.sqlite")
            sourceImagesURL = tempDirectoryURL.appendingPathComponent("images")
        } else {
            let clipoNested = tempDirectoryURL.appendingPathComponent("Clipo")
            if fileManager.fileExists(atPath: clipoNested.appendingPathComponent("clipboard.sqlite").path) {
                sourceDbURL = clipoNested.appendingPathComponent("clipboard.sqlite")
                sourceImagesURL = clipoNested.appendingPathComponent("images")
            }
        }
        
        guard let dbURL = sourceDbURL else {
            throw NSError(domain: "BackupService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invalid backup file: clipboard database not found."])
        }
        
        // Overwrite live files
        let currentDbURL = destRootURL.appendingPathComponent("clipboard.sqlite")
        let currentWalURL = destRootURL.appendingPathComponent("clipboard.sqlite-wal")
        let currentShmURL = destRootURL.appendingPathComponent("clipboard.sqlite-shm")
        
        try? fileManager.removeItem(at: currentDbURL)
        try? fileManager.removeItem(at: currentWalURL)
        try? fileManager.removeItem(at: currentShmURL)
        
        try fileManager.copyItem(at: dbURL, to: currentDbURL)
        
        let backupWal = dbURL.deletingLastPathComponent().appendingPathComponent("clipboard.sqlite-wal")
        if fileManager.fileExists(atPath: backupWal.path) {
            try? fileManager.copyItem(at: backupWal, to: currentWalURL)
        }
        let backupShm = dbURL.deletingLastPathComponent().appendingPathComponent("clipboard.sqlite-shm")
        if fileManager.fileExists(atPath: backupShm.path) {
            try? fileManager.copyItem(at: backupShm, to: currentShmURL)
        }
        
        let currentImagesURL = destRootURL.appendingPathComponent("images")
        try? fileManager.removeItem(at: currentImagesURL)
        
        if let imgURL = sourceImagesURL, fileManager.fileExists(atPath: imgURL.path) {
            try fileManager.copyItem(at: imgURL, to: currentImagesURL)
        }
    }
}
