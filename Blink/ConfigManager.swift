import Foundation
import AppKit
import OSLog

struct BlinkConfig: Codable {
    var customApps: [CustomApp]
    var aliases: [AppAlias]
    var excludeApps: [String]
    var excludePatterns: [String]
    var shortcuts: ShortcutsConfig
    var alwaysNewWindow: Bool
    var closeOnBlur: Bool
    var quitAfterLaunch: Bool

    struct CustomApp: Codable {
        let name: String
        let path: String
    }

    struct AppAlias: Codable {
        let app: String
        let shortcuts: [String]
    }

    struct ShortcutsConfig: Codable {
        var preferences: String?
        var refresh: String?
        var markSingleInstance: String?

        static let `default` = ShortcutsConfig(
            preferences: "cmd+,",
            refresh: "cmd+r",
            markSingleInstance: "cmd+s"
        )
    }

    static let `default` = BlinkConfig(
        customApps: [],
        aliases: [],
        excludeApps: [],
        excludePatterns: [],
        shortcuts: .default,
        alwaysNewWindow: false,
        closeOnBlur: true,
        quitAfterLaunch: true
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

        # ============================================
        # CUSTOM APPLICATIONS
        # ============================================
        # Apps in non-standard locations or scripts you want to launch
        #
        # [[custom_apps]]
        # name = "My App"
        # path = "/path/to/app.app"

        # ============================================
        # APP ALIASES (search shortcuts)
        # ============================================
        # Define alternative search terms for apps
        # App name must match exactly as it appears in Blink's search results
        #
        # [[aliases]]
        # app = "Code"
        # shortcuts = ["vsc", "vscode", "editor"]
        #
        # [[aliases]]
        # app = "Google Chrome"
        # shortcuts = ["chrome", "browser", "gc"]

        # ============================================
        # EXCLUDED APPS
        # ============================================
        # Apps to hide from search results
        # exclude_apps = ["Migration Assistant", "Boot Camp Assistant"]

        # Pattern-based exclusions (supports * wildcard)
        # exclude_patterns = ["*Helper*", "*Uninstaller*"]

        # ============================================
        # KEYBOARD SHORTCUTS
        # ============================================
        # Format: "modifier+key" (cmd, shift, alt, ctrl)
        [shortcuts]
        preferences = "cmd+,"
        refresh = "cmd+r"
        mark_single_instance = "cmd+s"

        # ============================================
        # LAUNCH BEHAVIOR
        # ============================================
        # Always open new window (override single-instance behavior globally)
        always_new_window = false

        # Close Blink when window loses focus
        close_on_blur = true

        # Quit after launching an app
        quit_after_launch = true

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
        var aliases: [BlinkConfig.AppAlias] = []
        var excludeApps: [String] = []
        var excludePatterns: [String] = []
        var shortcuts = BlinkConfig.ShortcutsConfig.default
        var alwaysNewWindow = false
        var closeOnBlur = true
        var quitAfterLaunch = true

        enum ParseSection {
            case none
            case customApps
            case aliases
            case shortcuts
        }
        var currentSection: ParseSection = .none

        var currentApp: (name: String?, path: String?) = (nil, nil)
        var currentAlias: (app: String?, shortcuts: [String]?) = (nil, nil)

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Section headers
            if trimmed == "[[custom_apps]]" {
                saveCurrentItems(&currentApp, &currentAlias, &customApps, &aliases, currentSection)
                currentSection = .customApps
                currentApp = (nil, nil)
                continue
            }
            if trimmed == "[[aliases]]" {
                saveCurrentItems(&currentApp, &currentAlias, &customApps, &aliases, currentSection)
                currentSection = .aliases
                currentAlias = (nil, nil)
                continue
            }
            if trimmed == "[shortcuts]" {
                saveCurrentItems(&currentApp, &currentAlias, &customApps, &aliases, currentSection)
                currentSection = .shortcuts
                continue
            }

            // Parse based on current section
            switch currentSection {
            case .customApps:
                if trimmed.hasPrefix("name") {
                    currentApp.name = extractValue(from: trimmed)
                } else if trimmed.hasPrefix("path") {
                    currentApp.path = extractValue(from: trimmed)
                }

            case .aliases:
                if trimmed.hasPrefix("app") {
                    currentAlias.app = extractValue(from: trimmed)
                } else if trimmed.hasPrefix("shortcuts") {
                    currentAlias.shortcuts = extractArrayValue(from: trimmed)
                }

            case .shortcuts:
                if trimmed.hasPrefix("preferences") {
                    shortcuts.preferences = extractValue(from: trimmed)
                } else if trimmed.hasPrefix("refresh") {
                    shortcuts.refresh = extractValue(from: trimmed)
                } else if trimmed.hasPrefix("mark_single_instance") {
                    shortcuts.markSingleInstance = extractValue(from: trimmed)
                }

            case .none:
                // Top-level keys
                if trimmed.hasPrefix("exclude_apps") {
                    excludeApps = extractArrayValue(from: trimmed) ?? []
                } else if trimmed.hasPrefix("exclude_patterns") {
                    excludePatterns = extractArrayValue(from: trimmed) ?? []
                } else if trimmed.hasPrefix("always_new_window") {
                    alwaysNewWindow = extractBoolValue(from: trimmed) ?? false
                } else if trimmed.hasPrefix("close_on_blur") {
                    closeOnBlur = extractBoolValue(from: trimmed) ?? true
                } else if trimmed.hasPrefix("quit_after_launch") {
                    quitAfterLaunch = extractBoolValue(from: trimmed) ?? true
                }
            }
        }

        // Save final items
        saveCurrentItems(&currentApp, &currentAlias, &customApps, &aliases, currentSection)

        return BlinkConfig(
            customApps: customApps,
            aliases: aliases,
            excludeApps: excludeApps,
            excludePatterns: excludePatterns,
            shortcuts: shortcuts,
            alwaysNewWindow: alwaysNewWindow,
            closeOnBlur: closeOnBlur,
            quitAfterLaunch: quitAfterLaunch
        )
    }

    private func saveCurrentItems(
        _ currentApp: inout (name: String?, path: String?),
        _ currentAlias: inout (app: String?, shortcuts: [String]?),
        _ customApps: inout [BlinkConfig.CustomApp],
        _ aliases: inout [BlinkConfig.AppAlias],
        _ section: Any
    ) {
        if let name = currentApp.name, let path = currentApp.path {
            customApps.append(BlinkConfig.CustomApp(name: name, path: path))
        }
        currentApp = (nil, nil)

        if let app = currentAlias.app, let shortcuts = currentAlias.shortcuts {
            aliases.append(BlinkConfig.AppAlias(app: app, shortcuts: shortcuts))
        }
        currentAlias = (nil, nil)
    }
    
    private func extractValue(from line: String) -> String? {
        guard let equalsIndex = line.firstIndex(of: "=") else { return nil }
        let value = line[line.index(after: equalsIndex)...]
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return value.isEmpty ? nil : value
    }

    private func extractArrayValue(from line: String) -> [String]? {
        guard let equalsIndex = line.firstIndex(of: "=") else { return nil }
        let value = line[line.index(after: equalsIndex)...]
            .trimmingCharacters(in: .whitespaces)

        // Handle array syntax: ["item1", "item2"]
        guard value.hasPrefix("[") && value.hasSuffix("]") else { return nil }
        let inner = value.dropFirst().dropLast()
        return inner.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            .filter { !$0.isEmpty }
    }

    private func extractBoolValue(from line: String) -> Bool? {
        guard let equalsIndex = line.firstIndex(of: "=") else { return nil }
        let value = line[line.index(after: equalsIndex)...]
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        if value == "true" { return true }
        if value == "false" { return false }
        return nil
    }

    func matchesPattern(_ name: String, pattern: String) -> Bool {
        // Convert glob pattern to regex: * matches any characters
        let regexPattern = "^" + NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*") + "$"

        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive) else {
            return false
        }

        let range = NSRange(name.startIndex..., in: name)
        return regex.firstMatch(in: name, options: [], range: range) != nil
    }
    
    func expandPath(_ path: String) -> String {
        if path.hasPrefix("~") {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            return path.replacingOccurrences(of: "~", with: homeDir)
        }
        return path
    }

    func getConfigFilePath() -> URL {
        return configFile
    }
}
