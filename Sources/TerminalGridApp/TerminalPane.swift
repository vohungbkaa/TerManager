import SwiftUI
import SwiftTerm

enum TerminalFontSize {
    static let defaultSize: Double = 13
    static let range: ClosedRange<Double> = 9...24
    private static let key = "terminalFontSize"

    static var current: Double {
        get {
            let stored = UserDefaults.standard.double(forKey: key)
            return stored == 0 ? defaultSize : stored
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            NotificationCenter.default.post(name: .terminalFontSizeChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let terminalFontSizeChanged = Notification.Name("terminalFontSizeChanged")
}

struct TerminalPane: NSViewRepresentable {
    @EnvironmentObject private var store: ProjectStore
    let paneId: String
    let cwd: String
    let shellPath: String
    let startupCommand: String?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        if let cachedView = store.getTerminalView(for: paneId) {
            context.coordinator.termView = cachedView
            context.coordinator.observeFontSizeChanges()
            return cachedView
        }

        let termView = LocalProcessTerminalView(frame: .zero)

        // Color scheme
        termView.nativeForegroundColor = NSColor(red: 0.663, green: 0.694, blue: 0.839, alpha: 1)
        termView.nativeBackgroundColor = NSColor(red: 0.051, green: 0.055, blue: 0.067, alpha: 1)

        // Font: JetBrains Mono > Menlo > system monospace
        termView.font = Self.terminalFont(size: TerminalFontSize.current)

        termView.startProcess(
            executable: shellPath,
            args: ["-l"],
            currentDirectory: cwd
        )

        let command = startupCommand?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? UserDefaults.standard.string(forKey: "defaultStartCommand")?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cmd = command,
           !cmd.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                termView.send(txt: cmd + "\n")
            }
        }

        // Configure scrollbar asynchronously when view is in hierarchy
        DispatchQueue.main.async {
            configureTerminalView(termView)
        }

        context.coordinator.termView = termView
        context.coordinator.observeFontSizeChanges()

        store.cacheTerminalView(termView, for: paneId)
        return termView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        configureTerminalView(nsView)
    }

    static func dismantleNSView(_ nsView: LocalProcessTerminalView, coordinator: Coordinator) {
        // Do not terminate the process here to keep state across folder switches.
    }

    private func configureTerminalView(_ termView: LocalProcessTerminalView) {
        // SwiftTerm embeds a plain NSScroller directly (no NSScrollView).
        // Its overlay style should auto-hide but renders a persistent grey track here.
        // Hide it; scrollback still works via scroll wheel / keyboard, and
        // reservedScrollerWidth collapses to 0 when hidden, reclaiming the right strip.
        for subview in termView.subviews where subview is NSScroller {
            subview.isHidden = true
        }
    }

    static func terminalFont(size: Double) -> NSFont {
        NSFont(name: "JetBrainsMono-Regular", size: size)
            ?? NSFont(name: "Menlo", size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    class Coordinator {
        var termView: LocalProcessTerminalView?
        private var fontObserver: NSObjectProtocol?

        func observeFontSizeChanges() {
            guard fontObserver == nil else { return }
            fontObserver = NotificationCenter.default.addObserver(
                forName: .terminalFontSizeChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let termView = self?.termView else { return }
                termView.font = TerminalPane.terminalFont(size: TerminalFontSize.current)
            }
        }

        deinit {
            if let fontObserver {
                NotificationCenter.default.removeObserver(fontObserver)
            }
        }
    }
}
