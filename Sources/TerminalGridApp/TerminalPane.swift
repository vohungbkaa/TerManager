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

        // Configure scrollbar asynchronously when view is in hierarchy
        DispatchQueue.main.async {
            configureTerminalView(termView)
        }

        context.coordinator.termView = termView
        return termView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        configureTerminalView(nsView)
    }

    static func dismantleNSView(_ nsView: LocalProcessTerminalView, coordinator: Coordinator) {
        coordinator.termView?.terminate()
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

    class Coordinator {
        var termView: LocalProcessTerminalView?
    }
}
