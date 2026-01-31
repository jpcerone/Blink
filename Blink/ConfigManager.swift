import Foundation
import AppKit
import OSLog

struct BlinkConfig: Codable {
    var customApps: [CustomApp]
    
    struct CustomApp: Codable {
        let name: String
        let path: String
    }
    
    static let `default` = BlinkConfig(
        customApps: []
    )
}

class ConfigManager {
    static let shared = ConfigManager()
    
    private let logger = Logger(subsystem: "com.blink.app", category: "ConfigManager")
    private let configDir: URL
    private let configFile: URL
    
    private init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        configDir = homeDir.appendingPathComponent(".config/blink")
        configFile = configDir.appendingPathComponent("blink.config")
    }
    
    func loadConfig() -> BlinkConfig {
        // Ensure config directory exists
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            logger.error("Failed to create config directory: \(error.localizedDescription)")
        }
        
        // If config doesn't exist, create default
        if !FileManager.default.fileExists(atPath: configFile.path) {
            createDefaultConfig()
        }
        
        // Read and parse config
        guard let contents = try? String(contentsOf: configFile, encoding: .utf8) else {
            logger.warning("Failed to read config, using defaults")
            return .default
        }
        
        return parseConfig(contents) ?? .default
    }
    
    private func createDefaultConfig() {
        let defaultConfig = """
        # Blink Configuration File
        # Located at: ~/.config/blink/blink.config
        
        # Custom applications to add manually
        # Useful for apps in non-standard locations or scripts you want to launch
        # Format:
        # [[custom_apps]]
        # name = "My App"
        # path = "/path/to/app.app"
        
        """
        
        do {
            try defaultConfig.write(to: configFile, atomically: true, encoding: .utf8)
            logger.info("Created default config at: \(self.configFile.path)")
        } catch {
            logger.error("Failed to create config file: \(error.localizedDescription)")
        }
    }
    
    private func parseConfig(_ contents: String) -> BlinkConfig? {
        var customApps: [BlinkConfig.CustomApp] = []
        
        var currentApp: (name: String?, path: String?) = (nil, nil)
        
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Parse custom_apps section
            if trimmed == "[[custom_apps]]" {
                // Save previous app if complete
                if let name = currentApp.name, let path = currentApp.path {
                    customApps.append(BlinkConfig.CustomApp(name: name, path: path))
                }
                currentApp = (nil, nil)
            }
            else if trimmed.hasPrefix("name") {
                currentApp.name = extractValue(from: trimmed)
            }
            else if trimmed.hasPrefix("path") {
                currentApp.path = extractValue(from: trimmed)
            }
        }
        
        // Save last app
        if let name = currentApp.name, let path = currentApp.path {
            customApps.append(BlinkConfig.CustomApp(name: name, path: path))
        }
        
        return BlinkConfig(
            customApps: customApps
        )
    }
    
    private func extractValue(from line: String) -> String? {
        guard let equalsIndex = line.firstIndex(of: "=") else { return nil }
        let value = line[line.index(after: equalsIndex)...]
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return value.isEmpty ? nil : value
    }
    
    func expandPath(_ path: String) -> String {
        if path.hasPrefix("~") {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            return path.replacingOccurrences(of: "~", with: homeDir)
        }
        return path
    }
}
