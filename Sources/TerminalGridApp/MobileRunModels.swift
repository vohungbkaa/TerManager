import Foundation

enum MobileDeviceKind: String, Codable, Hashable {
    case physical
    case simulator
    case emulator
}

struct MobileDevice: Identifiable, Codable, Hashable {
    let identifier: String
    var name: String
    let platform: MobilePlatform
    let kind: MobileDeviceKind
    var controlIdentifier: String?
    var detail: String?

    var id: String { "\(platform.rawValue):\(kind.rawValue):\(identifier)" }
    var isPhysical: Bool { kind == .physical }
}

struct VirtualDeviceAction: Identifiable, Hashable {
    enum Kind: Hashable {
        case iosSimulator
        case androidEmulator(avdID: String)
    }

    let kind: Kind
    let title: String

    var id: String {
        switch kind {
        case .iosSimulator: return "ios-simulator"
        case .androidEmulator(let avdID): return "android-\(avdID)"
        }
    }
}

enum BuildTarget: Equatable {
    enum XcodeContainerKind: String {
        case workspace
        case project
    }

    case flutter(entrypoint: String)
    case android(module: String, variant: String)
    case ios(scheme: String, containerPath: String, containerKind: XcodeContainerKind)

    var displayName: String {
        switch self {
        case .flutter(let entrypoint): return URL(fileURLWithPath: entrypoint).lastPathComponent
        case .android(let module, let variant): return "\(module) / \(variant)"
        case .ios(let scheme, _, _): return scheme
        }
    }

    var iconName: String {
        switch self {
        case .flutter: return "f.square.fill"
        case .android: return "app.badge.fill"
        case .ios: return "swift"
        }
    }
}

enum BuildRunState: Equatable {
    case idle
    case preparing
    case running
    case succeeded
    case failed(String)

    var isActive: Bool {
        self == .preparing || self == .running
    }
}

struct ProcessOutput {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

enum MobileRunError: LocalizedError {
    case toolMissing(String)
    case commandFailed(String)
    case invalidOutput(String)
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .toolMissing(let tool): return "Không tìm thấy \(tool)."
        case .commandFailed(let message): return message
        case .invalidOutput(let message): return "Không đọc được dữ liệu: \(message)"
        case .unsupported(let message): return message
        }
    }
}
