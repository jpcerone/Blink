import SwiftUI
import AppKit

@main
struct BlinkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Minimal scene - prevents default window creation
    var body: some Scene {
        Settings { 
            EmptyView() 
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var launcher: LauncherWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Stay as regular app for proper focus handling
        //NSApp.setActivationPolicy(.accessory)
        
        // Force app to front
        NSApp.activate(ignoringOtherApps: true)
        
        // Create and show launcher window immediately
        launcher = LauncherWindow()
        launcher?.showWindow()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
