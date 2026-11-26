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

extension AppTheme {
    func apply(to terminalView: LocalProcessTerminalView) {
        terminalView.nativeBackgroundColor = terminalBackgroundNS
        terminalView.nativeForegroundColor = terminalForegroundNS
        terminalView.caretColor = terminalCursorNS
        let swiftTermColors = ansiHexColors.compactMap { SwiftTerm.Color(hexString: $0) }
        if swiftTermColors.count == 16 {
            terminalView.installColors(swiftTermColors)
        }
    }
}

private extension SwiftTerm.Color {
    convenience init?(hexString: String) {
        guard hexString.count == 6, let value = UInt32(hexString, radix: 16) else { return nil }
        let r = UInt16(((value >> 16) & 0xFF) * 257)
        let g = UInt16(((value >> 8) & 0xFF) * 257)
        let b = UInt16((value & 0xFF) * 257)
        self.init(red: r, green: g, blue: b)
    }
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
            ThemeManager.shared.current.apply(to: cachedView)
            context.coordinator.termView = cachedView
            context.coordinator.startObserving()
            return cachedView
        }

        let termView = LocalProcessTerminalView(frame: .zero)

        // Apply active app theme (background, foreground, cursor, 16-color ANSI palette)
        ThemeManager.shared.current.apply(to: termView)

        // Font: JetBrains Mono > SF Mono > Menlo > system monospace
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

        DispatchQueue.main.async {
            configureTerminalView(termView)
        }

        context.coordinator.termView = termView
        context.coordinator.startObserving()

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
        for subview in termView.subviews where subview is NSScroller {
            subview.isHidden = true
        }
    }

    static func terminalFont(size: Double) -> NSFont {
        NSFont(name: "JetBrainsMono-Regular", size: size)
            ?? NSFont(name: "SFMono-Regular", size: size)
            ?? NSFont(name: "Menlo", size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    class Coordinator {
        var termView: LocalProcessTerminalView?
        private var fontObserver: NSObjectProtocol?
        private var themeObserver: NSObjectProtocol?

        func startObserving() {
            if fontObserver == nil {
                fontObserver = NotificationCenter.default.addObserver(
                    forName: .terminalFontSizeChanged,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    guard let termView = self?.termView else { return }
                    termView.font = TerminalPane.terminalFont(size: TerminalFontSize.current)
                }
            }

            if themeObserver == nil {
                themeObserver = NotificationCenter.default.addObserver(
                    forName: .appThemeChanged,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    guard let termView = self?.termView else { return }
                    ThemeManager.shared.current.apply(to: termView)
                }
            }
        }

        deinit {
            if let fontObserver {
                NotificationCenter.default.removeObserver(fontObserver)
            }
            if let themeObserver {
                NotificationCenter.default.removeObserver(themeObserver)
            }
        }
    }
}
