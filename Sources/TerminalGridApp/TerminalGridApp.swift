import SwiftUI
import AppKit

extension Notification.Name {
    static let toggleSidebarShortcut = Notification.Name("toggleSidebarShortcut")
    static let toggleSettingsShortcut = Notification.Name("toggleSettingsShortcut")
    static let newTerminalShortcut = Notification.Name("newTerminalShortcut")
}

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
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.isOpaque = false
        window.backgroundColor = backgroundColor
    }
}

@main
struct TerminalGridApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = ProjectStore()
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var agentCommandStore = AgentCommandStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(themeManager)
                .environmentObject(agentCommandStore)
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 580)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first {
                        appDelegate.configureWindow(window, backgroundColor: themeManager.current.windowNSColor)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Ẩn / Hiện Sidebar") {
                    NotificationCenter.default.post(name: .toggleSidebarShortcut, object: nil)
                }
                .keyboardShortcut("\\", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Thiết lập & Giao diện...") {
                    NotificationCenter.default.post(name: .toggleSettingsShortcut, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Mở Terminal mới") {
                    NotificationCenter.default.post(name: .newTerminalShortcut, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }
    }
}
