import Foundation
import AppKit

struct BlinkConfig: Codable {
    var terminal: String
    var customApps: [CustomApp]
    var scanPaths: [String]
    
    struct CustomApp: Codable {
        let name: String
        let path: String
    }
    
    static let `default` = BlinkConfig(
        terminal: "Terminal",
        customApps: [],
        scanPaths: [
            "/Applications",
            "/System/Applications",
            "~/Applications"
        ]
    )
}

class ConfigManager {
    static let shared = ConfigManager()
    
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
            print("⚠️  Failed to create config directory: \(error)")
        }
        
        // If config doesn't exist, create default
        if !FileManager.default.fileExists(atPath: configFile.path) {
            createDefaultConfig()
        }
        
        // Read and parse config
        guard let contents = try? String(contentsOf: configFile, encoding: .utf8) else {
            print("⚠️  Failed to read config, using defaults")
            return .default
        }
        
        return parseConfig(contents) ?? .default
    }
    
    private func createDefaultConfig() {
        let defaultConfig = """
        # Blink Configuration File
        # Located at: ~/.config/blink/blink.config
        
        # Terminal application to use for CLI tools
        # Options: "Terminal", "iTerm", "Warp", "Alacritty", "Kitty"
        terminal = "Terminal"
        
        # Directories to scan for applications
        # Paths starting with ~ will be expanded to your home directory
        scan_paths = [
            "/Applications",
            "/System/Applications",
            "~/Applications"
        ]
        
        # Custom applications to add manually
        # Useful for apps in non-standard locations or scripts you want to launch
        # Format:
        # [[custom_apps]]
        # name = "My App"
        # path = "/path/to/app.app"
        
        [[custom_apps]]
        name = "Finder"
        path = "/System/Library/CoreServices/Finder.app"
        
        """
        
        do {
            try defaultConfig.write(to: configFile, atomically: true, encoding: .utf8)
            print("✅ Created default config at: \(configFile.path)")
        } catch {
            print("⚠️  Failed to create config file: \(error)")
        }
    }
    
    private func parseConfig(_ contents: String) -> BlinkConfig? {
        var terminal = "Terminal"
        var customApps: [BlinkConfig.CustomApp] = []
        var scanPaths: [String] = []
        
        var currentApp: (name: String?, path: String?) = (nil, nil)
        
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Parse terminal
            if trimmed.hasPrefix("terminal") {
                if let value = extractValue(from: trimmed) {
                    terminal = value
                }
            }
            
            // Parse scan_paths array
            else if trimmed.hasPrefix("scan_paths") {
                scanPaths = parseArray(from: trimmed)
            }
            
            // Parse custom_apps section
            else if trimmed == "[[custom_apps]]" {
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
            terminal: terminal,
            customApps: customApps,
            scanPaths: scanPaths.isEmpty ? BlinkConfig.default.scanPaths : scanPaths
        )
    }
    
    private func extractValue(from line: String) -> String? {
        guard let equalsIndex = line.firstIndex(of: "=") else { return nil }
        let value = line[line.index(after: equalsIndex)...]
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return value.isEmpty ? nil : value
    }
    
    private func parseArray(from line: String) -> [String] {
        guard let startBracket = line.firstIndex(of: "["),
              let endBracket = line.lastIndex(of: "]") else {
            return []
        }
        
        let arrayContent = line[line.index(after: startBracket)..<endBracket]
        return arrayContent
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            .filter { !$0.isEmpty }
    }
    
    func expandPath(_ path: String) -> String {
        if path.hasPrefix("~") {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            return path.replacingOccurrences(of: "~", with: homeDir)
        }
        return path
    }
}
