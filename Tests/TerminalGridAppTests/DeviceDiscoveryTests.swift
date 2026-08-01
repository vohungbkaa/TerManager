import XCTest
@testable import TerminalGridApp

final class DeviceDiscoveryTests: XCTestCase {
    private var temporaryRoot: URL!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MobileRunTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: temporaryRoot)
    }

    func testParsesOnlyReadyAndroidDevices() {
        let output = """
        List of devices attached
        emulator-5554 device product:sdk_gphone model:Pixel_7a device:emu transport_id:1
        R58M123 device product:beyond model:Galaxy_S10 device:beyond transport_id:2
        offline-id offline transport_id:3
        unauthorized-id unauthorized transport_id:4
        """

        let devices = DeviceOutputParser.androidDevices(output)

        XCTAssertEqual(devices.count, 2)
        XCTAssertEqual(devices[0].kind, .emulator)
        XCTAssertEqual(devices[0].name, "Pixel 7a")
        XCTAssertEqual(devices[1].kind, .physical)
    }

    func testParsesAndroidVirtualDeviceActions() {
        let actions = DeviceOutputParser.androidAVDs("Pixel_4\nPixel_Tablet\n")

        XCTAssertEqual(actions.map(\.title), [
            "Open Android Emulator: Pixel 4",
            "Open Android Emulator: Pixel Tablet"
        ])
    }

    func testAndroidEmulatorNameCanBeReplacedByAVDName() {
        var device = DeviceOutputParser.androidDevices(
            "List of devices attached\nemulator-5554 device product:sdk model:sdk_gphone64_arm64 device:emu\n"
        )[0]
        let technicalModel = device.name
        let avdName = "Pixel_4"

        device.name = avdName.replacingOccurrences(of: "_", with: " ")
        device.detail = technicalModel

        XCTAssertEqual(device.name, "Pixel 4")
        XCTAssertEqual(device.detail, "sdk gphone64 arm64")
    }

    func testParsesOnlyBootedAvailableIOSSimulators() throws {
        let json = """
        {"devices":{"runtime":[
          {"name":"iPhone 16","udid":"booted","state":"Booted","isAvailable":true},
          {"name":"iPhone 15","udid":"shutdown","state":"Shutdown","isAvailable":true},
          {"name":"iPhone 14","udid":"missing","state":"Booted","isAvailable":false}
        ]}}
        """.data(using: .utf8)!

        let devices = try DeviceOutputParser.iosSimulators(json)

        XCTAssertEqual(devices.map(\.identifier), ["booted"])
        XCTAssertEqual(devices.first?.kind, .simulator)
    }

    func testParsesOnlyConnectedPhysicalIOSDevices() throws {
        let json = """
        {"result":{"devices":[
          {"identifier":"core-1","connectionProperties":{"tunnelState":"connected"},"deviceProperties":{"name":"My iPhone","osVersionNumber":"26.0"},"hardwareProperties":{"udid":"udid-1","platform":"iOS","reality":"physical"}},
          {"identifier":"core-2","connectionProperties":{"tunnelState":"unavailable"},"deviceProperties":{"name":"Old iPhone"},"hardwareProperties":{"udid":"udid-2","platform":"iOS","reality":"physical"}}
        ]}}
        """.data(using: .utf8)!

        let devices = try DeviceOutputParser.iosPhysicalDevices(json)

        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices[0].identifier, "udid-1")
        XCTAssertEqual(devices[0].controlIdentifier, "core-1")
        XCTAssertEqual(devices[0].detail, "iOS 26.0")
    }

    func testIOSSimulatorCommandIncludesDestinationInstallAndLaunch() throws {
        let project = Project(name: "Example", path: "/tmp/Example", projectType: .iosNative)
        let target = BuildTarget.ios(scheme: "Example", containerPath: "/tmp/Example/Example.xcodeproj", containerKind: .project)
        let device = MobileDevice(identifier: "sim-id", name: "iPhone", platform: .ios, kind: .simulator)
        let metadata = IOSBuildMetadata(appPath: "/tmp/App.app", bundleIdentifier: "com.example.app", derivedDataPath: "/tmp/Derived")

        let command = try BuildCommandFactory.command(project: project, target: target, device: device, iosMetadata: metadata)

        XCTAssertTrue(command.contains("'id=sim-id'"))
        XCTAssertTrue(command.contains("simctl install 'sim-id' '/tmp/App.app'"))
        XCTAssertTrue(command.contains("simctl launch 'sim-id' 'com.example.app'"))
    }

    func testFlutterCommandUsesResolvedAbsoluteSDKPath() throws {
        let project = Project(name: "FlutterApp", path: "/tmp/FlutterApp", projectType: .flutter)
        let target = BuildTarget.flutter(entrypoint: "lib/main.dart")
        let device = MobileDevice(identifier: "emulator-5554", name: "Pixel", platform: .android, kind: .emulator)

        let command = try BuildCommandFactory.command(
            project: project,
            target: target,
            device: device,
            flutterExecutable: "/Users/example/develop/flutter/bin/flutter"
        )

        XCTAssertEqual(
            command,
            "'/Users/example/develop/flutter/bin/flutter' 'run' '-d' 'emulator-5554' '-t' 'lib/main.dart'"
        )
    }

    func testAndroidNativeCommandBuildsInstallsAndLaunches() throws {
        let project = Project(name: "AndroidApp", path: "/tmp/AndroidApp", projectType: .androidNative)
        let target = BuildTarget.android(module: "app", variant: "debug")
        let device = MobileDevice(identifier: "device-1", name: "Pixel", platform: .android, kind: .physical)

        let command = try BuildCommandFactory.command(
            project: project,
            target: target,
            device: device,
            adbExecutable: "/Android/sdk/platform-tools/adb"
        )

        XCTAssertTrue(command.contains("ANDROID_SERIAL='device-1' ./gradlew ':app:installDebug'"))
        XCTAssertTrue(command.contains("output-metadata.json"))
        XCTAssertTrue(command.contains("'/Android/sdk/platform-tools/adb' -s 'device-1' shell monkey"))
    }

    func testShellEscapingHandlesSingleQuotes() {
        XCTAssertEqual(ShellEscaper.quote("HUNG's iPhone"), "'HUNG'\\''s iPhone'")
    }

    func testFlutterCandidatesIncludeConfiguredAndCommonReleaseAppLocations() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
        let candidates = ToolLocator.flutterCandidatePaths(
            environment: [
                "PATH": "/usr/bin:/bin",
                "FLUTTER_ROOT": "/opt/flutter-root",
                "FLUTTER_HOME": "/opt/flutter-home"
            ],
            homeDirectory: home
        )

        XCTAssertEqual(candidates.first, "/opt/flutter-root/bin/flutter")
        XCTAssertTrue(candidates.contains("/opt/flutter-home/bin/flutter"))
        XCTAssertTrue(candidates.contains("/Users/example/develop/flutter/bin/flutter"))
        XCTAssertTrue(candidates.contains("/Users/example/.fvm/default/bin/flutter"))
        XCTAssertTrue(candidates.contains("/opt/homebrew/bin/flutter"))
    }

    func testResolvesDefaultFlutterTarget() throws {
        try FileManager.default.createDirectory(
            at: temporaryRoot.appendingPathComponent("lib"),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(
            atPath: temporaryRoot.appendingPathComponent("lib/main.dart").path,
            contents: Data()
        )
        let project = Project(name: "FlutterApp", path: temporaryRoot.path, projectType: .flutter)

        XCTAssertEqual(try BuildTargetResolver.resolve(for: project), .flutter(entrypoint: "lib/main.dart"))
    }

    func testResolvesDefaultAndroidTarget() throws {
        FileManager.default.createFile(
            atPath: temporaryRoot.appendingPathComponent("gradlew").path,
            contents: Data()
        )
        let project = Project(name: "AndroidApp", path: temporaryRoot.path, projectType: .androidNative)

        XCTAssertEqual(try BuildTargetResolver.resolve(for: project), .android(module: "app", variant: "debug"))
    }

    func testAutomaticTerminalLayouts() {
        let expected: [(Int, GridSize)] = [
            (0, GridSize(rows: 1, cols: 1)),
            (1, GridSize(rows: 1, cols: 1)),
            (2, GridSize(rows: 1, cols: 2)),
            (3, GridSize(rows: 2, cols: 2)),
            (4, GridSize(rows: 2, cols: 2)),
            (5, GridSize(rows: 2, cols: 3)),
            (6, GridSize(rows: 2, cols: 3)),
            (7, GridSize(rows: 3, cols: 3)),
            (9, GridSize(rows: 3, cols: 3))
        ]

        for (count, layout) in expected {
            XCTAssertEqual(ProjectStore.automaticGrid(for: count), layout, "Sai bố cục cho \(count) terminal")
        }
    }

    @MainActor
    func testKillPaneTerminatesSlotAndShrinksLayout() {
        let store = ProjectStore(persistenceURL: temporaryRoot.appendingPathComponent("kill-store.json"))
        let entityID = "entity"
        let first = PaneSlot(paneId: "first", cwd: "/tmp")
        let second = PaneSlot(paneId: "second", cwd: "/tmp")
        store.grids[entityID] = GridSize(rows: 1, cols: 2)
        store.panes[entityID] = [first, second]

        store.killPane(entityID: entityID, index: 0)

        XCTAssertEqual(store.grid(for: entityID), GridSize(rows: 1, cols: 1))
        XCTAssertEqual(store.panes[entityID]?.compactMap { $0 }.map(\.paneId), ["second"])
    }

    @MainActor
    func testHidePaneKeepsItAvailableForRestore() {
        let store = ProjectStore(persistenceURL: temporaryRoot.appendingPathComponent("hide-store.json"))
        let entityID = "entity"
        store.grids[entityID] = GridSize(rows: 1, cols: 2)
        store.panes[entityID] = [
            PaneSlot(paneId: "first", cwd: "/tmp"),
            PaneSlot(paneId: "second", cwd: "/tmp")
        ]

        store.hidePane(entityID: entityID, index: 0)

        XCTAssertEqual(store.slots(for: entityID).compactMap { $0 }.map(\.paneId), ["second"])
        XCTAssertEqual(store.hiddenPanesCount(for: entityID), 1)

        store.restoreAllHiddenPanes(for: entityID)
        XCTAssertEqual(store.slots(for: entityID).compactMap { $0 }.count, 2)
        XCTAssertEqual(store.hiddenPanesCount(for: entityID), 0)
    }

    @MainActor
    func testSpawnAddsExactlyOnePaneWithoutRestoringHiddenSlots() {
        let store = ProjectStore(persistenceURL: temporaryRoot.appendingPathComponent("spawn-legacy-store.json"))
        let entityID = "entity"
        let visible = PaneSlot(paneId: "visible", cwd: "/tmp")
        let hidden = (1...4).map { PaneSlot(paneId: "hidden-\($0)", cwd: "/tmp") }
        store.grids[entityID] = GridSize(rows: 1, cols: 1)
        store.panes[entityID] = [visible] + hidden.map(Optional.some)

        let createdIndex = store.spawnPane(entityID: entityID, cwd: "/tmp")

        XCTAssertEqual(createdIndex, 1)
        XCTAssertEqual(store.grid(for: entityID), GridSize(rows: 1, cols: 2))
        XCTAssertEqual(store.slots(for: entityID).compactMap { $0 }.count, 2)
        XCTAssertEqual(store.hiddenPanesCount(for: entityID), 4)
    }

    @MainActor
    func testKillPanePreservesSeparatelyHiddenSlots() {
        let store = ProjectStore(persistenceURL: temporaryRoot.appendingPathComponent("kill-legacy-store.json"))
        let entityID = "entity"
        let visible = [
            PaneSlot(paneId: "visible-1", cwd: "/tmp"),
            PaneSlot(paneId: "visible-2", cwd: "/tmp")
        ]
        let hidden = (1...4).map { PaneSlot(paneId: "hidden-\($0)", cwd: "/tmp") }
        store.grids[entityID] = GridSize(rows: 1, cols: 2)
        store.panes[entityID] = visible.map(Optional.some) + hidden.map(Optional.some)

        store.killPane(entityID: entityID, index: 0)

        XCTAssertEqual(store.grid(for: entityID), GridSize(rows: 1, cols: 1))
        XCTAssertEqual(store.slots(for: entityID).compactMap { $0 }.map(\.paneId), ["visible-2"])
        XCTAssertEqual(store.hiddenPanesCount(for: entityID), 4)
    }

    @MainActor
    func testRootTerminalButtonTargetsActiveTaskInSameProject() {
        let store = ProjectStore(persistenceURL: temporaryRoot.appendingPathComponent("target-store.json"))
        let task = SubProject(name: "Task 1", path: "/tmp")
        let project = Project(name: "Project", path: "/tmp", subProjects: [task])
        store.projects = [project]

        store.selectedEntityID = task.id.uuidString
        XCTAssertEqual(store.terminalTargetEntityID(for: project.id.uuidString), task.id.uuidString)

        store.selectedEntityID = project.id.uuidString
        XCTAssertEqual(store.terminalTargetEntityID(for: project.id.uuidString), project.id.uuidString)
    }

    func testExactAgentTaskNameOverridesStartupCommand() {
        XCTAssertEqual(
            ProjectStore.agentCommand(forTaskName: "  Codex  ", configuredAgents: ["agy", "codex", "claude"]),
            "codex"
        )
        XCTAssertEqual(
            ProjectStore.agentCommand(forTaskName: "gemini", configuredAgents: ["agy", "codex", "claude"]),
            "gemini"
        )
    }

    func testNonExactOrUnsafeAgentTaskNameDoesNotBecomeACommand() {
        XCTAssertNil(ProjectStore.agentCommand(forTaskName: "codex task", configuredAgents: ["codex"]))
        XCTAssertNil(ProjectStore.agentCommand(forTaskName: "codex; rm", configuredAgents: ["codex; rm"]))
        XCTAssertNil(ProjectStore.agentCommand(forTaskName: "feature", configuredAgents: ["codex"]))
    }

    func testPaneSlotFromOlderSavedDataHasNoAgentStartupCommand() throws {
        let id = UUID()
        let data = """
        {
          "id": "\(id.uuidString)",
          "paneId": "legacy-pane",
          "cwd": "/tmp",
          "customName": "Terminal 1"
        }
        """.data(using: .utf8)!

        let slot = try JSONDecoder().decode(PaneSlot.self, from: data)

        XCTAssertEqual(slot.paneId, "legacy-pane")
        XCTAssertNil(slot.startupCommand)
    }

    @MainActor
    func testRenamingTaskToAgentUpdatesExistingTerminalCommands() {
        let store = ProjectStore(persistenceURL: temporaryRoot.appendingPathComponent("rename-agent-store.json"))
        let task = SubProject(name: "Task 1", path: "/tmp")
        let project = Project(name: "Project", path: "/tmp", subProjects: [task])
        store.projects = [project]
        store.grids[task.id.uuidString] = GridSize()
        store.panes[task.id.uuidString] = [PaneSlot(cwd: "/tmp"), PaneSlot(cwd: "/tmp")]

        store.renameSubProject(
            in: project.id.uuidString,
            subProjectID: task.id.uuidString,
            newName: "Codex"
        )

        XCTAssertEqual(store.projects[0].subProjects[0].name, "Codex")
        XCTAssertEqual(
            store.panes[task.id.uuidString]?.compactMap { $0 }.map(\.startupCommand),
            ["codex", "codex"]
        )

        store.renameSubProject(
            in: project.id.uuidString,
            subProjectID: task.id.uuidString,
            newName: "Feature"
        )

        XCTAssertTrue(
            store.panes[task.id.uuidString]?.compactMap { $0 }.allSatisfy { $0.startupCommand == nil } == true
        )
    }

    @MainActor
    func testSpawnedPaneStoresTaskAgentCommandButRootPaneDoesNot() {
        let store = ProjectStore(persistenceURL: temporaryRoot.appendingPathComponent("agent-command-store.json"))
        let task = SubProject(name: "codex", path: "/tmp")
        let project = Project(name: "Project", path: "/tmp", subProjects: [task])
        store.projects = [project]
        store.grids[task.id.uuidString] = GridSize()
        store.grids[project.id.uuidString] = GridSize()

        _ = store.spawnPane(entityID: task.id.uuidString, cwd: "/tmp")
        _ = store.spawnPane(entityID: project.id.uuidString, cwd: "/tmp")

        XCTAssertEqual(store.panes[task.id.uuidString]?.compactMap { $0 }.first?.startupCommand, "codex")
        XCTAssertNil(store.panes[project.id.uuidString]?.compactMap { $0 }.first?.startupCommand)
    }
}
