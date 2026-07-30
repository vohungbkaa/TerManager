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
            configureScrollView(termView)
        }

        context.coordinator.termView = termView
        return termView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        configureScrollView(nsView)
    }

    static func dismantleNSView(_ nsView: LocalProcessTerminalView, coordinator: Coordinator) {
        coordinator.termView?.terminate()
    }

    private func configureScrollView(_ termView: LocalProcessTerminalView) {
        if let scrollView = findScrollView(in: termView) {
            scrollView.scrollerStyle = .overlay
            scrollView.scrollerKnobStyle = .light
            scrollView.autohidesScrollers = true
            scrollView.hasHorizontalScroller = false
            scrollView.drawsBackground = false
            scrollView.backgroundColor = .clear
            scrollView.verticalScroller?.controlSize = .small
        }
    }

    private func findScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let found = findScrollView(in: subview) {
                return found
            }
        }
        return nil
    }

    class Coordinator {
        var termView: LocalProcessTerminalView?
    }
}
