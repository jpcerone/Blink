import Foundation
import AppKit

class CacheManager {
    static let shared = CacheManager()
    
    private let cacheDir: URL
    private let cacheFile: URL
    
    private init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        cacheDir = homeDir.appendingPathComponent(".config/blink")
        cacheFile = cacheDir.appendingPathComponent("single-instance-apps")
    }
    
    func loadSingleInstanceApps() -> Set<String> {
        // Ensure config directory exists
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
        
        // If file doesn't exist, create it with defaults
        if !FileManager.default.fileExists(atPath: cacheFile.path) {
            createDefaultFile()
        }
        
        // Read file and parse into Set
        guard let contents = try? String(contentsOf: cacheFile, encoding: .utf8) else {
            return getDefaultSingleInstanceApps()
        }
        
        let apps = contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        
        return Set(apps)
    }
    
    private func createDefaultFile() {
        let defaultContent = """
        # Blink Single-Instance Apps
        # If nothing is happening when selecting a specific app, try adding to this list.
        # Apps listed here will NOT use the -n flag when launched
        # This means they'll activate existing windows instead of opening new ones
        #
        # Add one app name per line (case-sensitive, must match exactly)
        # Lines starting with # are comments
        
        Finder
        System Settings
        System Preferences
        Activity Monitor
        
        """
        
        try? defaultContent.write(to: cacheFile, atomically: true, encoding: .utf8)
    }
    
    private func getDefaultSingleInstanceApps() -> Set<String> {
        return Set([
            "Finder",
            "System Settings",
            "System Preferences",
            "Activity Monitor"
        ])
    }
}
