import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.appearance = NSAppearance(named: .darkAqua)

        let bg = ThemeManager.shared.current.windowNSColor
        for window in NSApp.windows {
            configureWindow(window, backgroundColor: bg)
        }
    }

    func configureWindow(_ window: NSWindow, backgroundColor: NSColor) {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = backgroundColor
    }
}

@main
struct TerminalGridApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = ProjectStore()
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(themeManager)
                .preferredColorScheme(.dark)
                .frame(minWidth: 920, minHeight: 600)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first {
                        appDelegate.configureWindow(window, backgroundColor: themeManager.current.windowNSColor)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
