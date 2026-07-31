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

    func makeNSView(context: Context) -> BuildProcessTerminalView {
        if let existing = session.terminalView { return existing }
        let terminal = BuildProcessTerminalView(frame: .zero)
        terminal.nativeForegroundColor = NSColor(red: 0.663, green: 0.694, blue: 0.839, alpha: 1)
        terminal.nativeBackgroundColor = NSColor(red: 0.051, green: 0.055, blue: 0.067, alpha: 1)
        terminal.font = NSFont(name: "JetBrainsMono-Regular", size: 12)
            ?? NSFont(name: "Menlo", size: 12)
            ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        terminal.startProcess(executable: ProjectStore.defaultShell, args: ["-l"], currentDirectory: session.projectPath)
        DispatchQueue.main.async { session.attach(terminal) }
        return terminal
    }

    func updateNSView(_ nsView: BuildProcessTerminalView, context: Context) {}
}

struct BuildTerminalDrawer: View {
    @ObservedObject var session: BuildSession
    @State private var height: CGFloat = 220
    @State private var dragStartHeight: CGFloat?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.themeSurface
                Capsule()
                    .fill(Color.themeTextMuted.opacity(0.75))
                    .frame(width: 42, height: 3)
            }
                .frame(height: 11)
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
                    if hovering {
                        NSCursor.resizeUpDown.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .help("Kéo để thay đổi chiều cao Build Terminal")

            HStack(spacing: 8) {
                Image(systemName: "hammer.fill")
                    .foregroundColor(.themePrimaryHover)
                Text("BUILD TERMINAL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.themeTextSecondary)
                Spacer()
                buildStatus
                Button { session.isDrawerVisible = false } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.plain)
                .foregroundColor(.themeTextMuted)
                .help("Thu gọn Build Terminal")
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Color.themeSurface)

            BuildTerminalRepresentable(session: session)
        }
        .frame(height: height)
        .transaction { transaction in
            transaction.animation = nil
        }
        .background(Color.themeBase)
        .overlay(Rectangle().fill(Color.themeBorder).frame(height: 1), alignment: .top)
    }

    @ViewBuilder
    private var buildStatus: some View {
        switch session.state {
        case .preparing:
            ProgressView().controlSize(.small)
            Text("Preparing")
        case .running:
            Circle().fill(Color.themeGreen).frame(width: 6, height: 6)
            Text("Running")
        case .succeeded:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.themeGreen)
            Text("Success")
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundColor(.themeRed)
            Text("Failed")
        case .idle:
            Text("Ready")
        }
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
