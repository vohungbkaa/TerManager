import SwiftUI
import SwiftTerm

@MainActor
final class BuildSession: ObservableObject, Identifiable {
    let id: UUID
    let projectPath: String
    @Published var state: BuildRunState = .idle
    @Published var isDrawerVisible = false

    fileprivate var terminalView: BuildProcessTerminalView?
    private var pendingCommand: String?

    init(projectID: UUID, projectPath: String) {
        id = projectID
        self.projectPath = projectPath
    }

    func run(command: String) {
        guard !state.isActive else { return }
        state = .running
        isDrawerVisible = true
        if let terminalView {
            terminalView.run(command: command)
        } else {
            pendingCommand = command
        }
    }

    func prepare() {
        state = .preparing
        isDrawerVisible = true
    }

    func reportFailure(_ message: String) {
        state = .failed(message)
        isDrawerVisible = true
        let notice = "printf '\\n[TerManager] %s\\n' \(ShellEscaper.quote(message))\n"
        if let terminalView {
            terminalView.send(txt: notice)
        } else {
            pendingCommand = notice
        }
    }

    func stop() {
        guard state.isActive else { return }
        terminalView?.interruptForegroundProcess()
    }

    fileprivate func attach(_ view: BuildProcessTerminalView) {
        terminalView = view
        view.onCommandFinished = { [weak self] exitCode in
            Task { @MainActor in
                guard let self else { return }
                self.state = exitCode == 0 ? .succeeded : .failed("Lệnh kết thúc với mã \(exitCode).")
            }
        }
        if let pendingCommand {
            self.pendingCommand = nil
            if state.isActive {
                view.run(command: pendingCommand)
            } else {
                view.send(txt: pendingCommand)
            }
        }
    }
}

final class BuildProcessTerminalView: LocalProcessTerminalView {
    var onCommandFinished: ((Int32) -> Void)?
    private let markerPrefix = Data("\u{1B}]777;TERMANAGER;".utf8)
    private var bufferedData = Data()

    func run(command: String) {
        let token = UUID().uuidString
        let wrapped = "{ \(command); }; __tm_status=$?; printf '\\033]777;TERMANAGER;\(token);%s\\007' \"$__tm_status\"\n"
        send(txt: wrapped)
    }

    func interruptForegroundProcess() {
        send(txt: "\u{3}")
    }

    override func dataReceived(slice: ArraySlice<UInt8>) {
        bufferedData.append(contentsOf: slice)
        drainBuffer()
    }

    private func drainBuffer() {
        while let markerRange = bufferedData.range(of: markerPrefix) {
            if markerRange.lowerBound > bufferedData.startIndex {
                feed(byteArray: Array(bufferedData[..<markerRange.lowerBound])[...])
            }
            guard let terminator = bufferedData[markerRange.upperBound...].firstIndex(of: 7) else {
                bufferedData.removeSubrange(..<markerRange.lowerBound)
                return
            }
            let payload = bufferedData[markerRange.upperBound..<terminator]
            let components = String(data: payload, encoding: .utf8)?.split(separator: ";") ?? []
            let exitCode = components.last.flatMap { Int32($0) } ?? 1
            bufferedData.removeSubrange(...terminator)
            DispatchQueue.main.async { [weak self] in self?.onCommandFinished?(exitCode) }
        }

        let retainedCount = partialMarkerSuffixLength()
        guard bufferedData.count > retainedCount else { return }
        let feedCount = bufferedData.count - retainedCount
        feed(byteArray: Array(bufferedData.prefix(feedCount))[...])
        bufferedData.removeFirst(feedCount)
    }

    private func partialMarkerSuffixLength() -> Int {
        let maximum = min(bufferedData.count, markerPrefix.count - 1)
        guard maximum > 0 else { return 0 }
        for length in stride(from: maximum, through: 1, by: -1) {
            if bufferedData.suffix(length).elementsEqual(markerPrefix.prefix(length)) { return length }
        }
        return 0
    }
}

struct BuildTerminalRepresentable: NSViewRepresentable {
    @ObservedObject var session: BuildSession

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> BuildProcessTerminalView {
        if let existing = session.terminalView {
            ThemeManager.shared.current.apply(to: existing)
            context.coordinator.termView = existing
            context.coordinator.startObserving()
            return existing
        }
        let terminal = BuildProcessTerminalView(frame: .zero)
        ThemeManager.shared.current.apply(to: terminal)
        terminal.font = TerminalPane.terminalFont(size: max(11, TerminalFontSize.current - 1))
        terminal.startProcess(executable: ProjectStore.defaultShell, args: ["-l"], currentDirectory: session.projectPath)
        context.coordinator.termView = terminal
        context.coordinator.startObserving()
        DispatchQueue.main.async { session.attach(terminal) }
        return terminal
    }

    func updateNSView(_ nsView: BuildProcessTerminalView, context: Context) {}

    class Coordinator {
        var termView: BuildProcessTerminalView?
        private var themeObserver: NSObjectProtocol?
        private var fontObserver: NSObjectProtocol?

        func startObserving() {
            if themeObserver == nil {
                themeObserver = NotificationCenter.default.addObserver(
                    forName: .appThemeChanged,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    guard let view = self?.termView else { return }
                    ThemeManager.shared.current.apply(to: view)
                }
            }
            if fontObserver == nil {
                fontObserver = NotificationCenter.default.addObserver(
                    forName: .terminalFontSizeChanged,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    guard let view = self?.termView else { return }
                    view.font = TerminalPane.terminalFont(size: max(11, TerminalFontSize.current - 1))
                }
            }
        }

        deinit {
            if let themeObserver { NotificationCenter.default.removeObserver(themeObserver) }
            if let fontObserver { NotificationCenter.default.removeObserver(fontObserver) }
        }
    }
}

struct BuildTerminalDrawer: View {
    @ObservedObject var session: BuildSession
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var height: CGFloat = 220
    @State private var dragStartHeight: CGFloat?
    @State private var isHandleHovered = false

    var body: some View {
        let theme = themeManager.current
        VStack(spacing: 0) {
            ZStack {
                theme.surface
                Capsule()
                    .fill(isHandleHovered ? theme.accent : theme.borderStrong)
                    .frame(width: isHandleHovered ? 48 : 34, height: 3)
                    .animation(.easeOut(duration: 0.14), value: isHandleHovered)
            }
            .frame(height: 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStartHeight ?? height
                        dragStartHeight = start
                        let proposedHeight = start - value.translation.height
                        height = min(480, max(140, proposedHeight)).rounded()
                    }
                    .onEnded { _ in dragStartHeight = nil }
            )
            .onHover { hovering in
                isHandleHovered = hovering
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .help("Kéo để thay đổi chiều cao Build Terminal")

            HStack(spacing: 8) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 11))
                    .foregroundColor(theme.accentHover)
                Text("BUILD TERMINAL")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(theme.textSecondary)

                Spacer()

                buildStatusBadge

                Button { session.isDrawerVisible = false } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .buttonStyle(GlassIconButtonStyle(size: 24))
                .help("Thu gọn Build Terminal")
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(theme.surface)
            .overlay(HairlineDivider(), alignment: .bottom)

            BuildTerminalRepresentable(session: session)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(theme.terminalBackground)
        }
        .frame(height: height)
        .transaction { transaction in
            transaction.animation = nil
        }
        .background(theme.terminalBackground)
        .overlay(HairlineDivider(), alignment: .top)
    }

    @ViewBuilder
    private var buildStatusBadge: some View {
        let theme = themeManager.current
        HStack(spacing: 5) {
            switch session.state {
            case .preparing:
                ProgressView().controlSize(.mini)
                Text("Preparing")
                    .foregroundColor(theme.textSecondary)
            case .running:
                Circle().fill(theme.success).frame(width: 6, height: 6)
                Text("Running")
                    .foregroundColor(theme.success)
            case .succeeded:
                Image(systemName: "checkmark.circle.fill").foregroundColor(theme.success)
                Text("Success")
                    .foregroundColor(theme.success)
            case .failed:
                Image(systemName: "xmark.circle.fill").foregroundColor(theme.danger)
                Text("Failed")
                    .foregroundColor(theme.danger)
            case .idle:
                Circle().fill(theme.textMuted).frame(width: 5, height: 5)
                Text("Ready")
                    .foregroundColor(theme.textMuted)
            }
        }
        .font(.system(size: 10.5, weight: .semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(theme.surfaceHover))
        .overlay(Capsule().stroke(theme.border, lineWidth: 1))
    }
}

/// Keeps the visibility condition inside a view that directly observes the
/// session. ContentView only observes MobileRunController, so checking the
/// session's published flag there would not refresh when Run opens the drawer.
struct BuildTerminalDrawerHost: View {
    @ObservedObject var session: BuildSession

    var body: some View {
        if session.isDrawerVisible {
            BuildTerminalDrawer(session: session)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
