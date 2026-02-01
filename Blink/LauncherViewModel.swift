import SwiftUI
import AppKit
import Combine

struct Application: Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let bundleIdentifier: String?
    let icon: NSImage?
    let isCLI: Bool
}

class LauncherViewModel: ObservableObject {
    @Published var searchText = "" {
        didSet {
            updateFilteredApps()
        }
    }
    @Published var allApps: [Application] = []
    @Published var filteredApps: [Application] = []
    @Published var selectedIndex = 0

    private(set) var config: BlinkConfig
    private var singleInstanceApps: Set<String>
    private var aliasLookup: [String: String] = [:] // shortcut -> app name

    init() {
        config = ConfigManager.shared.loadConfig()
        singleInstanceApps = CacheManager.shared.loadSingleInstanceApps()
        buildAliasLookup()
    }

    private func buildAliasLookup() {
        aliasLookup = [:]
        for alias in config.aliases {
            for shortcut in alias.shortcuts {
                aliasLookup[shortcut.lowercased()] = alias.app
            }
        }
    }
    
    func scanApplications() {
        // Reload config and single-instance apps
        config = ConfigManager.shared.loadConfig()
        singleInstanceApps = CacheManager.shared.loadSingleInstanceApps()
        buildAliasLookup()

        var apps: [Application] = []

        // Add custom apps from config first (highest priority)
        for customApp in config.customApps {
            let expandedPath = ConfigManager.shared.expandPath(customApp.path)
            if FileManager.default.fileExists(atPath: expandedPath) {
                let bundleId = getBundleIdentifier(forAppPath: expandedPath)
                let icon = NSWorkspace.shared.icon(forFile: expandedPath)
                apps.append(Application(
                    name: customApp.name,
                    path: expandedPath,
                    bundleIdentifier: bundleId,
                    icon: icon,
                    isCLI: false
                ))
            }
        }

        // Use Launch Services to get ALL installed applications
        apps.append(contentsOf: getAllInstalledApplications())

        // Remove duplicates (prefer first occurrence - custom apps have priority)
        var seenPaths = Set<String>()
        apps = apps.filter { app in
            if seenPaths.contains(app.path) {
                return false
            }
            seenPaths.insert(app.path)
            return true
        }

        // Apply exclusion filters
        apps = apps.filter { app in
            // Check exact name exclusions
            if config.excludeApps.contains(app.name) {
                return false
            }
            // Check pattern exclusions
            for pattern in config.excludePatterns {
                if ConfigManager.shared.matchesPattern(app.name, pattern: pattern) {
                    return false
                }
            }
            return true
        }

        allApps = apps.sorted { $0.path.lowercased() < $1.path.lowercased() }

        updateFilteredApps()
    }
    
    private func getAllInstalledApplications() -> [Application] {
        var apps: [Application] = []
        
        // Use MDQuery (Spotlight) to find all applications - this is what Spotlight uses
        let query = MDQueryCreate(kCFAllocatorDefault, "kMDItemContentType == 'com.apple.application-bundle'" as CFString, nil, nil)
        MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue))
        
        let resultCount = MDQueryGetResultCount(query)
        
        for i in 0..<resultCount {
            if let rawPointer = MDQueryGetResultAtIndex(query, i) {
                let item = Unmanaged<MDItem>.fromOpaque(rawPointer).takeUnretainedValue()
                
                if let path = MDItemCopyAttribute(item, kMDItemPath) as? String {
                    let url = URL(fileURLWithPath: path)
                    if let appInfo = getApplicationInfo(for: url) {
                        if(appInfo.name != ""){
                            apps.append(appInfo)
                        }
                    }
                }
            }
        }
        
        return apps
    }
    
    private func getApplicationInfo(for url: URL) -> Application? {
        guard let bundle = Bundle(url: url) else { return nil }
        
        // Get app name - prefer CFBundleDisplayName, fall back to CFBundleName, then filename
        let name = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                ?? url.deletingPathExtension().lastPathComponent
        
        let bundleId = bundle.bundleIdentifier
        let path = url.path
        let icon = NSWorkspace.shared.icon(forFile: path)
        
        return Application(
            name: name,
            path: path,
            bundleIdentifier: bundleId,
            icon: icon,
            isCLI: false
        )
    }
    
    func updateFilteredApps() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.searchText.isEmpty {
                self.filteredApps = Array(self.allApps.prefix(50))
                self.selectedIndex = 0
            } else {
                self.filteredApps = self.fuzzySearch(query: self.searchText, in: self.allApps)
                self.selectedIndex = 0
            }
            
            self.objectWillChange.send()
        }
    }
    
    func fuzzySearch(query: String, in apps: [Application]) -> [Application] {
        let query = query.lowercased()

        // Check if query matches an alias exactly
        let aliasTargetApp = aliasLookup[query]?.lowercased()

        let scored = apps.compactMap { app -> (app: Application, score: Int)? in
            let name = app.name.lowercased()

            // Exact alias match gets very high priority
            if let targetApp = aliasTargetApp, name == targetApp {
                return (app, 950)
            }

            // Check partial alias matches (query is prefix of a shortcut)
            for (shortcut, targetApp) in aliasLookup {
                if shortcut.hasPrefix(query) && name == targetApp.lowercased() {
                    return (app, 850)
                }
            }

            // Standard matching
            if name == query {
                return (app, 1000)
            }

            if name.hasPrefix(query) {
                return (app, 900)
            }

            if name.contains(query) {
                return (app, 500)
            }

            let fuzzyScore = calculateFuzzyScore(query: query, target: name)
            if fuzzyScore > 0 {
                return (app, fuzzyScore)
            }

            return nil
        }

        return scored
            .sorted { $0.score > $1.score }
            .map { $0.app }
            .prefix(50)
            .map { $0 }
    }
    
    func calculateFuzzyScore(query: String, target: String) -> Int {
        var queryIndex = query.startIndex
        var targetIndex = target.startIndex
        var score = 0
        var consecutive = 0
        
        while queryIndex < query.endIndex && targetIndex < target.endIndex {
            if query[queryIndex] == target[targetIndex] {
                score += 1 + consecutive
                consecutive += 1
                queryIndex = query.index(after: queryIndex)
            } else {
                consecutive = 0
            }
            targetIndex = target.index(after: targetIndex)
        }
        
        return queryIndex == query.endIndex ? score : 0
    }
    
    func moveSelectionUp() {
        if selectedIndex > 0 {
            selectedIndex -= 1
            objectWillChange.send()
        }
    }
    
    func moveSelectionDown() {
        if selectedIndex < filteredApps.count - 1 {
            selectedIndex += 1
            objectWillChange.send()
        }
    }
    
    func launchSelectedApp() {
        guard selectedIndex < filteredApps.count else { return }
        let app = filteredApps[selectedIndex]
        launchGUIApp(app)
    }
    
    func launchGUIApp(_ app: Application) {
        let task = Process()
        task.launchPath = "/usr/bin/open"

        // Determine whether to open new instance
        let useNewInstance: Bool
        if singleInstanceApps.contains(app.name) {
            // Single-instance apps never get -n flag
            useNewInstance = false
        } else if config.alwaysNewWindow {
            // Global override: always open new instances
            useNewInstance = true
        } else {
            // Default behavior: open new instances
            useNewInstance = true
        }

        if useNewInstance {
            task.arguments = ["-n", "-a", app.name]
        } else {
            task.arguments = ["-a", app.name]
        }

        do {
            try task.run()
        } catch {
            // Silently fail - user will notice if app doesn't launch
        }
    }
    
    private func getBundleIdentifier(forAppPath appPath: String) -> String? {
        let bundleURL = URL(fileURLWithPath: appPath)
        if let bundle = Bundle(url: bundleURL) {
            return bundle.bundleIdentifier
        }
        return nil
    }

    func markSelectedAsSingleInstance() {
        guard selectedIndex < filteredApps.count else { return }
        let app = filteredApps[selectedIndex]
        CacheManager.shared.addSingleInstanceApp(app.name)
        // Reload the set so it takes effect immediately
        singleInstanceApps = CacheManager.shared.loadSingleInstanceApps()
    }
}
