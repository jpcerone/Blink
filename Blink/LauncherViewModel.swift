import SwiftUI
import AppKit
import Combine

struct Application: Identifiable {
    var id: String { path } // Use path as stable ID
    let name: String
    let path: String
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
    @AppStorage("terminalApp") var terminalApp = "Terminal"
    
    init() {
        // No timer needed - updates happen immediately via didSet
    }
    
    func scanApplications() {
        var apps: [Application] = []
        
        // Hardcode Finder (it's in a weird location)
        let finderPath = "/System/Library/CoreServices/Finder.app"
        if FileManager.default.fileExists(atPath: finderPath) {
            let finderIcon = NSWorkspace.shared.icon(forFile: finderPath)
            apps.append(Application(name: "Finder", path: finderPath, icon: finderIcon, isCLI: false))
        }
        
        // Scan /Applications
        apps.append(contentsOf: scanDirectory("/Applications"))
        
        // Scan /System/Applications (includes system apps)
        apps.append(contentsOf: scanDirectory("/System/Applications"))
        
        // Scan ~/Applications
        if let homeDir = FileManager.default.homeDirectoryForCurrentUser.path as String? {
            apps.append(contentsOf: scanDirectory("\(homeDir)/Applications"))
        }
        
        // Sort by name
        allApps = apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
        
        // Debug logging
        print("✅ Scanned \(allApps.count) GUI applications")
        
        updateFilteredApps()
    }
    
    func scanDirectory(_ path: String) -> [Application] {
        var apps: [Application] = []
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return apps
        }
        
        for item in contents {
            let fullPath = "\(path)/\(item)"
            
            // Check if it's an app bundle
            if item.hasSuffix(".app") {
                let appName = item.replacingOccurrences(of: ".app", with: "")
                let icon = NSWorkspace.shared.icon(forFile: fullPath)
                apps.append(Application(name: appName, path: fullPath, icon: icon, isCLI: false))
            }
        }
        
        return apps
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
                
                // Debug: print first 5 results
                print("🔍 Search: '\(self.searchText)' -> \(self.filteredApps.count) results")
                for (i, app) in self.filteredApps.prefix(5).enumerated() {
                    print("   \(i): \(app.name)")
                }
            }
            
            // Force UI update
            self.objectWillChange.send()
        }
    }
    
    func fuzzySearch(query: String, in apps: [Application]) -> [Application] {
        let query = query.lowercased()
        
        // Score each app and sort by relevance
        let scored = apps.compactMap { app -> (app: Application, score: Int)? in
            let name = app.name.lowercased()
            
            // Exact match gets highest score
            if name == query {
                return (app, 1000)
            }
            
            // Starts with query gets high score
            if name.hasPrefix(query) {
                return (app, 900)
            }
            
            // Contains query gets medium score
            if name.contains(query) {
                return (app, 500)
            }
            
            // Fuzzy match
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
        
        // Return score only if all query characters were matched
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
        task.arguments = ["-n", "-a", app.path]
        
        do {
            try task.run()
        } catch {
            print("Failed to launch app: \(error)")
        }
    }
}
