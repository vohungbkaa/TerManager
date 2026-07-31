import SwiftUI

@MainActor
final class MobileRunController: ObservableObject {
    @Published private(set) var activeProject: Project?
    @Published private(set) var devices: [MobileDevice] = []
    @Published private(set) var virtualActions: [VirtualDeviceAction] = []
    @Published private(set) var selectedDeviceID: String?
    @Published private(set) var target: BuildTarget?
    @Published private(set) var targetError: String?
    @Published private(set) var discoveryWarning: String?
    @Published private(set) var isDiscovering = false
    @Published private(set) var isLaunchingVirtualDevice = false
    @Published private(set) var activeSession: BuildSession?

    private var sessions: [UUID: BuildSession] = [:]
    private var refreshTask: Task<Void, Never>?
    private var targetTask: Task<Void, Never>?
    private var runTask: Task<Void, Never>?

    var selectedDevice: MobileDevice? {
        devices.first { $0.id == selectedDeviceID }
    }

    func activate(project: Project) {
        let changed = activeProject?.id != project.id
        activeProject = project
        activeSession = session(for: project)
        selectedDeviceID = UserDefaults.standard.string(forKey: selectionKey(project.id))
        if changed {
            devices = []
            virtualActions = []
            target = nil
            targetError = nil
            refresh()
            resolveTarget(project: project)
        }
    }

    func deactivate() {
        refreshTask?.cancel()
        targetTask?.cancel()
        activeProject = nil
        activeSession = nil
        devices = []
        virtualActions = []
        selectedDeviceID = nil
        target = nil
        targetError = nil
        isDiscovering = false
    }

    func refresh() {
        guard let project = activeProject else { return }
        refreshTask?.cancel()
        isDiscovering = true
        let projectID = project.id
        let platforms = project.projectType.supportedPlatforms
        refreshTask = Task {
            let result = await Task.detached(priority: .userInitiated) {
                DeviceDiscoveryService.discover(platforms: platforms)
            }.value
            guard !Task.isCancelled, activeProject?.id == projectID else { return }
            devices = result.devices
            virtualActions = result.virtualActions
            discoveryWarning = result.warnings.first
            restoreOrSelectDefault(for: project)
            isDiscovering = false
        }
    }

    func select(_ device: MobileDevice) {
        guard let project = activeProject else { return }
        selectedDeviceID = device.id
        UserDefaults.standard.set(device.id, forKey: selectionKey(project.id))
    }

    func launch(_ action: VirtualDeviceAction) {
        guard !isLaunchingVirtualDevice else { return }
        isLaunchingVirtualDevice = true
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    switch action.kind {
                    case .iosSimulator:
                        let result = try ProcessRunner.run("/usr/bin/open", ["-a", "Simulator"])
                        guard result.exitCode == 0 else { throw MobileRunError.commandFailed(result.stderr) }
                    case .androidEmulator(let avdID):
                        guard let emulator = ToolLocator.emulator else { throw MobileRunError.toolMissing("Android Emulator") }
                        let process = Process()
                        process.executableURL = URL(fileURLWithPath: emulator)
                        process.arguments = ["-avd", avdID]
                        process.standardOutput = FileHandle.nullDevice
                        process.standardError = FileHandle.nullDevice
                        try process.run()
                    }
                }.value
                for _ in 0..<30 {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard let project = activeProject else { break }
                    let result = await Task.detached {
                        DeviceDiscoveryService.discover(platforms: project.projectType.supportedPlatforms)
                    }.value
                    devices = result.devices
                    virtualActions = result.virtualActions
                    if let launched = matchingLaunchedDevice(for: action, in: result.devices) {
                        select(launched)
                        break
                    }
                }
            } catch {
                discoveryWarning = error.localizedDescription
            }
            isLaunchingVirtualDevice = false
        }
    }

    func runOrStop() {
        guard let project = activeProject, let session = activeSession else { return }
        if session.state.isActive {
            if session.state == .preparing {
                runTask?.cancel()
                session.state = .idle
            } else {
                session.stop()
            }
            return
        }
        guard let target else {
            session.reportFailure(targetError ?? "Chưa xác định được build target.")
            return
        }
        guard let device = selectedDevice else {
            session.reportFailure("Hãy chọn một device trước khi Run.")
            return
        }

        session.prepare()
        runTask = Task {
            do {
                let command = try await Task.detached(priority: .userInitiated) {
                    let iosMetadata: IOSBuildMetadata?
                    if case .ios = target {
                        iosMetadata = try IOSBuildMetadataResolver.resolve(project: project, target: target, device: device)
                    } else {
                        iosMetadata = nil
                    }
                    return try BuildCommandFactory.command(
                        project: project,
                        target: target,
                        device: device,
                        iosMetadata: iosMetadata
                    )
                }.value
                guard !Task.isCancelled else { return }
                guard activeProject?.id == project.id else { return }
                session.state = .idle
                session.run(command: command)
            } catch {
                session.reportFailure(error.localizedDescription)
            }
        }
    }

    private func resolveTarget(project: Project) {
        targetTask?.cancel()
        let projectID = project.id
        targetTask = Task {
            do {
                let resolved = try await Task.detached(priority: .userInitiated) {
                    try BuildTargetResolver.resolve(for: project)
                }.value
                guard !Task.isCancelled, activeProject?.id == projectID else { return }
                target = resolved
                targetError = nil
            } catch {
                guard activeProject?.id == projectID else { return }
                target = nil
                targetError = error.localizedDescription
            }
        }
    }

    private func session(for project: Project) -> BuildSession {
        if let existing = sessions[project.id] { return existing }
        let session = BuildSession(projectID: project.id, projectPath: project.path)
        sessions[project.id] = session
        return session
    }

    private func restoreOrSelectDefault(for project: Project) {
        if let selectedDeviceID, devices.contains(where: { $0.id == selectedDeviceID }) { return }
        let selected = devices.first(where: \.isPhysical) ?? devices.first
        selectedDeviceID = selected?.id
        if let selected { UserDefaults.standard.set(selected.id, forKey: selectionKey(project.id)) }
    }

    private func matchingLaunchedDevice(for action: VirtualDeviceAction, in devices: [MobileDevice]) -> MobileDevice? {
        switch action.kind {
        case .iosSimulator:
            return devices.first { $0.platform == .ios && $0.kind == .simulator }
        case .androidEmulator(let avdID):
            return devices.first {
                $0.platform == .android && $0.kind == .emulator
                    && ($0.name.replacingOccurrences(of: " ", with: "_") == avdID || $0.detail == avdID)
            } ?? devices.first { $0.platform == .android && $0.kind == .emulator }
        }
    }

    private func selectionKey(_ projectID: UUID) -> String {
        "selectedMobileDevice.\(projectID.uuidString)"
    }
}
