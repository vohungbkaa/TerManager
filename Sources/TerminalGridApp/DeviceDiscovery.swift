import Foundation

enum ToolLocator {
    static var flutter: String { executable(named: "flutter") ?? "/usr/bin/env" }
    static var adb: String? {
        let fm = FileManager.default
        let env = ProcessInfo.processInfo.environment
        let candidates = [
            env["ANDROID_HOME"].map { "\($0)/platform-tools/adb" },
            env["ANDROID_SDK_ROOT"].map { "\($0)/platform-tools/adb" },
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Android/sdk/platform-tools/adb").path,
            executable(named: "adb")
        ].compactMap { $0 }
        return candidates.first { fm.isExecutableFile(atPath: $0) }
    }

    static var emulator: String? {
        let fm = FileManager.default
        let env = ProcessInfo.processInfo.environment
        let candidates = [
            env["ANDROID_HOME"].map { "\($0)/emulator/emulator" },
            env["ANDROID_SDK_ROOT"].map { "\($0)/emulator/emulator" },
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Android/sdk/emulator/emulator").path,
            executable(named: "emulator")
        ].compactMap { $0 }
        return candidates.first { fm.isExecutableFile(atPath: $0) }
    }

    static func executable(named name: String) -> String? {
        let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        return paths
            .map { URL(fileURLWithPath: $0).appendingPathComponent(name).path }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

enum ProcessRunner {
    static func run(_ executable: String, _ arguments: [String], cwd: String? = nil) throws -> ProcessOutput {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        if let cwd { process.currentDirectoryURL = URL(fileURLWithPath: cwd) }

        do {
            try process.run()
        } catch {
            throw MobileRunError.commandFailed("Không thể chạy \(executable): \(error.localizedDescription)")
        }
        var stdoutData = Data()
        var stderrData = Data()
        let readGroup = DispatchGroup()
        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }
        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }
        process.waitUntilExit()
        readGroup.wait()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        return ProcessOutput(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
    }
}

enum DeviceOutputParser {
    static func androidDevices(_ output: String) -> [MobileDevice] {
        output.split(whereSeparator: \.isNewline).dropFirst().compactMap { line in
            let columns = line.split(whereSeparator: \.isWhitespace)
            guard columns.count >= 2, columns[1] == "device" else { return nil }
            let identifier = String(columns[0])
            let values = Dictionary(uniqueKeysWithValues: columns.dropFirst(2).compactMap { column -> (String, String)? in
                let parts = column.split(separator: ":", maxSplits: 1).map(String.init)
                return parts.count == 2 ? (parts[0], parts[1]) : nil
            })
            let rawName = values["model"]?.replacingOccurrences(of: "_", with: " ")
            let isEmulator = identifier.hasPrefix("emulator-")
            return MobileDevice(
                identifier: identifier,
                name: rawName ?? (isEmulator ? "Android Emulator" : "Android Device"),
                platform: .android,
                kind: isEmulator ? .emulator : .physical,
                detail: values["product"]
            )
        }
    }

    static func androidAVDs(_ output: String) -> [VirtualDeviceAction] {
        output.split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { VirtualDeviceAction(kind: .androidEmulator(avdID: $0), title: "Open Android Emulator: \($0.replacingOccurrences(of: "_", with: " "))") }
    }

    static func iosSimulators(_ data: Data) throws -> [MobileDevice] {
        struct Payload: Decodable { let devices: [String: [Simulator]] }
        struct Simulator: Decodable {
            let name: String
            let udid: String
            let state: String
            let isAvailable: Bool
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return payload.devices.values.flatMap { $0 }.compactMap { simulator in
            guard simulator.isAvailable, simulator.state == "Booted" else { return nil }
            return MobileDevice(
                identifier: simulator.udid,
                name: simulator.name,
                platform: .ios,
                kind: .simulator,
                detail: "iOS Simulator"
            )
        }
    }

    static func iosPhysicalDevices(_ data: Data) throws -> [MobileDevice] {
        struct Payload: Decodable { let result: ResultPayload }
        struct ResultPayload: Decodable { let devices: [Device] }
        struct Device: Decodable {
            let identifier: String
            let connectionProperties: Connection
            let deviceProperties: Properties
            let hardwareProperties: Hardware
        }
        struct Connection: Decodable { let tunnelState: String? }
        struct Properties: Decodable { let name: String; let osVersionNumber: String? }
        struct Hardware: Decodable { let udid: String?; let platform: String?; let reality: String? }

        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return payload.result.devices.compactMap { device in
            guard device.connectionProperties.tunnelState == "connected",
                  device.hardwareProperties.platform?.lowercased() == "ios",
                  device.hardwareProperties.reality == "physical",
                  let udid = device.hardwareProperties.udid else { return nil }
            return MobileDevice(
                identifier: udid,
                name: device.deviceProperties.name,
                platform: .ios,
                kind: .physical,
                controlIdentifier: device.identifier,
                detail: device.deviceProperties.osVersionNumber.map { "iOS \($0)" }
            )
        }
    }
}

struct DeviceDiscoveryResult {
    var devices: [MobileDevice]
    var virtualActions: [VirtualDeviceAction]
    var warnings: [String]
}

enum DeviceDiscoveryService {
    static func discover(platforms: [MobilePlatform]) -> DeviceDiscoveryResult {
        var devices: [MobileDevice] = []
        var actions: [VirtualDeviceAction] = []
        var warnings: [String] = []

        if platforms.contains(.android) {
            if let adb = ToolLocator.adb {
                do {
                    let result = try ProcessRunner.run(adb, ["devices", "-l"])
                    if result.exitCode == 0 {
                        var androidDevices = DeviceOutputParser.androidDevices(result.stdout)
                        for index in androidDevices.indices where androidDevices[index].kind == .emulator {
                            let avdResult = try? ProcessRunner.run(adb, ["-s", androidDevices[index].identifier, "emu", "avd", "name"])
                            if let avdName = avdResult?.stdout.split(whereSeparator: \.isNewline).first {
                                let technicalModel = androidDevices[index].name
                                androidDevices[index].name = String(avdName).replacingOccurrences(of: "_", with: " ")
                                androidDevices[index].detail = technicalModel
                            }
                        }
                        devices += androidDevices
                    } else {
                        warnings.append(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                } catch { warnings.append(error.localizedDescription) }
            } else {
                warnings.append("Không tìm thấy Android SDK (adb).")
            }

            if let emulator = ToolLocator.emulator {
                do {
                    let result = try ProcessRunner.run(emulator, ["-list-avds"])
                    if result.exitCode == 0 { actions += DeviceOutputParser.androidAVDs(result.stdout) }
                } catch { warnings.append(error.localizedDescription) }
            }
        }

        if platforms.contains(.ios) {
            do {
                let result = try ProcessRunner.run("/usr/bin/xcrun", ["simctl", "list", "devices", "available", "-j"])
                if result.exitCode == 0, let data = result.stdout.data(using: .utf8) {
                    devices += (try? DeviceOutputParser.iosSimulators(data)) ?? []
                } else if !result.stderr.isEmpty {
                    warnings.append(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            } catch { warnings.append(error.localizedDescription) }

            let jsonURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("termanager-devices-\(UUID().uuidString).json")
            defer { try? FileManager.default.removeItem(at: jsonURL) }
            do {
                let result = try ProcessRunner.run("/usr/bin/xcrun", [
                    "devicectl", "list", "devices", "--timeout", "5", "--json-output", jsonURL.path
                ])
                if result.exitCode == 0, let data = try? Data(contentsOf: jsonURL) {
                    devices += (try? DeviceOutputParser.iosPhysicalDevices(data)) ?? []
                }
            } catch { warnings.append(error.localizedDescription) }

            actions.append(VirtualDeviceAction(kind: .iosSimulator, title: "Open iOS Simulator"))
        }

        devices.sort {
            if $0.isPhysical != $1.isPhysical { return $0.isPhysical }
            if $0.platform != $1.platform { return $0.platform.rawValue < $1.platform.rawValue }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return DeviceDiscoveryResult(devices: devices, virtualActions: actions, warnings: warnings.filter { !$0.isEmpty })
    }
}
