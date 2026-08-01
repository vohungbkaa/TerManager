import Foundation

enum BuildTargetResolver {
    static func resolve(for project: Project) throws -> BuildTarget {
        let rootURL = URL(fileURLWithPath: project.path)
        switch project.projectType {
        case .flutter:
            let entrypoint = "lib/main.dart"
            guard FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(entrypoint).path) else {
                throw MobileRunError.unsupported("Không tìm thấy lib/main.dart.")
            }
            return .flutter(entrypoint: entrypoint)
        case .androidNative:
            guard FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("gradlew").path) else {
                throw MobileRunError.unsupported("Không tìm thấy Gradle wrapper (gradlew).")
            }
            return .android(module: "app", variant: "debug")
        case .iosNative:
            return try resolveXcodeTarget(for: project)
        case .unknown:
            throw MobileRunError.unsupported("Loại project chưa được hỗ trợ.")
        }
    }

    private static func resolveXcodeTarget(for project: Project) throws -> BuildTarget {
        let rootURL = URL(fileURLWithPath: project.path)
        let children = try FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let preferredName = project.name.lowercased()
        let workspaces = children.filter { $0.pathExtension == "xcworkspace" && $0.lastPathComponent != "Pods.xcworkspace" }
        let projects = children.filter { $0.pathExtension == "xcodeproj" }
        let container: URL
        let kind: BuildTarget.XcodeContainerKind
        if let workspace = workspaces.first(where: { $0.deletingPathExtension().lastPathComponent.lowercased() == preferredName }) ?? workspaces.first {
            container = workspace
            kind = .workspace
        } else if let xcodeProject = projects.first(where: { $0.deletingPathExtension().lastPathComponent.lowercased() == preferredName }) ?? projects.first {
            container = xcodeProject
            kind = .project
        } else {
            throw MobileRunError.unsupported("Không tìm thấy .xcworkspace hoặc .xcodeproj.")
        }

        let flag = kind == .workspace ? "-workspace" : "-project"
        let result = try ProcessRunner.run("/usr/bin/xcodebuild", [flag, container.path, "-list", "-json"], cwd: project.path)
        guard result.exitCode == 0, let data = result.stdout.data(using: .utf8) else {
            throw MobileRunError.commandFailed(result.stderr.isEmpty ? "Không đọc được Xcode schemes." : result.stderr)
        }
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let section = object?[kind == .workspace ? "workspace" : "project"] as? [String: Any]
        let schemes = section?["schemes"] as? [String] ?? []
        guard let scheme = schemes.first(where: { $0.lowercased() == preferredName }) ?? schemes.first else {
            throw MobileRunError.unsupported("Project chưa có shared scheme để Run.")
        }
        return .ios(scheme: scheme, containerPath: container.path, containerKind: kind)
    }
}

struct IOSBuildMetadata {
    let appPath: String
    let bundleIdentifier: String
    let derivedDataPath: String
}

enum IOSBuildMetadataResolver {
    static func resolve(project: Project, target: BuildTarget, device: MobileDevice) throws -> IOSBuildMetadata {
        guard case .ios(let scheme, let containerPath, let kind) = target else {
            throw MobileRunError.unsupported("Target iOS không hợp lệ.")
        }
        let derivedDataPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("TerminalGridBuild/\(project.id.uuidString)", isDirectory: true).path
        let flag = kind == .workspace ? "-workspace" : "-project"
        let args = [
            flag, containerPath,
            "-scheme", scheme,
            "-configuration", "Debug",
            "-destination", "id=\(device.identifier)",
            "-derivedDataPath", derivedDataPath,
            "-showBuildSettings"
        ]
        let result = try ProcessRunner.run("/usr/bin/xcodebuild", args, cwd: project.path)
        guard result.exitCode == 0 else {
            throw MobileRunError.commandFailed(result.stderr.isEmpty ? "Không đọc được Xcode build settings." : result.stderr)
        }
        var targetBuildDirectory: String?
        var wrapperName: String?
        var bundleIdentifier: String?
        for rawLine in result.stdout.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("TARGET_BUILD_DIR = ") { targetBuildDirectory = String(line.dropFirst("TARGET_BUILD_DIR = ".count)) }
            if line.hasPrefix("WRAPPER_NAME = ") { wrapperName = String(line.dropFirst("WRAPPER_NAME = ".count)) }
            if line.hasPrefix("PRODUCT_BUNDLE_IDENTIFIER = ") { bundleIdentifier = String(line.dropFirst("PRODUCT_BUNDLE_IDENTIFIER = ".count)) }
        }
        guard let directory = targetBuildDirectory, let wrapper = wrapperName, let bundleIdentifier else {
            throw MobileRunError.invalidOutput("Xcode không trả về đường dẫn app hoặc bundle identifier.")
        }
        return IOSBuildMetadata(
            appPath: URL(fileURLWithPath: directory).appendingPathComponent(wrapper).path,
            bundleIdentifier: bundleIdentifier,
            derivedDataPath: derivedDataPath
        )
    }
}

enum ShellEscaper {
    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum BuildCommandFactory {
    static func command(
        project: Project,
        target: BuildTarget,
        device: MobileDevice,
        iosMetadata: IOSBuildMetadata? = nil,
        flutterExecutable: String? = ToolLocator.flutter,
        adbExecutable: String? = ToolLocator.adb
    ) throws -> String {
        switch target {
        case .flutter(let entrypoint):
            guard let flutter = flutterExecutable else { throw MobileRunError.toolMissing("Flutter SDK") }
            return [flutter, "run", "-d", device.identifier, "-t", entrypoint].map(ShellEscaper.quote).joined(separator: " ")

        case .android(let module, let variant):
            guard let adb = adbExecutable else { throw MobileRunError.toolMissing("adb") }
            let task = ":\(module):install\(variant.prefix(1).uppercased())\(variant.dropFirst())"
            let metadataPath = "\(module)/build/outputs/apk/\(variant)/output-metadata.json"
            return "ANDROID_SERIAL=\(ShellEscaper.quote(device.identifier)) ./gradlew \(ShellEscaper.quote(task))"
                + " && __tm_app_id=$(/usr/bin/plutil -extract applicationId raw \(ShellEscaper.quote(metadataPath)))"
                + " && \(ShellEscaper.quote(adb)) -s \(ShellEscaper.quote(device.identifier)) shell monkey -p \"$__tm_app_id\" -c android.intent.category.LAUNCHER 1"

        case .ios(let scheme, let containerPath, let kind):
            guard let metadata = iosMetadata else { throw MobileRunError.invalidOutput("Thiếu Xcode build settings.") }
            let flag = kind == .workspace ? "-workspace" : "-project"
            let build = [
                "/usr/bin/xcodebuild", flag, containerPath,
                "-scheme", scheme,
                "-configuration", "Debug",
                "-destination", "id=\(device.identifier)",
                "-derivedDataPath", metadata.derivedDataPath,
                "build"
            ].map(ShellEscaper.quote).joined(separator: " ")
            if device.kind == .simulator {
                return build
                    + " && /usr/bin/xcrun simctl install \(ShellEscaper.quote(device.identifier)) \(ShellEscaper.quote(metadata.appPath))"
                    + " && /usr/bin/xcrun simctl launch \(ShellEscaper.quote(device.identifier)) \(ShellEscaper.quote(metadata.bundleIdentifier))"
            }
            let controlID = device.controlIdentifier ?? device.identifier
            return build
                + " && /usr/bin/xcrun devicectl device install app --device \(ShellEscaper.quote(controlID)) \(ShellEscaper.quote(metadata.appPath))"
                + " && /usr/bin/xcrun devicectl device process launch --device \(ShellEscaper.quote(controlID)) \(ShellEscaper.quote(metadata.bundleIdentifier))"
        }
    }
}
