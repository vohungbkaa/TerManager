import SwiftUI
import SwiftTerm

struct TerminalPane: NSViewRepresentable {
    let paneId: String
    let cwd: String
    let shellPath: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let termView = LocalProcessTerminalView(frame: .zero)

        // Color scheme
        termView.nativeForegroundColor = NSColor(red: 0.663, green: 0.694, blue: 0.839, alpha: 1)
        termView.nativeBackgroundColor = NSColor(red: 0.051, green: 0.055, blue: 0.067, alpha: 1)

        // Font: JetBrains Mono > Menlo > system monospace
        termView.font = NSFont(name: "JetBrainsMono-Regular", size: 13)
            ?? NSFont(name: "Menlo", size: 13)
            ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        termView.startProcess(
            executable: shellPath,
            args: ["-l"],
            currentDirectory: cwd
        )

        context.coordinator.termView = termView
        return termView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}

    static func dismantleNSView(_ nsView: LocalProcessTerminalView, coordinator: Coordinator) {
        coordinator.termView?.terminate()
    }

    class Coordinator {
        var termView: LocalProcessTerminalView?
    }
}
