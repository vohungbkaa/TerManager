import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        
        // Configure all windows to remove the ugly light-grey header background
        for window in NSApp.windows {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.backgroundColor = NSColor(red: 6/255, green: 7/255, blue: 10/255, alpha: 1.0)
        }
    }
}

@main
struct TerminalGridApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = ProjectStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first {
                        window.titlebarAppearsTransparent = true
                        window.titleVisibility = .hidden
                        window.backgroundColor = NSColor(red: 6/255, green: 7/255, blue: 10/255, alpha: 1.0)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
