import SwiftUI
import AppKit
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

// MARK: - Native AppKit Drag-and-Drop Terminal (Supports macOS Screenshot Thumbnails!)

final class DropEnabledTerminalView: LocalProcessTerminalView {
    var onDropHighlightChanged: ((Bool) -> Void)?

    private static let dropQueue: OperationQueue = {
        let q = OperationQueue()
        q.qualityOfService = .userInitiated
        return q
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerDropTypes()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerDropTypes()
    }

    private func registerDropTypes() {
        var types: [NSPasteboard.PasteboardType] = [
            .fileURL,
            .string,
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.image")
        ]
        let promiseTypes = NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        types.append(contentsOf: promiseTypes)
        registerForDraggedTypes(types)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if canAccept(sender.draggingPasteboard) {
            onDropHighlightChanged?(true)
            return .copy
        }
        return []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        canAccept(sender.draggingPasteboard) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDropHighlightChanged?(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onDropHighlightChanged?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDropHighlightChanged?(false)
        let pasteboard = sender.draggingPasteboard

        // 0. Handle dragged Agent Command chips from TerManager
        if let rawString = pasteboard.string(forType: .string),
           let draggedCmd = AgentCommandDragCodec.decode(rawString) {
            send(txt: draggedCmd.command + "\n")
            window?.makeFirstResponder(self)
            return true
        }

        // 1. Handle macOS File Promises (e.g. Screenshot floating thumbnail in bottom-right corner!)
        if let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver],
           !receivers.isEmpty {
            let destDir = Self.dropTempDirectory()
            for receiver in receivers {
                receiver.receivePromisedFiles(atDestination: destDir, options: [:], operationQueue: Self.dropQueue) { [weak self] fileURL, error in
                    guard error == nil else { return }
                    let escaped = Self.escapeForShell(fileURL.path)
                    DispatchQueue.main.async {
                        self?.send(txt: escaped + " ")
                        self?.window?.makeFirstResponder(self)
                    }
                }
            }
            return true
        }

        // 2. Handle standard Finder file/folder URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            let joined = urls.map { Self.escapeForShell($0.path) }.joined(separator: " ")
            send(txt: joined + " ")
            window?.makeFirstResponder(self)
            return true
        }

        // 3. Fallback: Handle raw image data on pasteboard (PNG / TIFF / NSImage)
        if let image = NSImage(pasteboard: pasteboard),
           let savedURL = Self.saveTemporaryImage(image) {
            let escaped = Self.escapeForShell(savedURL.path)
            send(txt: escaped + " ")
            window?.makeFirstResponder(self)
            return true
        }

        return false
    }

    private func canAccept(_ pasteboard: NSPasteboard) -> Bool {
        if let raw = pasteboard.string(forType: .string),
           raw.hasPrefix(AgentCommandDragCodec.prefix) {
            return true
        }
        if pasteboard.canReadObject(forClasses: [NSFilePromiseReceiver.self], options: nil) {
            return true
        }
        if pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) {
            return true
        }
        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) {
            return true
        }
        return false
    }

    private static func dropTempDirectory() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("TerManagerDrops", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func saveTemporaryImage(_ image: NSImage) -> URL? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let filename = "screenshot-\(formatter.string(from: Date())).png"
        let url = dropTempDirectory().appendingPathComponent(filename)
        do {
            try pngData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func escapeForShell(_ path: String) -> String {
        let specialChars = CharacterSet(charactersIn: " \\'\"()[]{}&;|<>?*~$`!")
        var result = ""
        for scalar in path.unicodeScalars {
            if specialChars.contains(scalar) {
                result.append("\\")
            }
            result.unicodeScalars.append(scalar)
        }
        return result
    }
}

// MARK: - SwiftUI Representable

struct TerminalPane: NSViewRepresentable {
    @EnvironmentObject private var store: ProjectStore
    let paneId: String
    let cwd: String
    let shellPath: String
    let startupCommand: String?
    var onDropHighlightChanged: ((Bool) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        if let cachedView = store.getTerminalView(for: paneId) {
            ThemeManager.shared.current.apply(to: cachedView)
            if let dropView = cachedView as? DropEnabledTerminalView {
                dropView.onDropHighlightChanged = onDropHighlightChanged
            }
            context.coordinator.termView = cachedView
            context.coordinator.startObserving()
            return cachedView
        }

        let termView = DropEnabledTerminalView(frame: .zero)
        termView.onDropHighlightChanged = onDropHighlightChanged

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
        if let dropView = nsView as? DropEnabledTerminalView {
            dropView.onDropHighlightChanged = onDropHighlightChanged
        }
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
