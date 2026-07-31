import Foundation

enum MobilePlatform: String, Codable, Hashable {
    case android
    case ios
}

enum ProjectType: String, Codable, Hashable {
    case flutter
    case androidNative
    case iosNative
    case unknown

    var displayName: String {
        switch self {
        case .flutter: return "Flutter"
        case .androidNative: return "Android"
        case .iosNative: return "iOS"
        case .unknown: return "Không xác định"
        }
    }

    var supportedPlatforms: [MobilePlatform] {
        switch self {
        case .flutter: return [.android, .ios]
        case .androidNative: return [.android]
        case .iosNative: return [.ios]
        case .unknown: return []
        }
    }
}

enum ProjectTypeDetector {
    static func detect(at folderURL: URL, fileManager: FileManager = .default) -> ProjectType {
        if isFlutterProject(at: folderURL, fileManager: fileManager) {
            return .flutter
        }

        let hasAndroidMarkers = isAndroidProject(at: folderURL, fileManager: fileManager)
        let hasIOSMarkers = isIOSProject(at: folderURL, fileManager: fileManager)

        // A non-Flutter root containing both platforms is commonly another
        // cross-platform solution. Do not classify it as a native project.
        guard hasAndroidMarkers != hasIOSMarkers else { return .unknown }
        return hasAndroidMarkers ? .androidNative : .iosNative
    }

    private static func isFlutterProject(at folderURL: URL, fileManager: FileManager) -> Bool {
        let pubspecURL = folderURL.appendingPathComponent("pubspec.yaml")
        guard fileManager.fileExists(atPath: pubspecURL.path),
              let contents = try? String(contentsOf: pubspecURL, encoding: .utf8) else {
            return false
        }

        return contents.range(
            of: #"(?m)^\s*sdk:\s*flutter\s*(?:#.*)?$"#,
            options: .regularExpression
        ) != nil
    }

    private static func isAndroidProject(at folderURL: URL, fileManager: FileManager) -> Bool {
        let settingsFiles = ["settings.gradle", "settings.gradle.kts"]
        let buildFiles = [
            "build.gradle",
            "build.gradle.kts",
            "app/build.gradle",
            "app/build.gradle.kts"
        ]

        return settingsFiles.contains { fileManager.fileExists(atPath: folderURL.appendingPathComponent($0).path) }
            && buildFiles.contains { fileManager.fileExists(atPath: folderURL.appendingPathComponent($0).path) }
    }

    private static func isIOSProject(at folderURL: URL, fileManager: FileManager) -> Bool {
        guard let children = try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        return children.contains {
            $0.pathExtension == "xcodeproj" || $0.pathExtension == "xcworkspace"
        }
    }
}
