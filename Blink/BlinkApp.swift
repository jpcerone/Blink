import SwiftUI
import AppKit

@main
struct BlinkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var launcher: LauncherWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Create and show launcher window immediately
        launcher = LauncherWindow()
        launcher?.showWindow()
    }
}
