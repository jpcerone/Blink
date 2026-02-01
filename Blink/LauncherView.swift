import SwiftUI
import AppKit

// Keyboard shortcut parser
struct KeyboardShortcutParser {
    struct ParsedShortcut {
        let modifiers: NSEvent.ModifierFlags
        let keyCode: UInt16
    }

    static func parse(_ shortcut: String) -> ParsedShortcut? {
        let parts = shortcut.lowercased().components(separatedBy: "+")
        var modifiers: NSEvent.ModifierFlags = []
        var key: String = ""

        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            switch trimmed {
            case "cmd", "command": modifiers.insert(.command)
            case "shift": modifiers.insert(.shift)
            case "alt", "option": modifiers.insert(.option)
            case "ctrl", "control": modifiers.insert(.control)
            default: key = trimmed
            }
        }

        guard let keyCode = keyCodeFor(key) else { return nil }
        return ParsedShortcut(modifiers: modifiers, keyCode: keyCode)
    }

    private static func keyCodeFor(_ key: String) -> UInt16? {
        let keyMap: [String: UInt16] = [
            ",": 43, ".": 47, "/": 44,
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3,
            "g": 5, "h": 4, "i": 34, "j": 38, "k": 40, "l": 37,
            "m": 46, "n": 45, "o": 31, "p": 35, "q": 12, "r": 15,
            "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7,
            "y": 16, "z": 6,
            "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
            "6": 22, "7": 26, "8": 28, "9": 25, "0": 29,
        ]
        return keyMap[key]
    }
}

// Custom window class that allows borderless windows to become key and accept input
class BlinkWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}

class LauncherWindow {
    var window: BlinkWindow?
    var hostingController: NSHostingController<LauncherView>?
    let windowWidth = 600
    let windowHeight = 400
    private var blurObserver: NSObjectProtocol?

    init() {
        let config = ConfigManager.shared.loadConfig()

        let launcherView = LauncherView(
            closeWindow: { [weak self] in
                self?.hideWindow()
                NSApp.terminate(nil)
            },
            launchAndClose: { [weak self] in
                self?.hideWindow()
                // Small delay to ensure app launches before we quit
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if config.quitAfterLaunch {
                        NSApp.terminate(nil)
                    }
                }
            }
        )

        hostingController = NSHostingController(rootView: launcherView)

        window = BlinkWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window?.contentViewController = hostingController
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.level = .floating
        window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window?.isMovableByWindowBackground = true

        // Close on blur if configured
        if config.closeOnBlur {
            blurObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.hideWindow()
                NSApp.terminate(nil)
            }
        }
    }

    deinit {
        if let observer = blurObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func showWindow() {
        guard let window = window else { return }
        
        
        // Get the screen containing the mouse cursor (the "focused" screen)
        // This ensures Blink opens on whichever monitor the user is actively using
        let mouseLocation = NSEvent.mouseLocation
        let screenWithMouse = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.main
        
        // Center window on screen
        if let screen = screenWithMouse {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - (CGFloat)(windowWidth / 2)
            let y = screenRect.midY - (CGFloat)(windowHeight / 2) + 200
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // Very aggressive window activation
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        // Force the window to be key and make the text field first responder
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKey()
            
            // Find and focus the text field
            self.focusTextField(in: window.contentView)
        }
        
        // Additional focus attempt after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKey()
            self.focusTextField(in: window.contentView)
        }
        
        // Note: resetSearch is handled in LauncherView.onAppear
    }
    
    private func focusTextField(in view: NSView?) {
        guard let view = view else { return }
        
        // If this is a text field, make it first responder
        if let textField = view as? NSTextField {
            window?.makeFirstResponder(textField)
            return
        }
        
        // Recursively search subviews
        for subview in view.subviews {
            focusTextField(in: subview)
        }
    }
    
    func hideWindow() {
        window?.orderOut(nil)
    }
}

struct LauncherView: View {
    @StateObject private var viewModel = LauncherViewModel()
    @FocusState private var isSearchFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?
    var closeWindow: () -> Void
    var launchAndClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search applications...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .focused($isSearchFocused)
                    .onSubmit {
                        viewModel.launchSelectedApp()
                        launchAndClose()
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
            
            Divider()
            
            // Results list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.filteredApps) { app in
                            let index = viewModel.filteredApps.firstIndex(where: { $0.id == app.id }) ?? 0
                            AppRow(app: app, isSelected: index == viewModel.selectedIndex)
                                .id(app.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectedIndex = index
                                    viewModel.launchSelectedApp()
                                    launchAndClose()
                                }
                        }
                    }
                }
                .onAppear {
                    scrollProxy = proxy
                }
            }
            .frame(maxHeight: 350)
        }
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .frame(width: 600, height: 400)
        .onAppear {
            viewModel.scanApplications()
            viewModel.searchText = ""
            viewModel.selectedIndex = 0
            isSearchFocused = true

            // Parse configured shortcuts
            let config = viewModel.config
            let prefShortcut = KeyboardShortcutParser.parse(config.shortcuts.preferences ?? "")
            let refreshShortcut = KeyboardShortcutParser.parse(config.shortcuts.refresh ?? "")
            let markShortcut = KeyboardShortcutParser.parse(config.shortcuts.markSingleInstance ?? "")

            // Set up local key monitoring
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

                // Check custom shortcuts first
                if let shortcut = prefShortcut,
                   modifiers == shortcut.modifiers && event.keyCode == shortcut.keyCode {
                    NSWorkspace.shared.open(ConfigManager.shared.getConfigFilePath())
                    return nil
                }

                if let shortcut = refreshShortcut,
                   modifiers == shortcut.modifiers && event.keyCode == shortcut.keyCode {
                    self.viewModel.scanApplications()
                    return nil
                }

                if let shortcut = markShortcut,
                   modifiers == shortcut.modifiers && event.keyCode == shortcut.keyCode {
                    self.viewModel.markSelectedAsSingleInstance()
                    return nil
                }

                // Arrow keys and escape
                switch Int(event.keyCode) {
                case 126: // Up arrow
                    self.viewModel.moveSelectionUp()
                    if let proxy = self.scrollProxy,
                       self.viewModel.selectedIndex < self.viewModel.filteredApps.count {
                        let app = self.viewModel.filteredApps[self.viewModel.selectedIndex]
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(app.id, anchor: .center)
                        }
                    }
                    return nil
                case 125: // Down arrow
                    self.viewModel.moveSelectionDown()
                    if let proxy = self.scrollProxy,
                       self.viewModel.selectedIndex < self.viewModel.filteredApps.count {
                        let app = self.viewModel.filteredApps[self.viewModel.selectedIndex]
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(app.id, anchor: .center)
                        }
                    }
                    return nil
                case 53: // Escape
                    self.closeWindow()
                    return nil
                default:
                    return event
                }
            }
        }
    }
    
    func resetSearch() {
        viewModel.searchText = ""
        viewModel.selectedIndex = 0
    }
}

struct AppRow: View {
    let app: Application
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                Text(app.path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
